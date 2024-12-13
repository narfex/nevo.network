// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./lib/openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./lib/openzeppelin/contracts/access/Ownable.sol";

/// @title FiatToken
/// @notice An ERC-20 token implementation for fiat-like tokens with minting and burning functionality.
/// @dev This contract is controlled by an owner who can mint and burn tokens.
contract FiatToken is ERC20, Ownable {
    uint8 private immutable _decimals;

    /// @notice Constructor to initialize the token with name, symbol, and decimals.
    /// @param name_ The name of the token.
    /// @param symbol_ The symbol of the token.
    /// @param decimals_ The number of decimals for the token.
  constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
    _decimals = decimals_;
}


    /// @notice Returns the number of decimals for the token.
    /// @return The number of decimals.
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice Allows the owner to mint new tokens.
    /// @param to The address to receive the newly minted tokens.
    /// @param amount The amount of tokens to mint.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Allows the owner to burn tokens from a specified address.
    /// @param from The address whose tokens will be burned.
    /// @param amount The amount of tokens to burn.
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
