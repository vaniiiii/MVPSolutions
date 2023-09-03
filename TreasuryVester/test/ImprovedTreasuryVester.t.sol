// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "../src/ImprovedTreasuryVester.sol";

contract ImprovedTreasuryVesterTest is Test {
    ImprovedTreasuryVester public tvester;

    address public uni;
    address public uniNoRevertOnTransfer;
    address public uniNoReturnValueOnTransfer;
    address recipient = makeAddr("recipient");
    address vani = makeAddr("vani");

    function setUp() public {
        address uni_;
        address uniNoRevertOnTransfer_;
        address uniNoReturnValueOnTransfer_;
        bytes memory args = abi.encode(vani, vani, 1);
        bytes memory bytecodeUni = abi.encodePacked(
            vm.getCode("Uni.sol:Uni"),
            args
        );
        bytes memory bytecodeUniNoRevertOnTransfer = abi.encodePacked(
            vm.getCode("UniNoRevertOnTransfer.sol:UniNoRevertOnTransfer"),
            args
        );
        bytes memory bytecodeUniNoReturnValueOnTransfer = abi.encodePacked(
            vm.getCode(
                "UniNoReturnValueOnTransfer.sol:UniNoReturnValueOnTransfer"
            ),
            args
        );
        assembly {
            uni_ := create(0, add(bytecodeUni, 0x20), mload(bytecodeUni))
            uniNoRevertOnTransfer_ := create(
                0,
                add(bytecodeUniNoRevertOnTransfer, 0x20),
                mload(bytecodeUniNoRevertOnTransfer)
            )
            uniNoReturnValueOnTransfer_ := create(
                0,
                add(bytecodeUniNoReturnValueOnTransfer, 0x20),
                mload(bytecodeUniNoReturnValueOnTransfer)
            )
        }
        tvester = new ImprovedTreasuryVester(
            uni_,
            recipient,
            1000000000000,
            10,
            15,
            20
        );
        vm.prank(vani);
        IUni(uni_).transfer(address(tvester), 1000e18);
        uni = uni_;
        uniNoRevertOnTransfer = uniNoRevertOnTransfer_;
        uniNoReturnValueOnTransfer = uniNoReturnValueOnTransfer_;
    }

    // UNIT

    function testDeployment() external {
        assertEq(tvester.uni(), uni);
        assertEq(tvester.recipient(), recipient);
        assertEq(tvester.vestingAmount(), 1000000000000);
        assertEq(tvester.vestingBegin(), 10);
        assertEq(tvester.vestingCliff(), 15);
        assertEq(tvester.vestingEnd(), 20);
        assertEq(tvester.lastUpdate(), tvester.vestingBegin());
        assertEq(IUni(uni).balanceOf(address(tvester)), 1000e18);
    }

    function testDeploymentWhenVestingBeginIsInPastFails() external {
        vm.warp(100);
        vm.expectRevert("TreasuryVester::constructor: vesting begin too early");
        new ImprovedTreasuryVester(uni, recipient, 99, 10, 15, 20);
    }

    function testDeploymentWhenVestingCliffIsTooEarlyFails() external {
        vm.expectRevert("TreasuryVester::constructor: cliff is too early");
        new ImprovedTreasuryVester(uni, recipient, 99, 10, 9, 20);
    }

    function testDeploymentWhenVestingEndIsTooEarlyFails() external {
        vm.expectRevert("TreasuryVester::constructor: end is too early");
        new ImprovedTreasuryVester(uni, recipient, 99, 10, 10, 10);
    }

    function testDeploymentWhenUniIsZeroFails() external {
        vm.expectRevert();
        new ImprovedTreasuryVester(
            address(0),
            recipient,
            1000000000000,
            10,
            15,
            20
        );
    }

    function testDeploymentWhenRecipientIsZeroFails() external {
        vm.expectRevert();
        new ImprovedTreasuryVester(uni, address(0), 1000000000000, 10, 15, 20);
    }

    function testSetRecipient() external {
        address newRecipient = makeAddr("newRecipient");
        vm.prank(recipient);
        tvester.setRecipient(newRecipient);
        assertEq(tvester.recipient(), newRecipient);
    }

    function testOnlyCurrentRecipientCanCallFunction() external {
        vm.prank(vani);
        vm.expectRevert("TreasuryVester::setRecipient: unauthorized");
        tvester.setRecipient(vani);
    }

    function testClaimWhenVestingIsNotEnded() external {
        vm.warp(15);
        tvester.claim();
        assertEq(IUni(uni).balanceOf(recipient), 500000000000);
        assertEq(tvester.lastUpdate(), block.timestamp);
    }

    function testClaimWhenVestingIsEnded() external {
        vm.warp(20);
        uint256 balance = IUni(uni).balanceOf(address(tvester));
        tvester.claim();
        assertEq(IUni(uni).balanceOf(recipient), balance);
    }

    function testClaimWhenNotTimeYetFails() external {
        vm.warp(14);
        vm.expectRevert("TreasuryVester::claim: not time yet");
        tvester.claim();
    }

    //INTEGRATION

    function testClaimWhenTransferFails() external {
        ImprovedTreasuryVester tvester_ = new ImprovedTreasuryVester(
            uni,
            recipient,
            1000000000000,
            10,
            15,
            20
        );
        vm.startPrank(vani);
        IUni(uni).transfer(address(tvester_), 100);
        vm.warp(16);
        vm.expectRevert("TreasuryVester::claim: TRANSFER_FAILED");
        tvester_.claim();
        vm.stopPrank();
    }

    function testClaimWhenTransferReturnsFalse() external {
        ImprovedTreasuryVester tvester_ = new ImprovedTreasuryVester(
            uniNoRevertOnTransfer,
            recipient,
            1000000000000,
            10,
            15,
            20
        );
        vm.startPrank(vani);
        IUni(uniNoRevertOnTransfer).transfer(address(tvester_), 100);
        vm.warp(16);
        vm.expectRevert("TreasuryVester::claim: TRANSFER_FAILED");
        tvester_.claim();
        vm.stopPrank();
    }

    function testClaimWhenTransferReturnsNoValueFails() external {
        ImprovedTreasuryVester tvester_ = new ImprovedTreasuryVester(
            uniNoReturnValueOnTransfer,
            recipient,
            1000000000000,
            10,
            15,
            20
        );
        vm.startPrank(vani);
        IUniNoReturnValue(uniNoReturnValueOnTransfer).transfer(
            address(tvester_),
            100
        );
        vm.warp(16);
        vm.expectRevert("TreasuryVester::claim: TRANSFER_FAILED");
        tvester_.claim();
        vm.stopPrank();
    }

    function testClaimWhenTransferReturnsNoValue() external {
        ImprovedTreasuryVester tvester_ = new ImprovedTreasuryVester(
            uniNoReturnValueOnTransfer,
            recipient,
            1000000000000,
            10,
            15,
            20
        );
        vm.startPrank(vani);
        IUniNoReturnValue(uniNoReturnValueOnTransfer).transfer(
            address(tvester_),
            1000000000000
        );
        vm.warp(15);
        tvester_.claim();
        assertEq(
            IUniNoReturnValue(uniNoReturnValueOnTransfer).balanceOf(recipient),
            500000000000
        );
        vm.stopPrank();
    }

    // FUZZ

    function testFuzzDeployment(
        address uni_,
        address recipient_,
        uint vestingAmount_,
        uint vestingBegin_,
        uint vestingCliff_,
        uint vestingEnd_
    ) external {
        vm.assume(
            uni_ != address(0) &&
                recipient_ != address(0) &&
                vestingBegin_ > 0 &&
                vestingCliff_ >= vestingBegin_ &&
                vestingEnd_ > vestingCliff_
        );
        ImprovedTreasuryVester tvester_ = new ImprovedTreasuryVester(
            uni_,
            recipient_,
            vestingAmount_,
            vestingBegin_,
            vestingCliff_,
            vestingEnd_
        );
        assertEq(tvester_.uni(), uni_);
        assertEq(tvester_.recipient(), recipient_);
        assertEq(tvester_.vestingAmount(), vestingAmount_);
        assertEq(tvester_.vestingBegin(), vestingBegin_);
        assertEq(tvester_.vestingCliff(), vestingCliff_);
        assertEq(tvester_.vestingEnd(), vestingEnd_);
        assertEq(tvester_.lastUpdate(), tvester_.vestingBegin());
    }

    function testFuzzSetRecipient(address recipient_) external {
        vm.assume(recipient_ != address(0));
        vm.startPrank(recipient);
        tvester.setRecipient(recipient_);
        assertEq(tvester.recipient(), recipient_);
        vm.stopPrank();
    }

    // INVARIANT

    function invariantZeroAddress() external {
        assertTrue(tvester.recipient() != address(0));
    }
}
