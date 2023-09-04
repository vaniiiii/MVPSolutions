# Task 1

Clone the https://github.com/andrejrakic/gas-golfing-challenge-looper repo. Your task
is to lower the gas consumption of the Looper.sol smart contract from the current
43.606 gas to at least 30.000 gas, or lower. You must not edit the doStuff function.
Bonus points if you can lower it to 24.655 or less.

## Solution

In the end, I managed to lower it below 30k without using lower-level languages like Huff. I was stuck at ~30.7k but succeeded at the end.

---

For this optimization, I made several  changes to the `loop` function:

- The loop condition and increment are moved inside the function body. By doing this, the number of operations and gas costs is reduced.

- `unchecked` keyword is used to suppress overflow checks when incrementing `i`. 

- Function visibility is changed from `public pure` to `external payable`. Payable functions are cheaper than nonpayable ones because they don't have msg.value checks. 

These changes reduced the gas consumption to 29.665k.


---

```
function loop() external payable {
        for (uint256 i; ; ) {
            unchecked {
                doStuff(i++);
                if (i == 100) {
                    break;
                }
            }
        }
    }
```
---

## Test


```shell
npx hardhat test
```
