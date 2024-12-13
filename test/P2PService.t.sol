// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../script/P2PService.sol";
import "../script/INarfexP2pFactory.sol";
import "../script/INarfexP2pRouter.sol";

contract MockFactory is INarfexP2pFactory {
    mapping(address => bool) public kycVerified;

    function isKYCVerified(address user) external view returns (bool) {
        return kycVerified[user];
    }

    function mockSetKYCVerified(address user, bool verified) external {
        kycVerified[user] = verified;
    }
}

contract P2PServiceTest is Test {
    P2PService p2pService;
    MockFactory factory;
    address router = address(0x2);
    address owner = address(0x1);
    address buyer = address(0x3);
    address seller = address(0x4);
    address fiatToken = address(0x5);

    function setUp() public {
        factory = new MockFactory();
        p2pService = new P2PService(address(factory), router);

        vm.prank(owner);
        p2pService.transferOwnership(owner);

        // Add fiat token and verify users
        vm.prank(owner);
        p2pService.addFiatToken(fiatToken);

        factory.mockSetKYCVerified(buyer, true);
        factory.mockSetKYCVerified(seller, true);
    }

    function testAddAndRemoveFiatToken() public {
        address newFiat = address(0x6);

        vm.prank(owner);
        p2pService.addFiatToken(newFiat);

        assertTrue(p2pService.isSupportedFiatToken(newFiat));

        vm.prank(owner);
        p2pService.removeFiatToken(newFiat);

        assertFalse(p2pService.isSupportedFiatToken(newFiat));
    }

    function testCreateTrade() public {
        uint amount = 1000;
        uint price = 500;

        vm.prank(buyer);
        p2pService.createTrade(buyer, seller, amount, price, fiatToken);

        bytes32 tradeId = keccak256(abi.encodePacked(block.timestamp, buyer, seller, amount, price, fiatToken));
        P2PService.Trade memory trade = p2pService.getTrade(tradeId);

        assertEq(trade.buyer, buyer);
        assertEq(trade.seller, seller);
        assertEq(trade.amount, amount);
        assertEq(trade.price, price);
        assertEq(trade.fiatToken, fiatToken);
        assertEq(trade.status, 0); // Created
    }

    function testConfirmTrade() public {
        uint amount = 1000;
        uint price = 500;

        vm.prank(buyer);
        p2pService.createTrade(buyer, seller, amount, price, fiatToken);

        bytes32 tradeId = keccak256(abi.encodePacked(block.timestamp, buyer, seller, amount, price, fiatToken));

        vm.prank(buyer);
        p2pService.confirmTrade(tradeId);

        P2PService.Trade memory trade = p2pService.getTrade(tradeId);
        assertEq(trade.status, 1); // Confirmed
    }

    function testCancelTrade() public {
        uint amount = 1000;
        uint price = 500;

        vm.prank(buyer);
        p2pService.createTrade(buyer, seller, amount, price, fiatToken);

        bytes32 tradeId = keccak256(abi.encodePacked(block.timestamp, buyer, seller, amount, price, fiatToken));

        vm.prank(buyer);
        p2pService.cancelTrade(tradeId);

        P2PService.Trade memory trade = p2pService.getTrade(tradeId);
        assertEq(trade.status, 2); // Cancelled
    }

    function testCreateTradeWithUnsupportedFiatReverts() public {
        uint amount = 1000;
        uint price = 500;
        address unsupportedFiat = address(0x6);

        vm.expectRevert("P2PService: Unsupported fiat token");
        vm.prank(buyer);
        p2pService.createTrade(buyer, seller, amount, price, unsupportedFiat);
    }
}
