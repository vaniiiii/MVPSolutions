// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "foundry-huff/HuffDeployer.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

contract LooperTest is Test {
    /// @dev Address of the SimpleStore contract.
    Looper public looper;

    /// @dev Setup the testing environment.
    function setUp() public {
        looper = Looper(HuffDeployer.deploy("Looper"));
    }

    /// @dev Ensure that you can set and get the value.
    function testLoop() public {
        uint256 i = looper.loop();
        assertEq(i, 100);
    }
}

interface Looper {
    function loop() external view returns(uint256);
}