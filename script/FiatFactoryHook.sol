// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../lib/v4-core/lib/solmate/src/tokens/ERC20.sol";
import "../lib/v4-core/src/libraries/Hooks.sol";
import "../lib/v4-core/src/types/PoolKey.sol";
import "../lib/v4-core/src/types/BalanceDelta.sol";
import "../lib/v4-periphery/src/base/hooks/BaseHook.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract FactoryHook is BaseHook, Ownable {
    using Hooks for Hooks.Permissions;

    mapping(string => address) public fiatTokens;
    address[] public fiatList;

    event FiatCreated(string name, string symbol, address fiatAddress);
    event BeforeLiquidityAdded(address indexed sender, PoolKey indexed poolKey, uint256 liquidityAmount);
    event SwapTriggered(PoolKey indexed poolKey, address indexed recipient, BalanceDelta delta);
    event SwapProcessed(PoolKey indexed poolKey, address indexed recipient, BalanceDelta delta);
    event RewardDistributed(PoolKey indexed poolKey, address indexed recipient, uint256 rewardAmount);

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

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
            beforeAddLiquidity: true,
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

    /// @notice Hook logic executed before adding liquidity
    /// @param sender The address adding liquidity
    /// @param poolKey The pool being interacted with
    /// @param liquidityAmount The amount of liquidity being added
    /// @param hookData Additional hook data
    function beforeAddLiquidity(
    address sender,
    PoolKey calldata poolKey,
    uint256 liquidityAmount,
    bytes calldata hookData
) external override onlyPoolManager returns (bytes4) {
    require(liquidityAmount > 0, "FactoryHook: Liquidity must be greater than 0");

    // Decode and utilize hookData if needed
    if (hookData.length > 0) {
        (uint256 minLiquidity, address allowedRecipient) = abi.decode(hookData, (uint256, address));
        require(liquidityAmount >= minLiquidity, "FactoryHook: Liquidity below minimum");
        if (allowedRecipient != address(0)) {
            require(sender == allowedRecipient, "FactoryHook: Sender not authorized");
        }
    }

    // Emit event with relevant details
    emit BeforeLiquidityAdded(sender, poolKey, liquidityAmount);

    return Hooks.BEFORE_ADD_LIQUIDITY_SELECTOR;
}


    /// @notice Hook logic executed before a swap
    /// @param poolKey The pool being interacted with
    /// @param recipient The recipient of the swap
    /// @param delta The balance delta of the swap
    /// @return selector The selector for beforeSwap
    function beforeSwap(
        PoolKey calldata poolKey,
        address recipient,
        BalanceDelta delta
    ) external override onlyPoolManager returns (bytes4) {
        require(recipient != address(0), "FactoryHook: Recipient cannot be zero address");

        // Emit event for tracking
        emit SwapTriggered(poolKey, recipient, delta);

        return Hooks.BEFORE_SWAP_SELECTOR;
    }

    /// @notice Hook logic executed after a swap
    /// @param poolKey The pool being interacted with
    /// @param recipient The recipient of the swap
    /// @param delta The balance delta of the swap
    /// @return selector The selector for afterSwap
    function afterSwap(
        PoolKey calldata poolKey,
        address recipient,
        BalanceDelta delta
    ) external override onlyPoolManager returns (bytes4) {
        // Placeholder for post-swap logic (e.g., reward distribution)
      emit SwapProcessed(poolKey, recipient, delta);
        return Hooks.AFTER_SWAP_SELECTOR;
    }

    /// @notice Create a new fiat token
    /// @param name The name of the fiat token
    /// @param symbol The symbol of the fiat token
    /// @param fiatAddress The address of the fiat token
    function createFiat(string memory name, string memory symbol, address fiatAddress) external onlyOwner {
        require(fiatTokens[symbol] == address(0), "FactoryHook: Fiat token already exists");
        require(fiatAddress != address(0), "FactoryHook: Fiat address cannot be zero");

        fiatTokens[symbol] = fiatAddress;
        fiatList.push(fiatAddress);

        emit FiatCreated(name, symbol, fiatAddress);
    }

    /// @notice Retrieve the list of fiat tokens
    /// @return The list of fiat token addresses
    function getFiatList() external view returns (address[] memory) {
        return fiatList;
    }
}
