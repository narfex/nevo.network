// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.24;

import "./lib/openzeppelin/utils/Address.sol";
import "./lib/openzeppelin/access/Ownable.sol";
import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager}from "lib/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";


interface IUniswapV4Pool {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/// @title Oracle Hook for Narfex System
/// @notice Provides dynamic token price, commission, and reward management in a modular hook
contract OracleHook is Ownable, IHooks {
    using Address for address;

    struct Token {
        bool isFiat;
        bool isCustomCommission;
        bool isCustomReward;
        uint price; 
        uint reward; 
        int commission;
        uint transferFee; // Transfer fee with 1000 decimals precision
    }

    struct TokenData {
        bool isFiat;
        int commission;
        uint price;
        uint reward;
        uint transferFee;
    }

    address[] public fiats;
    address[] public coins;
    mapping(address => Token) public tokens;

    int public defaultFiatCommission = 0;
    int public defaultCryptoCommission = 0;
    uint public defaultReward = 0;

    address public updater;
    address public USDT;

    event SetUpdater(address updater);
    event UpdatePrice(address indexed token, uint newPrice);
    event UpdateTokenSettings(address indexed token, Token tokenData);
    event BeforeSwap(address indexed sender, address token0, address token1, uint amountIn);
    event AfterSwap(address indexed sender, address token0, address token1, uint amountOut);

    modifier onlyUpdater() {
        require(msg.sender == owner() || msg.sender == updater, "OracleHook: Unauthorized");
        _;
    }

    constructor(address _USDT) {
        USDT = _USDT;
    }

    /// @notice Set the updater address
    function setUpdater(address _updater) external onlyOwner {
        updater = _updater;
        emit SetUpdater(_updater);
    }

    /// @notice Hook logic for `beforeSwap`
    function beforeSwap(
        address sender,
        IPoolManager.PoolKey memory key,
        IPoolManager.SwapParams memory params,
        bytes calldata
    ) external override returns (bytes4) {
        require(tokens[key.token0].isFiat || tokens[key.token1].isFiat, "No fiat tokens involved");
        emit BeforeSwap(sender, key.token0, key.token1, params.amountSpecified);
        return IHooks.beforeSwap.selector;
    }

    /// @notice Hook logic for `afterSwap`
    function afterSwap(
        address sender,
        IPoolManager.PoolKey memory key,
        IPoolManager.SwapParams memory params,
        IPoolManager.BalanceDelta memory swapDelta,
        bytes calldata
    ) external override {
        require(tokens[key.token0].isFiat || tokens[key.token1].isFiat, "No fiat tokens involved");
        emit AfterSwap(sender, key.token0, key.token1, uint256(swapDelta.amountOut));
    }

    /// @notice Retrieve token price
    function getPrice(address _token, address _pool) public view returns (uint) {
        return tokens[_token].isFiat ? tokens[_token].price : getDEXPrice(_token, _pool);
    }

    /// @notice Get the price ratio between two tokens using Uniswap V4 pool reserves
    function getPairRatio(address _pool, address _token0, address _token1) internal view returns (uint) {
        IUniswapV4Pool pool = IUniswapV4Pool(_pool);
        (uint112 reserve0, uint112 reserve1) = pool.getReserves();

        return pool.token0() == _token0
            ? (10**IERC20(_token0).decimals() * reserve1) / reserve0
            : (10**IERC20(_token1).decimals() * reserve0) / reserve1;
    }

    /// @notice Get token USD price via Uniswap pool if not fiat
    function getDEXPrice(address _token, address _pool) internal view returns (uint) {
        return _token == USDT
            ? 10**IERC20(USDT).decimals()
            : getPairRatio(_pool, _token, USDT);
    }

    /// @notice Update a token's price
    function updatePrice(address _token, uint _price) external onlyUpdater {
    Token storage token = tokens[_token];
    uint oldPrice = token.price;
    
    token.price = _price;
    if (!token.isFiat) {
        token.isFiat = true;
        if (!_isInArray(fiats, _token)) {
            fiats.push(_token);
        }
    }
    emit UpdatePrice(_token, oldPrice, _price);
}


    /// @notice Retrieve comprehensive token data
    function getTokenData(address _token, address _pool) external view returns (TokenData memory) {
        Token storage token = tokens[_token];
        uint tokenPrice = token.isFiat ? token.price : getDEXPrice(_token, _pool);

        return TokenData({
            isFiat: token.isFiat,
            commission: token.isCustomCommission ? token.commission : (token.isFiat ? defaultFiatCommission : defaultCryptoCommission),
            price: tokenPrice,
            reward: token.isCustomReward ? token.reward : defaultReward,
            transferFee: token.transferFee
        });
    }

    /// @notice Set default settings for fiat, crypto commissions, and referral rewards
    function setDefaultSettings(
        int _fiatCommission,
        int _cryptoCommission,
        uint _reward
    ) external onlyOwner {
        defaultFiatCommission = _fiatCommission;
        defaultCryptoCommission = _cryptoCommission;
        defaultReward = _reward;
    }
}
