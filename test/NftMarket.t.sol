// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "forge-std/Vm.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {NftMarket} from "../src/NftMarket.sol";

contract TestERC721 is ERC721 {
    constructor() ERC721("TestNFT", "TNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract NftMarketTest is Test {
    NftMarket public market;
    TestERC721 public nft;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(0x1234);
        user1 = address(0x1111);
        user2 = address(0x2222);
        vm.deal(owner, 1 ether);
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        nft = new TestERC721();

        vm.prank(owner);
        market = new NftMarket();
    }

    function test_listForSale() public {
        // setup
        address seller = user1;
        nft.mint(seller, 42);

        vm.startPrank(seller);
        nft.approve(address(market), 42);

        // test
        vm.recordLogs();
        market.listForSale(address(nft), 42, 0.1 ether);
        vm.stopPrank();

        // verify
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 2, "logs.length should be 2");
        assertEq(logs[0].emitter, address(nft), "First log is from the NFT");
        assertEq(logs[1].emitter, address(market), "Second log is from the market");
        assertEq(
            logs[1].topics[0], keccak256("NftListed(address,address,uint256,uint256)"), "Event should be NftListed"
        );
        assertEq(address(uint160(uint256(logs[1].topics[1]))), seller, "First topic should be the seller address");
        assertEq(address(uint160(uint256(logs[1].topics[2]))), address(nft), "Second topic should be the NFT address");
        assertEq(uint256(logs[1].topics[3]), 42, "Third topic should be the token ID");
        assertEq(abi.decode(logs[1].data, (uint256)), 0.1 ether, "Data should be the price");

        assertEq(
            market.nftsForSale(seller, address(nft), 42),
            0.1 ether,
            "NFT should be listed for sale at the correct price"
        );
        assertEq(nft.ownerOf(42), address(market), "NFT should be owned by the market");
    }

    function test_buy() public {
        // setup
        address seller = user1;
        address buyer = user2;
        nft.mint(seller, 42);

        vm.startPrank(seller);
        nft.approve(address(market), 42);

        // test
        market.listForSale(address(nft), 42, 0.1 ether);
        vm.stopPrank();

        vm.recordLogs();
        vm.startPrank(buyer);
        market.buy{value: 0.1 ether + (0.1 ether * 25 / 1000)}(payable(seller), address(nft), 42);
        vm.stopPrank();

        // verify
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 3, "Should be 3 logs");
        assertEq(logs[0].emitter, address(nft), "First log is from the NFT");
        assertEq(logs[1].emitter, address(market), "Second log is from the market");
        assertEq(logs[2].emitter, address(market), "Third log is from the market");

        assertEq(logs[1].topics[0], keccak256("NftSold(address,address,uint256,uint256)"), "Event should be NftSold");
        assertEq(address(uint160(uint256(logs[1].topics[1]))), seller, "First topic should be the seller address");
        assertEq(address(uint160(uint256(logs[1].topics[2]))), address(nft), "Second topic should be the NFT address");

        assertEq(uint256(logs[1].topics[3]), 42, "Third topic should be the token ID");
        assertEq(abi.decode(logs[1].data, (uint256)), 0.1 ether, "Data should be the price");

        assertEq(
            logs[2].topics[0], keccak256("NftBought(address,address,uint256,uint256)"), "Event should be NftBought"
        );
        assertEq(address(uint160(uint256(logs[2].topics[1]))), buyer, "First topic should be the buyer address");
        assertEq(address(uint160(uint256(logs[2].topics[2]))), address(nft), "Second topic should be the NFT address");

        assertEq(uint256(logs[2].topics[3]), 42, "Third topic should be the token ID");
        assertEq(abi.decode(logs[2].data, (uint256)), 0.1 ether, "Data should be the price");

        assertEq(market.nftsForSale(seller, address(nft), 42), 0, "NFT should be not be listed");
        assertEq(nft.ownerOf(42), address(buyer), "NFT should be owned by the buyer");
        assertEq(
            buyer.balance, 1.0 ether - (0.1 ether + (0.1 ether * 25 / 1000)), "Buyer should have spent 0.1 ether + fee"
        );
        assertEq(seller.balance, 1.0 ether + 0.1 ether, "Seller should have received 0.1 ether");
    }

    function test_cancelListing() public {
        // setup
        address seller = user1;
        address buyer = user2;
        nft.mint(seller, 42);

        vm.startPrank(seller);
        nft.approve(address(market), 42);

        // test
        market.listForSale(address(nft), 42, 0.1 ether);

        vm.recordLogs();
        market.cancelListing(address(nft), 42);
        vm.stopPrank();

        // verify
        vm.startPrank(buyer);
        vm.expectRevert("NFT is not for sale");
        market.buy{value: 0.1 ether + (0.1 ether * 25 / 1000)}(payable(seller), address(nft), 42);
        vm.stopPrank();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 2, "Should be 2 logs");
        assertEq(logs[0].emitter, address(nft), "First log is from the NFT");
        assertEq(logs[1].emitter, address(market), "Second log is from the market");
        assertEq(
            logs[1].topics[0],
            keccak256("NftListingCancelled(address,address,uint256)"),
            "Event should be NftListingCancelled"
        );
        assertEq(address(uint160(uint256(logs[1].topics[1]))), seller, "First topic should be the seller address");
        assertEq(address(uint160(uint256(logs[1].topics[2]))), address(nft), "Second topic should be the NFT address");
        assertEq(uint256(logs[1].topics[3]), 42, "Third topic should be the token ID");

        assertEq(market.nftsForSale(seller, address(nft), 42), 0, "NFT should not be listed for sale");
        assertEq(nft.ownerOf(42), seller, "NFT should still be owned by the seller");
        assertEq(buyer.balance, 1.0 ether, "Buyer should not have spent any ether");
        assertEq(seller.balance, 1.0 ether, "Seller should not have received any ether");
        assertEq(address(market).balance, 0, "No fees should have been collected");
    }

    function test_takeFee() public {
        // setup
        address seller = user1;
        address buyer = user2;
        nft.mint(seller, 42);

        vm.startPrank(seller);
        nft.approve(address(market), 42);
        market.listForSale(address(nft), 42, 0.1 ether);
        vm.startPrank(buyer);
        market.buy{value: 0.1 ether + (0.1 ether * 25 / 1000)}(payable(seller), address(nft), 42);
        vm.stopPrank();

        // test

        vm.startPrank(owner);
        market.takeFee();
        vm.stopPrank();

        // verify
        assertEq(address(market).balance, 0, "Market balance should be 0 after taking fee");
        assertEq(owner.balance, 1 ether + (0.1 ether * 25 / 1000), "Owner should have received the fee");
    }
}
