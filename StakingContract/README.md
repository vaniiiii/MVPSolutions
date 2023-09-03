# Task 3

Using Hardhat develop a smart contract with staking and unstaking functionality.
Deploy it to the Sepolia testnet and verify it on Etherscan. User can stake Sepolia ETH
only. User should provide the staking period as a function argument as well. The
minimum staking period is 6 months. When staking Sepolia ETH User should get some
amount of the ERC-20 token, which you should also develop, in return. To calculate how
much ERC-20 token to get in return, use ETH/USD oracle. For example, if 1 Sepolia ETH
“costs” $100, User should get 100 of your ERC-20 tokens. To unstake previously staked
Sepolia ETH, User should provide ERC-20 tokens back.

## Solution

There are two solutions for this task:  **StakingContract** and **StakingContractBytes**. The main difference is in how the stake positions are stored.

StakingContract uses `mapping(address => StakePosition[])`. A StakePosition is struct that holds information about position(more details later) .

In StakingContractBytes nested mapping `mapping(address => mapping(uint256 => bytes32)) ` is used. All informations about single position are packed into bytes32. There is also additional mapping for IDs, `mapping(address => uint256)`.

Why two solutions? In my initial one, which is none of these, uint256 were used for struct fields. Then I wanted to optimize gas consumption and decided to pack all data into single slot. I also realized that I can avoid using structs and arrays, so I wrote the bytes32 solution which is more gas-efficient.

### Verified contracts
https://sepolia.etherscan.io/address/0xac158bd90df4088deadbde55eb8ddd92f9da67ff
https://sepolia.etherscan.io/address/0xe40c06eb4409949eeb49a748a0bed74b21967800

---

### Assumptions:

##### Staking contract

- Users can only withdraw the full amount after the staking period passes.

- There is no access control for the staking contract. I wanted to create a contract without any privileged users who could potentially manipulate stakers with oracle/staking period manipulations. It would make sense in an environment where some type of governance contract can implement changes after a vote passes.

---

##### ERC20

- Only staking contract (owner) can mint and burn the tokens. In this way, tokens are only created/destroyed through staking contract. Owner is set on creation and can't be changed. 

---

## StakingContract

### State variables

```
struct StakePosition {
        uint104 ETHAmount;
        uint104 ERC20Amount;
        uint48 endTime;
    }

mapping(address => StakePosition[]) public stakePositions

```

Stake positions are stored as an array of StakePosition structs, which are accessed for a specific address through mapping. It's worth mentioning that I used these types to pack all variables in one slot. Considering ether supply/price, this should be more than enough for single positions.

### Methods

```
function stake(uint256 stakingPeriod) external payable
```

Allows user to stake ether in return for ERC20 tokens. The staking period must be longer than the minimum, and msg.value must be greater than 0. On success, it emits the Staked event.

---

```
function unstake(uint256 id) external
```

Allows users to close a position with a specific ID. The ID must be an existing one, and the staking period should have passed. ERC20 tokens provided back are burnt. On success, it emits the Unstaked event.

---

```
 function getStakePositions(
        address staker
    ) external view returns (StakePosition[] memory stakePositions_)

```

Returns the array of active stake positions for the staker.



---

```
function priceFeed() public view returns (uint256)
```

Returns the current price of ETH in USD using the Chainlink data feed. Data must be non-zero and updated regularly (heartbeat is one hour).

---

```
function _safeCastCheck(
        uint256 ETHAmount,
        uint256 ERC20Amount,
        uint256 endTime
    ) internal pure 
```


Safety check before casting. Reverts if any of the input is above the maximum type value.

---

```
 function _removePosition(address staker, uint256 id) private
```

After a user closes a position, it frees storage. Because the order of positions inside the smart contract does not affect timestamps, it's swapped with the last position so there is no gap in the array.

---

## StakingContractBytes
I will provide only things that are different from StakingContract. Methods like stake, unstake, priceFeed have the same functionality.

### State variables
```
mapping(address => mapping(uint256 => bytes32)) public stakePositions;

mapping(address => uint256) public ids;
```
Stake positions are stored as bytes32 packed data, which are accessed for a specific address through a nested mapping. This is the order of variables [endTime..tokenAmount..ethAmount], where eth and token amounts take 13 bytes each and the time variable takes 6 bytes. Considering ether supply/price, this should be more than enough for single positions.

---

### Methods

```
function getStakePosition(
        address staker,
        uint256 id
    )
        public
        view
        returns (
            bytes32 stakePosition,
            uint256 ETHAmount,
            uint256 ERC20Amount,
            uint256 endTime
        )
```

Because a mapping is used, we need to specify an ID and return a specific position. It uses YUL to unpack data.

---

```
 function _packData(
        bytes32 ethAmount,
        bytes32 tokenAmount,
        bytes32 endTime
    ) internal pure returns (bytes32 packedData) {
```

Written in YUL and uses bitwise operators to pack data into a single bytes32 variable.



---

### Further improvments

- Adding more oracle sources
- Access control
- Partial withdrawals
- Withdraw multiple positions

---
### Test

```shell
npx hardhat test
npx hardhat coverage
```

It can also be tested on the mainnet/Sepolia fork.

Steps:

- Set proccess variables MAINNET_RPC_URL and 
ETH_USD_ORACLE 
- Run a fork in separate terminal
```shell
npx hardhat node --fork $MAINNET_RPC_URL
npx hardhat test --network localhost
```

