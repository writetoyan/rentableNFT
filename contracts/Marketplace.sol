// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./IERC4907.sol";
import "./Leasing.sol";

interface ILeasing {
    function setLessee(uint256 _tokenId, address _lesseeAddress, string memory _lesseeName) external;
    function renewMonthlyLeasing(uint256 _tokenId) external payable;
}

error Marketplace__notTheOwnerOfTheNft();
error Marketplace__AmountSentTooLow();
error Marketplace__NftAlreadyRented();
error Marketplace__lastRentingPeriodNotOver();
error Leasing__PaymentAmountDoesNotMatch();

contract Marketplace is ReentrancyGuard {

    struct Listing {
        address owner;
        address tenant;
        address nftAddress;
        uint tokenId;
        uint256 rentPrice;
        uint64 rentDuration;
        uint64 expires;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;

    function listNft(address _nftAddress, uint256 _tokenId, uint256 _rentPrice, uint64 _rentDuration) external payable {
        if(msg.sender != IERC721(_nftAddress).ownerOf(_tokenId)) {
            revert Marketplace__notTheOwnerOfTheNft();
        }
        if(block.timestamp < listings[_nftAddress][_tokenId].expires) {
            revert Marketplace__lastRentingPeriodNotOver();
        }
        listings[_nftAddress][_tokenId] = Listing(
            msg.sender,
            address(0),
            _nftAddress,
            _tokenId,
            _rentPrice,
            _rentDuration,
            0
        );
    }

    function rentNft(address _nftAddress, uint256 _tokenId) external payable nonReentrant {
        if(msg.value < listings[_nftAddress][_tokenId].rentPrice) {
            revert Marketplace__AmountSentTooLow();
        }
        if(listings[_nftAddress][_tokenId].tenant != address(0)) {
            revert Marketplace__NftAlreadyRented();
        }
        uint64 expires = uint64(block.timestamp + listings[_nftAddress][_tokenId].rentDuration);
        IERC4907(_nftAddress).setUser(_tokenId, msg.sender, expires);
        listings[_nftAddress][_tokenId].tenant = msg.sender;
        listings[_nftAddress][_tokenId].expires = expires;
    }

    function lease(address _nftAddress, uint256 _tokenId, string memory _lesseeName) external payable {
        ILeasing(_nftAddress).setLessee(_tokenId, msg.sender, _lesseeName);
    }

    function payLease(address _nftAddress, uint256 _tokenId) external payable {
        if(msg.value != listings[_nftAddress][_tokenId].rentPrice) {
            revert Leasing__PaymentAmountDoesNotMatch();
        }
        ILeasing(_nftAddress).renewMonthlyLeasing(_tokenId);
    }
    

}