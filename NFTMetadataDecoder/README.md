# Task 2

NFT metadata is stored packed as bytes32 variable. It packed the owner's address
into the least significant 20 bytes, the RGB colour into the next 3 bytes, the
isTransferable boolean flag into the next byte, and the tokenId into the most
significant 8 bytes.

Write a function in YUL to get the value of the colour.
For example,
0x0000000000000001018000ffd8da6bf26964af9d7eed9e03e53415d37aa96045 should
return 8388863 or 0x8000FF, its hexadecimal representation.

## Solution

---

```js
  function getColorFromMetadata() external view returns (uint256) {
    assembly {
        // Gets metadata storage slot
        let wholeSlot := sload(metadata.slot)
        // Gets next free memory slot
        let ptr := mload(0x40)
        // Shift metadata right by 160 bits to remove owner
        // Mask the slot to get the value of the color variable
        mstore(ptr, and(shr(160, wholeSlot), 0x000000000000000000ffffff))
        return(ptr, 0x20)
    }
}
```
getColorFromMetadata function extracts the color value from state variable. Here we can see how to read state variable and store return value in memory using YUL. 

## Test


```shell
npx hardhat test
```
