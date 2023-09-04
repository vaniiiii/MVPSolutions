// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Looper {
    function doStuff(uint256 i) private pure returns (uint256) {
        return i;
    }

    function loop() external payable {
        unchecked {
            for (uint256 i; ; ) {
                doStuff(i++);
                if (i == 100) {
                    break;
                }
            }
        }
    }
}
