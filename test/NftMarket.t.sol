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
        assertEq(
            logs[0].emitter, address(nft), "First log is from the NFT"
        );
        assertEq(logs[1].emitter, address(market), "Second log is from the market");
        assertEq(
            logs[1].topics[0], keccak256("NftListed(address,address,uint256,uint256)"), "Event should be NftListed"
        );
        assertEq(
            address(uint160(uint256(logs[1].topics[1]))),
            seller,
            "First topic should be the seller address"
        );
        assertEq(
            address(uint160(uint256(logs[1].topics[2]))),
            address(nft),
            "Second topic should be the NFT address");
        
        assertEq(
            uint256(logs[1].topics[3]),
            42,
            "Third topic should be the token ID"
        );
        assertEq(
            abi.decode(logs[1].data, (uint256)),
            0.1 ether,
            "Data should be the price"
        );

        assertEq(
            market.nftsForSale(seller, address(nft), 42),
            0.1 ether,
            "NFT should be listed for sale at the correct price"
        );
    }
}
