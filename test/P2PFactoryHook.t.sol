// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../script/P2PFactoryHook.sol";

contract P2PFactoryHookTest is Test {
    P2PFactoryHook hook;

    address owner = address(0x1);
    address user = address(0x2);
    address blacklistedUser = address(0x3);
    address fiatToken = address(0x4);

    function setUp() public {
        hook = new P2PFactoryHook();
        vm.prank(owner);
        hook.transferOwnership(owner);

        // Add a fiat token
        vm.prank(owner);
        hook.addFiat(fiatToken);

        // Blacklist a user
        vm.prank(owner);
        hook.blacklistAddress(blacklistedUser);
    }

    function testAddFiat() public {
        address newFiat = address(0x5);

        vm.prank(owner);
        hook.addFiat(newFiat);

        // Verify the new fiat token was added
        assertTrue(hook.isFiat(newFiat));
    }

    function testRemoveFiat() public {
        vm.prank(owner);
        hook.removeFiat(fiatToken);

        // Verify the fiat token was removed
        assertFalse(hook.isFiat(fiatToken));
    }

    function testBlacklistAddress() public {
        address newBlacklistedUser = address(0x6);

        vm.prank(owner);
        hook.blacklistAddress(newBlacklistedUser);

        // Verify the user was blacklisted
        assertTrue(hook.getIsBlacklisted(newBlacklistedUser));
    }

    function testUnblacklistAddress() public {
        vm.prank(owner);
        hook.unblacklistAddress(blacklistedUser);

        // Verify the user was removed from the blacklist
        assertFalse(hook.getIsBlacklisted(blacklistedUser));
    }

    function testCreateTrade() public {
        uint moneyAmount = 1000;
        string memory bankAccount = "Test Bank Account";

        vm.prank(user);
        hook.createTrade(user, moneyAmount, bankAccount, fiatToken);

        // Verify the trade was created
        P2PFactoryHook.Trade memory trade = hook.getTrade(user);
        assertEq(trade.client, user);
        assertEq(trade.moneyAmount, moneyAmount);
        assertEq(trade.bankAccount, bankAccount);
        assertEq(trade.fiatAmount, moneyAmount - (moneyAmount * hook.getFee(fiatToken) / 10000));
    }

    function testCancelTrade() public {
        uint moneyAmount = 1000;
        string memory bankAccount = "Test Bank Account";

        // Create a trade
        vm.prank(user);
        hook.createTrade(user, moneyAmount, bankAccount, fiatToken);

        // Cancel the trade
        vm.prank(user);
        hook.cancelTrade(user);

        // Verify the trade status is updated
        P2PFactoryHook.Trade memory trade = hook.getTrade(user);
        assertEq(trade.status, 0);
    }

    function testBeforeSwapBlacklistedUserReverts() public {
        PoolKey memory poolKey; // Replace with valid PoolKey mock
        vm.expectRevert("Sender is blacklisted");
        vm.prank(blacklistedUser);
        hook.beforeSwap(blacklistedUser, poolKey, BalanceDelta(0, 0), "");
    }

    function testBeforeSwapSuccess() public {
        PoolKey memory poolKey; // Replace with valid PoolKey mock
        BalanceDelta memory delta = BalanceDelta(100, 100); // Replace with valid BalanceDelta mock

        vm.prank(user);
        hook.beforeSwap(user, poolKey, delta, "");

        // Verify the event
        vm.expectEmit(true, true, true, true);
        emit P2PFactoryHook.BeforeSwap(user, poolKey.token0, poolKey.token1, delta.amount0());
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../script/P2PFactoryHook.sol";

contract P2PFactoryHookTest is Test {
    P2PFactoryHook hook;

    address owner = address(0x1);
    address user = address(0x2);
    address blacklistedUser = address(0x3);
    address fiatToken = address(0x4);

    function setUp() public {
        hook = new P2PFactoryHook();
        vm.prank(owner);
        hook.transferOwnership(owner);

        // Add a fiat token
        vm.prank(owner);
        hook.addFiat(fiatToken);

        // Blacklist a user
        vm.prank(owner);
        hook.blacklistAddress(blacklistedUser);
    }

    function testAddFiat() public {
        address newFiat = address(0x5);

        vm.prank(owner);
        hook.addFiat(newFiat);

        // Verify the new fiat token was added
        assertTrue(hook.isFiat(newFiat));
    }

    function testRemoveFiat() public {
        vm.prank(owner);
        hook.removeFiat(fiatToken);

        // Verify the fiat token was removed
        assertFalse(hook.isFiat(fiatToken));
    }

    function testBlacklistAddress() public {
        address newBlacklistedUser = address(0x6);

        vm.prank(owner);
        hook.blacklistAddress(newBlacklistedUser);

        // Verify the user was blacklisted
        assertTrue(hook.getIsBlacklisted(newBlacklistedUser));
    }

    function testUnblacklistAddress() public {
        vm.prank(owner);
        hook.unblacklistAddress(blacklistedUser);

        // Verify the user was removed from the blacklist
        assertFalse(hook.getIsBlacklisted(blacklistedUser));
    }

    function testCreateTrade() public {
        uint moneyAmount = 1000;
        string memory bankAccount = "Test Bank Account";

        vm.prank(user);
        hook.createTrade(user, moneyAmount, bankAccount, fiatToken);

        // Verify the trade was created
        P2PFactoryHook.Trade memory trade = hook.getTrade(user);
        assertEq(trade.client, user);
        assertEq(trade.moneyAmount, moneyAmount);
        assertEq(trade.bankAccount, bankAccount);
        assertEq(trade.fiatAmount, moneyAmount - (moneyAmount * hook.getFee(fiatToken) / 10000));
    }

    function testCancelTrade() public {
        uint moneyAmount = 1000;
        string memory bankAccount = "Test Bank Account";

        // Create a trade
        vm.prank(user);
        hook.createTrade(user, moneyAmount, bankAccount, fiatToken);

        // Cancel the trade
        vm.prank(user);
        hook.cancelTrade(user);

        // Verify the trade status is updated
        P2PFactoryHook.Trade memory trade = hook.getTrade(user);
        assertEq(trade.status, 0);
    }

    function testBeforeSwapBlacklistedUserReverts() public {
        PoolKey memory poolKey; // Replace with valid PoolKey mock
        vm.expectRevert("Sender is blacklisted");
        vm.prank(blacklistedUser);
        hook.beforeSwap(blacklistedUser, poolKey, BalanceDelta(0, 0), "");
    }

    function testBeforeSwapSuccess() public {
        PoolKey memory poolKey; // Replace with valid PoolKey mock
        BalanceDelta memory delta = BalanceDelta(100, 100); // Replace with valid BalanceDelta mock

        vm.prank(user);
        hook.beforeSwap(user, poolKey, delta, "");

        // Verify the event
        vm.expectEmit(true, true, true, true);
        emit P2PFactoryHook.BeforeSwap(user, poolKey.token0, poolKey.token1, delta.amount0());
    }
}
