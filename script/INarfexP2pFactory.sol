// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "lib/v4-core/src/libraries/Hooks.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title P2P Factory Hook for Uniswap V4
/// @notice Implements Uniswap V4 hooks with BeforeSwap and AfterSwap logic
contract P2PFactoryHook is IHooks, Ownable {
    /// @notice Events for tracking before and after swap logic
    event BeforeSwapTriggered(address indexed sender, IPoolManager.PoolKey poolKey, bytes hookData);
    event AfterSwapTriggered(address indexed sender, IPoolManager.PoolKey poolKey, bytes hookData);

    /// @notice Defines the hook permissions
    /// @return permissions The hooks permissions
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /// @notice Called before a swap occurs
    /// @param sender The address initiating the swap
    /// @param key The pool key for the swap
    /// @param params The swap parameters
    /// @param hookData Additional data passed to the hook
    function beforeSwap(
        address sender,
        IPoolManager.PoolKey memory key,
        IPoolManager.SwapParams memory params,
        bytes calldata hookData
    ) external override onlyPoolManager {
        require(sender != address(0), "P2PFactoryHook: Invalid sender address");
        require(params.amountSpecified != 0, "P2PFactoryHook: Swap amount must be non-zero");

        // Placeholder: Add additional pre-swap logic here

        emit BeforeSwapTriggered(sender, key, hookData);
    }

    /// @notice Called after a swap occurs
    /// @param sender The address initiating the swap
    /// @param key The pool key for the swap
    /// @param params The swap parameters
    /// @param swapDelta The resulting balance delta from the swap
    /// @param hookData Additional data passed to the hook
    function afterSwap(
        address sender,
        IPoolManager.PoolKey memory key,
        IPoolManager.SwapParams memory params,
        IPoolManager.BalanceDelta memory swapDelta,
        bytes calldata hookData
    ) external override onlyPoolManager {
        require(sender != address(0), "P2PFactoryHook: Invalid sender address");

        // Placeholder: Add additional post-swap logic here (e.g., rewards distribution)

        emit AfterSwapTriggered(sender, key, hookData);
    }

    /// @notice Returns the hooks implemented by this contract
    /// @return calls An array of hook calls supported by this contract
    function getHooksCalls() external pure override returns (Hooks.Call[] memory calls) {
        uint256 length = 2;
        calls = new Hooks.Call[](length);
        calls[0] = Hooks.Call.BeforeSwap;
        calls[1] = Hooks.Call.AfterSwap;
        return calls;
    }
}
