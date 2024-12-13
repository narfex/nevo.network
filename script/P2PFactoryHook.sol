// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.24;

import "./lib/openzeppelin/access/Ownable.sol";
import "./lib/openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {Hooks} from "lib/v4-core/src/libraries/Hooks.sol";

/// @title P2P Hook for Uniswap V4
/// @notice Integrates P2P Buy/Sell Factories and Offers with Uniswap V4 hooks
contract P2PFactoryHook is Ownable {
    using SafeERC20 for IERC20;

    struct Trade {
        uint8 status; // 0 = closed, 1 = active
        uint32 createDate;
        uint moneyAmount;
        uint fiatAmount;
        address client;
        address lawyer;
        string bankAccount;
        bytes32 chatRoom;
    }

    // Constants and state variables
    uint constant DAY = 86400;
    uint constant PERCENT_PRECISION = 10**4;

    mapping(address => bool) public isFiat; // Track fiat tokens
    mapping(address => Trade) private trades;
    mapping(address => bool) private blacklisted;
    mapping(address => uint16) private fees; // Protocol fees
    mapping(address => uint) private validatorLimits;

    event BeforeSwap(address indexed sender, address indexed token0, address indexed token1, uint256 amountIn);
    event AfterSwap(address indexed sender, address indexed token0, address indexed token1, uint256 amountOut);
    event CreateTrade(address indexed client, uint moneyAmount, uint fiatAmount);
    event CancelTrade(address indexed client);
    event ConfirmTrade(address indexed client);

    /// @notice Permissions for hooks
    /// @return permissions The hooks implemented by this contract
    function getHookPermissions()
        public
        pure
        returns (Hooks.Permissions memory permissions)
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

    /// @notice BeforeSwap hook
    function beforeSwap(
        address sender,
        IPoolManager.PoolKey memory key,
        IPoolManager.SwapParams memory params,
        bytes calldata /*hookData*/
    ) external {
        require(!blacklisted[sender], "Sender is blacklisted");
        emit BeforeSwap(sender, key.token0, key.token1, params.amountSpecified);
    }

    /// @notice AfterSwap hook
    function afterSwap(
        address sender,
        IPoolManager.PoolKey memory key,
        IPoolManager.SwapParams memory params,
        IPoolManager.BalanceDelta memory swapDelta,
        bytes calldata /*hookData*/
    ) external {
        emit AfterSwap(sender, key.token0, key.token1, uint256(swapDelta.amountOut));
    }

    /// @notice Create a new trade
    function createTrade(
        address client,
        uint moneyAmount,
        string calldata bankAccount,
        address fiatAddress
    ) external {
        require(isFiat[fiatAddress], "Token is not fiat");
        require(!blacklisted[client], "Client is blacklisted");

        uint fiatAmount = moneyAmount - (moneyAmount * fees[fiatAddress] / PERCENT_PRECISION);
        require(fiatAmount <= validatorLimits[msg.sender], "Exceeds validator limit");

        trades[client] = Trade({
            status: 1,
            createDate: uint32(block.timestamp),
            moneyAmount: moneyAmount,
            fiatAmount: fiatAmount,
            client: client,
            lawyer: address(0),
            bankAccount: bankAccount,
            chatRoom: keccak256(abi.encodePacked(block.timestamp, msg.sender, client))
        });

        emit CreateTrade(client, moneyAmount, fiatAmount);
    }

    /// @notice Cancel a trade
    function cancelTrade(address client) external {
        Trade storage trade = trades[client];
        require(trade.status == 1, "Trade is not active");

        trade.status = 0;
        emit CancelTrade(client);
    }

    /// @notice Confirm a trade
    function confirmTrade(address client) external {
        Trade storage trade = trades[client];
        require(trade.status == 1, "Trade is not active");

        trade.status = 0;
        emit ConfirmTrade(client);
    }

    /// @notice Add a fiat token
    function addFiat(address fiatAddress) external onlyOwner {
        isFiat[fiatAddress] = true;
    }

    /// @notice Remove a fiat token
    function removeFiat(address fiatAddress) external onlyOwner {
        isFiat[fiatAddress] = false;
    }

    /// @notice Set protocol fees
    function setFee(address fiatAddress, uint16 fee) external onlyOwner {
        fees[fiatAddress] = fee;
    }

    /// @notice Set validator limits
    function setValidatorLimit(address validator, uint limit) external onlyOwner {
        validatorLimits[validator] = limit;
    }

    /// @notice Blacklist an address
    function blacklistAddress(address account) external onlyOwner {
        blacklisted[account] = true;
    }

    /// @notice Remove address from blacklist
    function unblacklistAddress(address account) external onlyOwner {
        blacklisted[account] = false;
    }
}
