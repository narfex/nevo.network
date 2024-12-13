// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../script/ArbitrationHook.sol";
import "../script/P2PService.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ArbitrationHookTest is Test {
    ArbitrationHook arbitrationHook;
    address owner = address(0x1);
    address lawyer = address(0x2);
    address nonLawyer = address(0x3);

    function setUp() public {
        arbitrationHook = new ArbitrationHook();
        vm.prank(owner);
        arbitrationHook.transferOwnership(owner);
    }

    function testAddLawyer() public {
        vm.prank(owner);
        arbitrationHook.addLawyer(lawyer);
        assertTrue(arbitrationHook.isLawyerActive(lawyer));
    }

    function testRemoveLawyer() public {
        vm.prank(owner);
        arbitrationHook.addLawyer(lawyer);
        vm.prank(owner);
        arbitrationHook.removeLawyer(lawyer);
        assertFalse(arbitrationHook.isLawyerActive(lawyer));
    }

    function testSetSchedule() public {
        vm.prank(owner);
        arbitrationHook.addLawyer(lawyer);

        bool[7][24] memory newSchedule;
        newSchedule[1][10] = false; // Disable Tuesday 10 AM

        vm.prank(lawyer);
        arbitrationHook.setSchedule(newSchedule);

        assertFalse(arbitrationHook.isLawyerActive(lawyer));
    }

    function testBeforeSwapWithActiveLawyer() public {
        vm.prank(owner);
        arbitrationHook.addLawyer(lawyer);

        vm.prank(lawyer);
        arbitrationHook.setIsActive(true);

        // Call beforeSwap and ensure it does not revert
        arbitrationHook.beforeSwap(lawyer, PoolKey({token0: address(0), token1: address(1)}), IPoolManager.SwapParams(0, 0, 0), "");
    }

    function testBeforeSwapWithInactiveLawyer() public {
        vm.prank(owner);
        arbitrationHook.addLawyer(lawyer);
        vm.expectRevert("Lawyer is not active");
        arbitrationHook.beforeSwap(lawyer, PoolKey({token0: address(0), token1: address(1)}), IPoolManager.SwapParams(0, 0, 0), "");
    }
}

contract P2PServiceTest is Test {
    P2PService p2pService;
    ERC20 mockToken;
    address owner = address(0x1);
    address buyer = address(0x2);
    address seller = address(0x3);

    function setUp() public {
        mockToken = new ERC20("MockToken", "MKT", 18);
        p2pService = new P2PService(address(this), address(this));
        vm.prank(owner);
        p2pService.transferOwnership(owner);

        vm.prank(owner);
        p2pService.addFiatToken(address(mockToken));
    }

    function testAddFiatToken() public {
        vm.prank(owner);
        p2pService.addFiatToken(address(mockToken));
        assertTrue(p2pService.isSupportedFiatToken(address(mockToken)));
    }

    function testRemoveFiatToken() public {
        vm.prank(owner);
        p2pService.removeFiatToken(address(mockToken));
        assertFalse(p2pService.isSupportedFiatToken(address(mockToken)));
    }

    function testCreateTrade() public {
        vm.prank(owner);
        p2pService.createTrade(buyer, seller, 100, 10, address(mockToken));

        bytes32 tradeId = keccak256(abi.encodePacked(block.timestamp, buyer, seller, 100, 10, address(mockToken)));
        (address tBuyer, address tSeller, uint tAmount,,,) = p2pService.getTrade(tradeId);

        assertEq(tBuyer, buyer);
        assertEq(tSeller, seller);
        assertEq(tAmount, 100);
    }

    function testConfirmTrade() public {
        vm.prank(owner);
        p2pService.createTrade(buyer, seller, 100, 10, address(mockToken));

        bytes32 tradeId = keccak256(abi.encodePacked(block.timestamp, buyer, seller, 100, 10, address(mockToken)));

        vm.prank(buyer);
        mockToken.approve(address(p2pService), 100);

        vm.prank(buyer);
        p2pService.confirmTrade(tradeId);

        (, , , uint status,,) = p2pService.getTrade(tradeId);
        assertEq(status, 1);
    }

    function testCancelTrade() public {
        vm.prank(owner);
        p2pService.createTrade(buyer, seller, 100, 10, address(mockToken));

        bytes32 tradeId = keccak256(abi.encodePacked(block.timestamp, buyer, seller, 100, 10, address(mockToken)));
        vm.prank(buyer);
        p2pService.cancelTrade(tradeId);

        (, , , uint status,,) = p2pService.getTrade(tradeId);
        assertEq(status, 2);
    }
}
