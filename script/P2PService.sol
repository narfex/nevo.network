// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./lib/openzeppelin/contract/access/Ownable.sol";
import "./lib/openzeppelin/utils/Address.sol";
import "./lib/openzeppelin/token/ERC20/IERC20.sol";
import {INarfexP2pFactory} from "./INarfexP2pFactory.sol";
import {INarfexP2pRouter} from "./INarfexP2pRouter.sol";
import {Hooks} from "./lib/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";

/// @title Narfex P2P Service
/// @notice Handles P2P trading logic, integrating with factories, routers, and hooks
contract P2PService is Ownable {
    using Address for address;

    INarfexP2pFactory public factory;
    INarfexP2pRouter public router;

    mapping(address => bool) private supportedFiatTokens;

    event FiatTokenAdded(address indexed token);
    event FiatTokenRemoved(address indexed token);
    event TradeCreated(address indexed buyer, address indexed seller, uint amount, bytes32 tradeId);
    event TradeCancelled(address indexed buyer, address indexed seller, bytes32 tradeId);
    event TradeConfirmed(address indexed buyer, address indexed seller, bytes32 tradeId);
    event BeforeSwap(address indexed sender, address indexed token0, address indexed token1, uint256 amountIn);
    event AfterSwap(address indexed sender, address indexed token0, address indexed token1, uint256 amountOut);

    struct Trade {
        address buyer;
        address seller;
        uint amount;
        uint price;
        uint status; // 0 = created, 1 = confirmed, 2 = cancelled
        bytes32 tradeId;
        address fiatToken;
    }

    mapping(bytes32 => Trade) public trades;

    constructor(address _factory, address _router) {
        factory = INarfexP2pFactory(_factory);
        router = INarfexP2pRouter(_router);
    }

    modifier onlyKYCVerified(address user) {
        require(factory.isKYCVerified(user), "P2PService: KYC verification required");
        _;
    }

    modifier onlyActiveTrade(bytes32 tradeId) {
        require(trades[tradeId].status == 0, "P2PService: Trade is not active");
        _;
    }

    /// @notice Defines the hook permissions
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
        require(!factory.isBlacklisted(sender), "P2PService: Sender is blacklisted");
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

    /// @notice Adds a fiat token to the supported list
    /// @param token Fiat token address
    function addFiatToken(address token) external onlyOwner {
        supportedFiatTokens[token] = true;
        emit FiatTokenAdded(token);
    }

    /// @notice Removes a fiat token from the supported list
    /// @param token Fiat token address
    function removeFiatToken(address token) external onlyOwner {
        supportedFiatTokens[token] = false;
        emit FiatTokenRemoved(token);
    }

    /// @notice Checks if a fiat token is supported
    /// @param token Fiat token address
    /// @return True if supported
    function isSupportedFiatToken(address token) public view returns (bool) {
        return supportedFiatTokens[token];
    }

    /// @notice Creates a new trade
    /// @param buyer Buyer's address
    /// @param seller Seller's address
    /// @param amount Amount of fiat involved
    /// @param price Price in crypto or fiat
    /// @param fiatToken Address of the fiat token
    function createTrade(
        address buyer,
        address seller,
        uint amount,
        uint price,
        address fiatToken
    ) external onlyKYCVerified(buyer) onlyKYCVerified(seller) {
        require(isSupportedFiatToken(fiatToken), "P2PService: Unsupported fiat token");

        bytes32 tradeId = keccak256(
            abi.encodePacked(block.timestamp, buyer, seller, amount, price, fiatToken)
        );

        trades[tradeId] = Trade({
            buyer: buyer,
            seller: seller,
            amount: amount,
            price: price,
            status: 0,
            tradeId: tradeId,
            fiatToken: fiatToken
        });

        emit TradeCreated(buyer, seller, amount, tradeId);
    }

    /// @notice Confirms a trade
    /// @param tradeId Trade identifier
    function confirmTrade(bytes32 tradeId) external onlyActiveTrade(tradeId) {
        Trade storage trade = trades[tradeId];
        require(msg.sender == trade.buyer || msg.sender == trade.seller, "P2PService: Unauthorized");

        trade.status = 1;

        // Execute the fiat token transfer
        IERC20(trade.fiatToken).transferFrom(trade.buyer, trade.seller, trade.amount);

        emit TradeConfirmed(trade.buyer, trade.seller, tradeId);
    }

    /// @notice Cancels a trade
    /// @param tradeId Trade identifier
    function cancelTrade(bytes32 tradeId) external onlyActiveTrade(tradeId) {
        Trade storage trade = trades[tradeId];
        require(msg.sender == trade.buyer || msg.sender == trade.seller, "P2PService: Unauthorized");

        trade.status = 2;

        emit TradeCancelled(trade.buyer, trade.seller, tradeId);
    }

    /// @notice Returns trade details
    /// @param tradeId Trade identifier
    /// @return Trade details
    function getTrade(bytes32 tradeId) external view returns (Trade memory) {
        return trades[tradeId];
    }
}
