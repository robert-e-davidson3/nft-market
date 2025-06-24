// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NftMarket is Ownable {
    uint256 constant fee = 25; // 25/1000 aka 2.5%
    uint256 constant minPrice = 0.001 ether;

    // seller => nftAddress => tokenId => price
    mapping(address => mapping(address => mapping(uint256 => uint256))) public nftsForSale;

    event NftListed(address indexed seller, address indexed nftAddress, uint256 indexed tokenId, uint256 price);
    event NftSold(address indexed seller, address indexed nftAddress, uint256 indexed tokenId, uint256 price);
    event NftBought(address indexed buyer, address indexed nftAddress, uint256 indexed tokenId, uint256 price);
    event NftListingCancelled(address indexed seller, address indexed nftAddress, uint256 indexed tokenId);

    constructor() Ownable(msg.sender) {}

    function listForSale(address nftAddress, uint256 tokenId, uint256 price) external {
        IERC721 nft = IERC721(nftAddress);
        require(nft.ownerOf(tokenId) == msg.sender, "You do not own this NFT");
        require(price >= minPrice, "Price must be at least 0.001 ether");

        // Will revert if msg.sender does not own the NFT
        nft.transferFrom(msg.sender, address(this), tokenId);

        nftsForSale[msg.sender][nftAddress][tokenId] = price;

        emit NftListed(msg.sender, nftAddress, tokenId, price);
    }

    function buy(address payable seller, address nftAddress, uint256 tokenId) external payable {
        uint256 price = nftsForSale[seller][nftAddress][tokenId];
        require(price > 0, "NFT is not for sale");

        uint256 feeAmount = (price * fee) / 1000; // 2.5% fee
        require(msg.value == price + feeAmount, "Incorrect payment amount");

        // Prevent re-entrancy attacks by doing this first
        delete nftsForSale[seller][nftAddress][tokenId];

        IERC721 nft = IERC721(nftAddress);
        nft.transferFrom(address(this), msg.sender, tokenId);

        seller.transfer(price);

        emit NftSold(seller, nftAddress, tokenId, price);
        emit NftBought(msg.sender, nftAddress, tokenId, price);
    }

    function cancelListing(address nftAddress, uint256 tokenId) external {
        uint256 price = nftsForSale[msg.sender][nftAddress][tokenId];
        require(price > 0, "NFT is not for sale");
        delete nftsForSale[msg.sender][nftAddress][tokenId];
        IERC721(nftAddress).transferFrom(address(this), msg.sender, tokenId);
        emit NftListingCancelled(msg.sender, nftAddress, tokenId);
    }

    function takeFee() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
