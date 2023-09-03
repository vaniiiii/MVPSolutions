// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title An ERC20 contract named ERC20Token
/// @notice Serves as a fungible token for StakingContract
/// @dev Inherits the OpenZepplin ERC20 implementation
contract ERC20Token is ERC20 {
    /// @notice Staking contract is owner
    /// @dev Only the owner can call the mint and burn functions
    address public immutable owner;
    /// @notice Reverts if non owner account try to call functions
    error NotAuthorized();

    /// @notice Deploys the smart contract
    /// @dev Assigns `msg.sender` to the owner state variable
    constructor() ERC20("ERC20Token", "ERCT") {
        owner = msg.sender;
    }

    /// @notice Mints new tokens and increases the total supply
    /// @dev Function can only be called by the owner
    /// @param account The address of the account that will receive the newly created tokens
    /// @param value The amount of tokens `account` will receive
    function mint(address account, uint256 value) external {
        if (msg.sender != owner) {
            revert NotAuthorized();
        }
        _mint(account, value);
    }

    /// @notice Burns tokens and decreases the total supply
    /// @dev Function can only be called by the owner
    /// @param account The address of the account which burns tokens
    /// @param value The amount of tokens that will be burned
    function burn(address account, uint256 value) external {
        if (msg.sender != owner) {
            revert NotAuthorized();
        }
        _burn(account, value);
    }
}
