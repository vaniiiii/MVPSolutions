# Task 2

Using Foundry, develop the test suite for the following smart contract: TreasuryVester

## Solution

TreasuryVester is used to manage the vesting of a certain amount of tokens to a recipient. The vesting process is defined by a start time (vestingBegin), a cliff time (vestingCliff), and an end time (vestingEnd). For simplicity, I changed the compiler version to 0.6.12, although there is a way to use older compiler versions in Foundry. I showcased it with token mocks, but because TreasuryVester creation occurs more frequently, I avoided using it.

There are 16 different tests written for it, including unit/fuzzing/integration/invariant tests.
 

There is improved version **ImprovedTreasuryVester** which follows  recommendtation from this report. 

## Security problems detected:

### Input validation

-In the constructor, there are no checks if the recipient is a zero address, which can lead to funds being forever lost. Token address zero check is also missing.
- In the setRecipient function, a zero address check is missing.

#### Recommendation: 
Add input validations.

---

### setRecipient function

Anyone can call the setRecipient function and change the recipient address. 

#### Recommendation: Change require to
```
  require(msg.sender == recipient)
```

Also, Ownable2Step is recommended.

---

### claim function
```
IUni(uni).transfer(recipient, amount)
```
does not check if the transfer was successfull. There are ERC20s that return false if transfer fails. 

#### Recommendation: 

Add a check for the transfer, but also consider tokens that don't return any value on transfer.

```
  (bool success, bytes memory data) = uni.call(
            abi.encodeWithSelector(0xa9059cbb, recipient, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TreasuryVester::claim: TRANSFER_FAILED"
        );
    
```

## Gas improvments

- As most of the variables are set in the constructor and can't be changed later, immutable should be used for them.
- setRecipient and claim can be set to external if they are not planned to be inherited.



## Test


```shell
forge test
````
