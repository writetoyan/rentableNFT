// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./IERC4907.sol";
import "./Leasing.sol";

interface ILeasing {
    function setLessee(uint256 _tokenId, address _lesseeAddress, string memory _lesseeName) external;
    function renewMonthlyLeasing(uint256 _tokenId) external payable;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function optionToBuy() external;
}

error Marketplace__notTheOwnerOfTheNft();
error Marketplace__AmountSentTooLow();
error Marketplace__NftAlreadyRented();
error Marketplace__lastRentingPeriodNotOver();
error Marketplace__PaymentAmountDoesNotMatch();
error Marketplace__YouCannotPurchaseYet();
error Marketplace__YouHaveNoBalanceToWithdraw();
error Marketplace__WithdrawFailed();

///@title A marketplace for renting NFT
///@author Yannick J.
///@notice You can use this marketplace to list and manage all kind of renting NFT
///@dev The marketplace is lease contract compatible to respond to his particularity
contract Marketplace is ReentrancyGuard {

    struct Listing {
        address owner;
        address tenant;
        address nftAddress;
        uint tokenId;
        uint256 rentPrice;
        uint256 upfrontPayment;
        uint256 purchaseOptionPrice;
        uint256 leasingDurationInMonth;
        uint256 numberOfPaymentMade;
        uint64 rentDuration;
        uint64 expires;
    }

///@dev Event emitted when a new NFT is listed to be rented
    event NftListed(
        address owner,
        address tenant,
        address indexed nftAddress,
        uint indexed tokenId,
        uint256 indexed rentPrice,
        uint256 upfrontPayment,
        uint256 purchaseOptionPrice,
        uint256 leasingDurationInMonth,
        uint256 numberOfPaymentMade,
        uint64 rentDuration,
        uint64 expires
    );

///@dev Event emitted when a NFT is rented
///@param rent is the amount of the rent paid
///@param expires is the date when the rent is over
    event NftRented(address indexed tenant, address indexed nftAddress, uint256 indexed tokenId, uint256 rent, uint256 expires);

///@dev Event emitted when a car is leased
///@param lessee is the address of the lessee
///@param lesseeName is the name of the lessee
    event CarLeased(address indexed lessee, address indexed nftAddress, uint256 indexed tokenId, string lesseeName);

///@dev Event emitted when the monthly mease payment is made
    event LeasePaid(address indexed lessee, address indexed nftAddress, uint256 indexed tokenId);

///@dev Event emitted when the lessee decide to buy the car at the end of the leasing contract
    event OptionExercised(address indexed buyer, address indexed _nftAddress, uint256 indexed tokenId);

    mapping(address => mapping(uint256 => Listing)) public listings;
    mapping(address => uint256) public rentBalance;

///@notice List the NFT with the condition of the rent or lease
///@dev The address of the user and the expiration date is zero 
    function listNft(address _nftAddress, uint256 _tokenId, uint256 _rentPrice, uint256 _upFrontPayment, uint256 _purchasOptionPrice, uint256 _leasingDurationInMonth, uint256 _numberOfPaymentMade, uint64 _rentDuration) external payable {
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
            _upFrontPayment,
            _purchasOptionPrice,
            _leasingDurationInMonth,
            _numberOfPaymentMade,
            _rentDuration,
            0
        );
        emit NftListed(    
            msg.sender,
            address(0),
            _nftAddress,
            _tokenId,
            _rentPrice,
            _upFrontPayment,
            _purchasOptionPrice,
            _leasingDurationInMonth,
            _numberOfPaymentMade,
            _rentDuration,
            0
        );
    }

///@notice You can rent a NFT and use it as defined by the NFT project
///@dev The owner of the NFT have to withdraw his balance on the contract to receive his rent
    function rentNft(address _nftAddress, uint256 _tokenId) external payable nonReentrant {
        if(msg.value < listings[_nftAddress][_tokenId].rentPrice) {
            revert Marketplace__AmountSentTooLow();
        }
        if(listings[_nftAddress][_tokenId].tenant != address(0)) {
            revert Marketplace__NftAlreadyRented();
        }
        rentBalance[listings[_nftAddress][_tokenId].owner] += msg.value;
        uint64 expires = uint64(block.timestamp + listings[_nftAddress][_tokenId].rentDuration);
        IERC4907(_nftAddress).setUser(_tokenId, msg.sender, expires);
        listings[_nftAddress][_tokenId].tenant = msg.sender;
        listings[_nftAddress][_tokenId].expires = expires;
        emit NftRented(msg.sender, _nftAddress, _tokenId, msg.value, expires);
    }

///@notice Lease a car and have the option to buy it at the end
///@dev The leasear have to withdraw his balance to receive his lease payment
    function lease(address _nftAddress, uint256 _tokenId, string memory _lesseeName) external payable {
        if(msg.value < listings[_nftAddress][_tokenId].upfrontPayment + listings[_nftAddress][_tokenId].rentPrice) {
            revert Marketplace__AmountSentTooLow();
        }
        rentBalance[listings[_nftAddress][_tokenId].owner] += msg.value;
        ILeasing(_nftAddress).setLessee(_tokenId, msg.sender, _lesseeName);
        emit CarLeased(msg.sender, _nftAddress, _tokenId, _lesseeName);
    }

///@notice The monthly lease payment have to be made in order to continu using the car
///@dev The leasear have to withdraw his balance to receive his lease payment
    function payLease(address _nftAddress, uint256 _tokenId) external payable {
        if(msg.value != listings[_nftAddress][_tokenId].rentPrice) {
            revert Marketplace__PaymentAmountDoesNotMatch();
        }
        rentBalance[listings[_nftAddress][_tokenId].owner] += msg.value;
        listings[_nftAddress][_tokenId].numberOfPaymentMade += 1;
        ILeasing(_nftAddress).renewMonthlyLeasing(_tokenId);
        emit LeasePaid(msg.sender, _nftAddress, _tokenId);
    }

///@notice The lesse have the option to buy the car at the end of the lease
///@dev The ownership of the car can only be transfered to the current lessee
    function buyLease(address _nftAddress, uint256 _tokenId) external payable {
        if(msg.value < listings[_nftAddress][_tokenId].purchaseOptionPrice) {
            revert Marketplace__AmountSentTooLow();
        }
        if(listings[_nftAddress][_tokenId].numberOfPaymentMade < listings[_nftAddress][_tokenId].leasingDurationInMonth - 1) {
            revert Marketplace__YouCannotPurchaseYet();
        }
        rentBalance[listings[_nftAddress][_tokenId].owner] += msg.value;
        ILeasing(_nftAddress).optionToBuy();
        ILeasing(_nftAddress).safeTransferFrom(listings[_nftAddress][_tokenId].owner, msg.sender, _tokenId);
        emit OptionExercised(msg.sender, _nftAddress, _tokenId);
    }

///@notice Use this function to withdraw your balance on the marketplace
    function withdrawRent() external nonReentrant {
        if(rentBalance[msg.sender] <= 0) {
            revert Marketplace__YouHaveNoBalanceToWithdraw();
        }
        uint256 amount = rentBalance[msg.sender];
        rentBalance[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if(!success) {
            revert Marketplace__WithdrawFailed();
        }
    }
}