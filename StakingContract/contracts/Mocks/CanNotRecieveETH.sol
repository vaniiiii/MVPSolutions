// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract CanNotRecieveETH {
    uint256 public constant MINIMUM_STAKING_PERIOD = 180 days;
    uint256 stakedAmountETH;
    uint256 ERC20Amount;
    uint256 public recieved;

    IStakingContract immutable stakingContract;
    IERC20 immutable token;
    
    error CanNotRecieveMoreETH();

    constructor(address stakingContract_, address token_) {
        stakingContract = IStakingContract(stakingContract_);
        token = IERC20(token_);
    }

    receive() external payable {
        if (recieved != 0) {
            revert CanNotRecieveMoreETH();
        }
        recieved = 1;
        // selfdestruct bypass this, but doesn't matter in our case because it's MOCK test
    }

    function stake() external {
        stakedAmountETH = address(this).balance;
        ERC20Amount = stakedAmountETH * stakingContract.priceFeed();
        stakingContract.stake{value: address(this).balance}(
            MINIMUM_STAKING_PERIOD
        );
    }

    function unstake() external {
        IERC20(token).approve(address(stakingContract), ERC20Amount);
        stakingContract.unstake(0); // 0 because it's MOCK
    }
}

interface IStakingContract {
    function stake(uint256 stakingPeriod) external payable;

    function unstake(uint256 id) external;

    function token() external returns (address);

    function priceFeed() external pure returns (uint256 price);
}

interface IERC20 {
    function approve(address spender, uint256 value) external returns (bool);
}
