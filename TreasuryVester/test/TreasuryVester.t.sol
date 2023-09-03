// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "../src/TreasuryVester.sol";

contract TreasuryVesterTest is Test {
    TreasuryVester public tvester;

    address public uni;
    address public uniNoRevertOnTransfer;
    address public uniNoReturnValueOnTransfer;
    address recipient = makeAddr("recipient");
    address vani = makeAddr("vani");

    function setUp() public {
        address uni_;
        address uniNoRevertOnTransfer_;
        bytes memory args = abi.encode(vani, vani, 1);
        bytes memory bytecodeUni = abi.encodePacked(
            vm.getCode("Uni.sol:Uni"),
            args
        );
        bytes memory bytecodeUniNoRevertOnTransfer = abi.encodePacked(
            vm.getCode("UniNoRevertOnTransfer.sol:UniNoRevertOnTransfer"),
            args
        );
        assembly {
            uni_ := create(0, add(bytecodeUni, 0x20), mload(bytecodeUni))
            uniNoRevertOnTransfer_ := create(
                0,
                add(bytecodeUniNoRevertOnTransfer, 0x20),
                mload(bytecodeUniNoRevertOnTransfer)
            )
        }
        tvester = new TreasuryVester(
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
        new TreasuryVester(uni, recipient, 99, 10, 15, 20);
    }

    function testDeploymentWhenVestingCliffIsTooEarlyFails() external {
        vm.expectRevert("TreasuryVester::constructor: cliff is too early");
        new TreasuryVester(uni, recipient, 99, 10, 9, 20);
    }

    function testDeploymentWhenVestingEndIsTooEarlyFails() external {
        vm.expectRevert("TreasuryVester::constructor: end is too early");
        new TreasuryVester(uni, recipient, 99, 10, 10, 10);
    }

    function testDeploymentWhenUniIsZeroFails() external {
        vm.expectRevert();
        new TreasuryVester(address(0), recipient, 1000000000000, 10, 15, 20);
    }

    function testDeploymentWhenRecipientIsZeroFails() external {
        vm.expectRevert();
        new TreasuryVester(uni, address(0), 1000000000000, 10, 15, 20);
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

    function testWhatIfTransferFails() external {
        TreasuryVester tvester_ = new TreasuryVester(
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
        vm.expectRevert(
            "Uni::_transferTokens: transfer amount exceeds balance"
        );
        tvester_.claim();
        vm.stopPrank();
    }

    function testWhatIfTransferReturnsFalse() external {
        TreasuryVester tvester_ = new TreasuryVester(
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
        vm.expectRevert();
        tvester_.claim();
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
        TreasuryVester tvester_ = new TreasuryVester(
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
        vm.startPrank(recipient_);
        tvester.setRecipient(recipient_);
        assertEq(tvester.recipient(), recipient_);
        vm.stopPrank();
    }

    function invariantZeroAddress() external {
        assertTrue(tvester.recipient() != address(0));
    }
}
