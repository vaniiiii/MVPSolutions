// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./ERC20Token.sol";

/// @title StakingContract
/// @notice A smart contract for staking and unstaking Sepolia ETH and receiving ERC-20 tokens in return.
/// @dev This contract allows users to stake Sepolia ETH for a specified period and receive ERC-20 tokens as rewards. Amount of ERC20 tokens is calculated using Chainlink ETH/USD data feed
contract StakingContract {
    /// @notice Struct representing a stake position
    /// @dev uint104 is used for single stake position amounts, uint48 for time
    struct StakePosition {
        uint104 ETHAmount;
        uint104 ERC20Amount;
        uint48 endTime;
    }

    uint256 public constant MINIMUM_STAKING_PERIOD = 180 days;
    uint256 public totalStaked;
    mapping(address => StakePosition[]) public stakePositions;

    ERC20Token public immutable token;
    AggregatorV3Interface public immutable dataFeed;

    /// @notice Event emitted when a user stakes Sepolia ETH
    event Staked(
        address indexed staker,
        uint256 amount,
        uint256 indexed id,
        uint256 stakingPeriod
    );
    /// @notice Event emitted when a user unstakes Sepolia ETH
    event UnStaked(
        address indexed staker,
        uint256 amount,
        uint256 indexed id,
        uint256 tokenAmount
    );
    /// @dev Reverts on next errors
    error MinimumStakingPeriodTooShort();
    error ZeroStakingAmount();
    error CastOverflow();
    error StakingPeriodNotPassed();
    error EtherTransferFailed();
    error StakePositionNotActive();
    error ERC20TokenTransferFailed();
    error StaleData();
    error ZeroPrice();

    /// @notice Creates a new StakingContract instance
    /// @param dataFeed_ The address of the ETH/USD oracle contract
    constructor(address dataFeed_) {
        token = new ERC20Token();
        dataFeed = AggregatorV3Interface(dataFeed_);
    }

    /// @notice Stakes Sepolia ETH and receives ERC-20 tokens as rewards
    /// @param stakingPeriod The duration of the staking period in seconds, must be greater than minimum staking period
    function stake(uint256 stakingPeriod) external payable {
        if (stakingPeriod < MINIMUM_STAKING_PERIOD) {
            revert MinimumStakingPeriodTooShort();
        }
        if (msg.value == 0) {
            revert ZeroStakingAmount();
        }

        uint256 tokenAmount = msg.value * priceFeed();
        _safeCastCheck(msg.value, tokenAmount, block.timestamp + stakingPeriod);

        totalStaked += msg.value;

        uint256 id = stakePositions[msg.sender].length;
        StakePosition memory stakePosition = StakePosition(
            uint104(msg.value),
            uint104(tokenAmount),
            uint48(block.timestamp + stakingPeriod)
        );
        stakePositions[msg.sender].push(stakePosition);

        emit Staked(msg.sender, msg.value, id, stakingPeriod);

        token.mint(msg.sender, tokenAmount);
    }

    /// @notice Unstakes Sepolia ETH and returns ERC-20 tokens
    /// @param id The index of the stake position to unstake
    function unstake(uint256 id) external {
        if (id > (stakePositions[msg.sender].length - 1)) {
            revert StakePositionNotActive();
        }

        StakePosition memory stakePosition = stakePositions[msg.sender][id];
        uint256 ERC20Amount = stakePosition.ERC20Amount;
        uint256 ETHAmount = stakePosition.ETHAmount;

        if (block.timestamp < stakePosition.endTime) {
            revert StakingPeriodNotPassed();
        }

        totalStaked -= ETHAmount;
        _removePosition(msg.sender, id);

        emit UnStaked(
            msg.sender,
            stakePosition.ETHAmount,
            id,
            stakePosition.ERC20Amount
        );

        (bool sent, ) = msg.sender.call{value: ETHAmount}("");
        if (!sent) {
            revert EtherTransferFailed();
        }
        bool success = token.transferFrom(
            msg.sender,
            address(this),
            ERC20Amount
        );
        if (!success) {
            revert ERC20TokenTransferFailed();
        }
        token.burn(address(this), ERC20Amount);
    }

    /// @notice Retrieves all stake positions for a given staker
    /// @param staker The address of the staker
    /// @return stakePositions_ An array of stake positions
    function getStakePositions(
        address staker
    ) external view returns (StakePosition[] memory stakePositions_) {
        stakePositions_ = stakePositions[staker];
    }

    /// @notice Gets the current ETH/USD price from the oracle
    /// @return The current price
    function priceFeed() public view returns (uint256) {
        (, int256 price, , uint256 timeStamp, ) = dataFeed.latestRoundData();

        if (timeStamp < block.timestamp - 60 * 60 /* 1 hour */) {
            revert StaleData();
        }

        if (price <= 0) {
            revert ZeroPrice();
        }

        return uint256(price) / 10 ** (dataFeed.decimals());
    }

    function _safeCastCheck(
        uint256 ETHAmount,
        uint256 ERC20Amount,
        uint256 endTime
    ) internal pure {
        if (
            ETHAmount > type(uint104).max ||
            ERC20Amount > type(uint104).max ||
            endTime > type(uint48).max
        ) {
            revert CastOverflow();
        }
    }

    function _removePosition(address staker, uint256 id) private {
        uint256 length = stakePositions[staker].length;
        if (id != length - 1) {
            stakePositions[staker][id] = stakePositions[staker][length - 1];
        }
        stakePositions[staker].pop();
    }
}
