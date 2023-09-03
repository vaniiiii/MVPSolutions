# Task 1

Clone the https://github.com/andrejrakic/gas-golfing-challenge-looper repo. Your task
is to lower the gas consumption of the Looper.sol smart contract from the current
43.606 gas to at least 30.000 gas, or lower. You must not edit the doStuff function.
Bonus points if you can lower it to 24.655 or less.

## Solution

Huff. I tried different tricks inside solidity(avoiding overflow checks, external payable modifiers) but didn't work. If doStuff(i) is not planned to be changed simply commenting it out works because code boiled down increments i from 0 to 99. 

This was a super fun task because writing Huff helped me understand the EVM better, even though this code was not complex.

## Code Explanation

---
At the top of the file, there is a function declaration that allows users to interact with the contract externally:

```#define function loop() view returns(uint256 i)```

This is only done for external/public functions. 

--- 

After that comes the MAIN macro. This serves a single entry point for Huff contracts. All calls to a contract will start from MAIN. The first lines extract the function selector from calldata, and if it matches the loop function selector, it jumps to the location of the loop function code:

```
#define macro MAIN() = takes(0) returns(0) {

    // Get the function selector
    0x00
    calldataload
    0xE0
    shr

    // Jump to the implementation of the loop function if the calldata matches the function selector
    __FUNC_SIG(loop) eq loop jumpi
    
    loop:
        LOOP()
}
```
---

The Loop function is simply an implementation of a for loop in Huff. At the end, for testing purposes, I am returning the counter value from the function:

```
#define macro LOOP() = takes(0) returns(0) {
    0x64    // [100]
    0x00    // [i,100]
    compare:
    dup2 dup2 // [i,100,i,100]
    eq exit jumpi // [i,100]
    DOSTUFF() // [i,100]
    0x01 add // [i+1,100]
    compare jump
    exit: // [i,100]
    swap1 // [100,i]
    pop // [i]
    0x00 mstore // place the result in memory         
    0x20 0x00 return      // return the result
}
```

---
I will explain now more about how internal/private functions work in Huff.

You will notice that DOSTUFF is defined as:

```#define fn DOSTUFF() = takes (2) returns (2) {}```

This means it takes two values from stack and return two values on stack. Internal/private functions do not use return opcode, they return values by putting them on stack. External functions return values by putting the return values in memory and calling the return opcode. "Named returns" are syntactical sugar that Solidity uses.

 I didn't define DOSTUFF as macro because it's not allowed according the task.

 What's the difference?

  Each time a macro is invoked, the code within it is placed at the point of invocation.

  Functions look extremely similar to macros, but behave somewhat differently. Instead of the code being inserted at each invocation, the compiler moves the code to the end of the runtime bytecode, and a jump to and from that code is inserted at the points of invocation instead.
## Gas cost
 It is essentially a trade-off of decreasing contract size for extra runtime gas cost (22 + n_inputs * 3 + n_outputs * 3 gas per invocation, to be exact [Huff documentation]). Because of this, execution is 3,400 gas more expensive (34 x 100). In the current state, the total gas consumed is 28,730. 
 
 Because DOSTUFF is simply leaving the top item on the stack, it can be removed, and it wouldn't change any functionality (if you turn on optimization on the compiler and check bytecode, you will see that Solidity completely ignores doStuff calls).
 When defined as a macro, it consumes 25,130.
 
  https://www.evm.codes/playground?fork=shanghai used as reference. 

---

## Test


```shell
forge test
```
