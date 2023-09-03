// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract ImprovedTreasuryVester {
    using SafeMath for uint256;

    address public immutable uni;
    address public recipient;
    // TO-DO: // temp_recipient, he needs to confirm?,     // public -> external? ovo napisi u izvestaju najbolje.
    // TO-DO: NatSpecs maybe
    
    uint256 public immutable vestingAmount;
    uint256 public immutable vestingBegin;
    uint256 public immutable vestingCliff;
    uint256 public immutable vestingEnd;

    uint256 public lastUpdate;

    event RecipientUpdated(address indexed recipient);
    event Claimed(address indexed recipient, uint256 indexed amount);

    constructor(
        address uni_,
        address recipient_,
        uint256 vestingAmount_,
        uint256 vestingBegin_,
        uint256 vestingCliff_,
        uint256 vestingEnd_
    ) public {
        require(
            vestingBegin_ >= block.timestamp,
            "TreasuryVester::constructor: vesting begin too early"
        );
        require(
            vestingCliff_ >= vestingBegin_,
            "TreasuryVester::constructor: cliff is too early"
        );
        require(
            vestingEnd_ > vestingCliff_,
            "TreasuryVester::constructor: end is too early"
        );
        require(
            uni_ != address(0),
            "TreasuryVester::constructor: uni cant be address(0)"
        );
        require(
            recipient_ != address(0),
            "TreasuryVester::constructor: recipient cant be address(0)"
        );

        uni = uni_;
        recipient = recipient_;

        vestingAmount = vestingAmount_;
        vestingBegin = vestingBegin_;
        vestingCliff = vestingCliff_;
        vestingEnd = vestingEnd_;

        lastUpdate = vestingBegin_;
    }

    function setRecipient(address recipient_) public {
        require(
            recipient_ != address(0),
            "TreasuryVester::setRecipient: recipient cant be address(0)"
        );
        require(
            msg.sender == recipient,
            "TreasuryVester::setRecipient: unauthorized"
        );
        recipient = recipient_;
        emit RecipientUpdated(recipient_);
    }

    function claim() public {
        require(
            block.timestamp >= vestingCliff,
            "TreasuryVester::claim: not time yet"
        );
        uint256 amount;
        if (block.timestamp >= vestingEnd) {
            amount = IUni(uni).balanceOf(address(this));
        } else {
            amount = vestingAmount.mul(block.timestamp - lastUpdate).div(
                vestingEnd - vestingBegin
            );
            lastUpdate = block.timestamp;
        }
        emit Claimed(recipient, amount);
        (bool success, bytes memory data) = uni.call(
            abi.encodeWithSelector(0xa9059cbb, recipient, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TreasuryVester::claim: TRANSFER_FAILED"
        );
    }
}

interface IUni {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address dst, uint256 rawAmount) external returns (bool);
}

interface IUniNoReturnValue {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address dst, uint256 rawAmount) external;
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow"); // underflow?

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
