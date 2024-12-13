// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../script/NarfexKYC.sol";

contract NarfexKYCTest is Test {
    NarfexKYC kyc;

    address owner = address(0x1);
    address writer = address(0x2);
    address user = address(0x3);
    address blacklistedUser = address(0x4);

    function setUp() public {
        kyc = new NarfexKYC();
        vm.prank(owner);
        kyc.transferOwnership(owner);

        // Set writer
        vm.prank(owner);
        kyc.setWriter(writer);

        // Add user to blacklist
        vm.prank(writer);
        kyc.addToBlacklist(blacklistedUser);
    }

    function testSetWriter() public {
        address newWriter = address(0x5);

        vm.prank(owner);
        kyc.setWriter(newWriter);

        assertEq(kyc.writer(), newWriter);
    }

    function testVerifyAndRevoke() public {
        string memory data = "EncryptedUserData";

        vm.prank(writer);
        kyc.verify(user, data);

        assertTrue(kyc.isKYCVerified(user));
        assertEq(kyc.getData(new address, data);

        vm.prank(writer);
        kyc.revokeVerification(user);

        assertFalse(kyc.isKYCVerified(user));
    }

    function testAddAndRemoveBlacklist() public {
        vm.prank(writer);
        kyc.addToBlacklist(user);

        assertTrue(kyc.getIsBlacklisted(user));

        vm.prank(writer);
        kyc.removeFromBlacklist(user);

        assertFalse(kyc.getIsBlacklisted(user));
    }

    function testBeforeSwapBlacklistedReverts() public {
        PoolKey memory poolKey; // Replace with valid mock
        vm.expectRevert("Sender is blacklisted");
        vm.prank(blacklistedUser);
        kyc.beforeSwap(blacklistedUser, poolKey, IPoolManager.SwapParams(0, 0, 0, 0), "");
    }

    function testBeforeSwapKYCVerifiedSuccess() public {
        string memory data = "EncryptedUserData";

        vm.prank(writer);
        kyc.verify(user, data);

        PoolKey memory poolKey; // Replace with valid mock
        vm.prank(user);
        kyc.beforeSwap(user, poolKey, IPoolManager.SwapParams(0, 0, 0, 0), "");
    }
}
