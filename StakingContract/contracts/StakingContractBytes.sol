// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./ERC20Token.sol";

/// @title StakingContractBytes
/// @notice A smart contract for staking and unstaking Sepolia ETH and receiving ERC-20 tokens in return.
/// @dev This contract allows users to stake Sepolia ETH for a specified period and receive ERC-20 tokens as rewards. Amount of ERC20 tokens is calculated using Chainlink ETH/USD data feed
contract StakingContractBytes {
    uint256 public constant MINIMUM_STAKING_PERIOD = 180 days;
    // state variables
    uint256 public totalStaked;
    /// @notice Stake positions are saved as packed bytes32 data.
    mapping(address => mapping(uint256 => bytes32)) public stakePositions;
    /// @notice Number of total account positions
    mapping(address => uint256) public ids;

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
    event UnStaked(address indexed staker, uint256 amount, uint256 indexed id); // mozda dodati erc20amount?
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
        uint256 id = ids[msg.sender];

        bytes32 data = _packData(
            bytes32(msg.value),
            bytes32(tokenAmount),
            bytes32(block.timestamp + stakingPeriod)
        );

        stakePositions[msg.sender][id] = data;
        ids[msg.sender] = id + 1;

        emit Staked(msg.sender, msg.value, id, stakingPeriod);
        token.mint(msg.sender, tokenAmount);
    }

    /// @notice Unstakes Sepolia ETH and returns ERC-20 tokens
    /// @param id The index of the stake position to unstake
    function unstake(uint256 id) external {
        uint256 endTime;
        uint256 ETHAmount;
        uint256 ERC20Amount;
        bytes32 stakePosition;
        (stakePosition, ETHAmount, ERC20Amount, endTime) = getStakePosition(
            msg.sender,
            id
        );

        if (stakePosition == 0) {
            revert StakePositionNotActive();
        }

        if (block.timestamp < endTime) {
            revert StakingPeriodNotPassed();
        }

        totalStaked -= ETHAmount;
        stakePositions[msg.sender][id] = 0;

        emit UnStaked(msg.sender, ETHAmount, id);

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
    /// @param id The stake position id
    /// @return stakePosition Packed bytes32 data
    /// @return ETHAmount Amount of staked ETH
    /// @return ERC20Amount Amount of ERC20Token minted for this position
    /// @return endTime Timestamp after user can withdraw ETH
    function getStakePosition(address staker, uint256 id)
        public
        view
        returns (
            bytes32 stakePosition,
            uint256 ETHAmount,
            uint256 ERC20Amount,
            uint256 endTime
        )
    {
        stakePosition = stakePositions[staker][id];
        assembly {
            endTime := shr(224, stakePosition)
            ERC20Amount := shr(
                112,
                and(
                    0x00000000ffffffffffffffffffffffffffff0000000000000000000000000000,
                    stakePosition
                )
            )

            ETHAmount := and(
                0x000000000000000000000000000000000000ffffffffffffffffffffffffffff,
                stakePosition
            )
        }
    }

    /// @notice Gets the current ETH/USD price from the oracle
    /// @return The current price
    function priceFeed() public view returns (uint256) {
        (, int256 price, , uint256 timeStamp, ) = dataFeed.latestRoundData();

        if (
            timeStamp < block.timestamp - 60 * 60 /* 1 hour */
        ) {
            revert StaleData();
        }

        if (price <= 0) {
            revert ZeroPrice();
        }

        return uint256(price) / 10**(dataFeed.decimals());
    }

    /// @notice Packs inputs into single bytes32 variable
    /// @return packedData Inputs as bytes32 [endTime..tokenAmount..ethAmount]
    function _packData(
        bytes32 ethAmount,
        bytes32 tokenAmount,
        bytes32 endTime
    ) internal pure returns (bytes32 packedData) {
        assembly {
            packedData := or(packedData, ethAmount)
            packedData := or(packedData, shl(112, tokenAmount))
            packedData := or(packedData, shl(224, endTime))
        }
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
}
