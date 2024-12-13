// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../lib/v4-core/src/libraries/Hooks.sol";
import "../lib/v4-core/src/types/PoolKey.sol";
import "../lib/v4-core/src/types/BalanceDelta.sol";
import "../lib/v4-periphery/src/base/hooks/BaseHook.sol";

import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract RouterHook is BaseHook, Ownable {
    using SafeERC20 for IERC20;

    // Reward token for incentivization
    IERC20 public rewardToken;

    // Oracle for price feeds
    address public oracle;

    // Reward rate in basis points (1% = 100, 100% = 10000)
    uint256 public rewardRate = 10; // Default: 0.1%

    // Event emitted when rewards are distributed
    event RewardDistributed(PoolKey poolKey, address recipient, uint256 rewardAmount);
    
    event BeforeSwapTriggered(PoolKey indexed poolKey, address indexed recipient, BalanceDelta delta);

    /// @dev Constructor for the hook contract
    /// @param _poolManager Address of the PoolManager
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

    /// @notice Updates the oracle address
    /// @param _oracle New oracle address
    function setOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Oracle cannot be zero address");
        oracle = _oracle;
    }

    /// @notice Updates the reward token address
    /// @param _rewardToken New reward token address
    function setRewardToken(address _rewardToken) external onlyOwner {
        require(_rewardToken != address(0), "Reward token cannot be zero address");
        rewardToken = IERC20(_rewardToken);
    }

    /// @notice Updates the reward rate
    /// @param _newRate The new reward rate in basis points (1% = 100, 100% = 10000)
    function setRewardRate(uint256 _newRate) external onlyOwner {
        require(_newRate <= 10000, "Reward rate cannot exceed 100%");
        rewardRate = _newRate;
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
    require(recipient != address(0), "Recipient cannot be zero address");

    // Validate PoolKey (optional, if specific pools have restrictions)
    _validatePoolKey(poolKey);

    // Validate Delta (ensure swap isn't empty or invalid)
    _validateDelta(delta);

    // Emit event for tracking
    emit BeforeSwapTriggered(poolKey, recipient, delta);

    return Hooks.BEFORE_SWAP_SELECTOR;
}

/// @notice Validates the PoolKey for specific conditions
/// @param poolKey The PoolKey to validate
function _validatePoolKey(PoolKey calldata poolKey) internal view {
    // Example validation logic for PoolKey
    // if (restrictedPools[poolKey]) {
    //     revert("PoolKey restricted for swaps");
    // }
}

/// @notice Validates the delta for the swap
/// @param delta The BalanceDelta to validate
function _validateDelta(BalanceDelta delta) internal pure {
    require(delta.amount0() != 0 || delta.amount1() != 0, "Swap delta cannot be zero");
}


    /// @notice Hook logic executed after a swap
    /// @param poolKey The pool being interacted with
    /// @param recipient The recipient of the swap
    /// @param delta The balance delta of the swap
    /// @return selector The selector for afterSwap
    /// @return adjustment Adjustment to apply after the swap
    function afterSwap(
        PoolKey calldata poolKey,
        address recipient,
        BalanceDelta delta
    ) external override onlyPoolManager returns (bytes4, int128) {
        if (address(rewardToken) != address(0) && recipient != address(0)) {
            uint256 rewardAmount = _calculateReward(delta);
            if (rewardAmount > 0) {
                rewardToken.safeTransfer(recipient, rewardAmount);
                emit RewardDistributed(poolKey, recipient, rewardAmount);
            }
        }

        return (this.afterSwap.selector, 0);
    }

    /// @notice Calculates rewards based on swap activity
    /// @param delta The balance delta of the swap
    /// @return rewardAmount Calculated reward amount
    function _calculateReward(BalanceDelta delta) internal view returns (uint256) {
        int256 deltaSum = delta.amount0() + delta.amount1();
        return deltaSum > 0 ? uint256(deltaSum) * rewardRate / 10000 : 0;
    }
}
