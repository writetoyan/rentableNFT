// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import './ERC4907.sol';

error Leasing__PaymentTooLateOrLeaseAllPaid();
error Leasing__OnlyCurrentLeaserCanRenew();
error Leasing__WrongLessee();

///@title A lease creator 
///@author Yannick J.
///@notice You can use this contract to manage all your lease contract
///@notice You cannot sell/transfer the car while there is a lessee
///@dev The classic transferFrom and safeTransferFrom functions are overriden to allow the lessee to exercise his buy option 
///@dev Once the lessee bought got the ownership of the lease, he is free to sell/transfer it
contract Leasing is ERC721URIStorage, ERC4907, Ownable {
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct LeasingInfo {
        string carModel;
        string lesseeName;
        address lesseeAddress;
        uint256 leaseStartingDate;
        uint256 leasingDurationInMonth;
        uint256 upfrontPayment;
        uint256 monthlyPayment;
        uint256 purchaseOptionPrice;
        uint256 numberOfPaymentMade;
    }

///@dev Event emitted when a new lease is created
    event LeasingMinted(
        uint256 indexed tokenId,
        string  indexed tokenURI, 
        string  indexed carModel,
        uint256 leasingDurationInMonth,
        uint256 upfrontPayment,
        uint256 monthlyPayment,
        uint256 purchaseOptionPrice
    );

///@dev Event emitted when there is a lessee for a lease
///@param tokenId is the car leased
///@param lesseeAddress is the address of the lessee
///@param lesseeName is the name of the lessee
    event LesseeSetted(uint256 indexed tokenId, address indexed lesseeAddress, string indexed lesseeName);

///@dev Event emitted when the monthly payment of the lease is paid
///@param _lessee is the address of the lessee
///@param rent is the amount paid
    event MonthlyLeasingPaid(uint256 indexed tokenId, address indexed lessee, uint256 indexed rent);

    bool internal _purchased;
    mapping(uint256 => LeasingInfo) public leases;

    constructor() ERC4907("Car Leasing", "CL") {}

///@notice Provide all the parameter of the lease at mint
///@dev While listing on a marketplace, these parameters have to be used in order to meet the condition of the lease
///@param _leasingDurationInMonth the duration of the lease
///@param _upfrontPayment the payment that have to be paid when entering the lease
///@param _monthlyPayment the amount that the lessee have to pay to honor his lease contract
///@param _purchaseOptionPrice the amount that have to be paid at the end of the lease if the lessee want to own the car
    function mintLeasingNft(
        string memory _tokenURI, 
        string memory _carModel,
        uint256 _leasingDurationInMonth,
        uint256 _upfrontPayment,
        uint256 _monthlyPayment,
        uint256 _purchaseOptionPrice
        ) payable public onlyOwner returns (uint256) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        leases[newItemId].leasingDurationInMonth = _leasingDurationInMonth;
        leases[newItemId].carModel = _carModel;
        leases[newItemId].upfrontPayment = _upfrontPayment;
        leases[newItemId].monthlyPayment = _monthlyPayment;
        leases[newItemId].purchaseOptionPrice = _purchaseOptionPrice;
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, _tokenURI);
        emit LeasingMinted(newItemId, _tokenURI, _carModel, _leasingDurationInMonth, _upfrontPayment, _monthlyPayment, _purchaseOptionPrice);
        return newItemId;       
    }

///@notice All the lessee informations is set 
///@dev The expires parameters is defined to match the requirement of a lease contract
///@param _lesseeAddress is the address of the lessee
///@param _lesseeName is the name of the lessee
    function setLessee(uint256 _tokenId, address _lesseeAddress, string memory _lesseeName) external {
        leases[_tokenId].leaseStartingDate = block.timestamp;
        leases[_tokenId].lesseeAddress = _lesseeAddress;
        leases[_tokenId].lesseeName = _lesseeName;
        _users[_tokenId].expires = uint64(block.timestamp + 30 days);
        setUser(_tokenId, _lesseeAddress, _users[_tokenId].expires);
        emit LesseeSetted(_tokenId, _lesseeAddress, _lesseeName);
    }

///@notice The monthly lease have to be paid before the expiration date
///@dev This function track the number of payment that have to be made during the lifetime of a lease
    function renewMonthlyLeasing(uint256 _tokenId) external payable {
        if(block.timestamp > _users[_tokenId].expires || leases[_tokenId].numberOfPaymentMade >= leases[_tokenId].leasingDurationInMonth - 1) {
            revert Leasing__PaymentTooLateOrLeaseAllPaid();
        }
        uint64 nextPaymentDate = _users[_tokenId].expires + 30 days;
        leases[_tokenId].numberOfPaymentMade += 1; 
        setUser(_tokenId, leases[_tokenId].lesseeAddress, nextPaymentDate);
        emit MonthlyLeasingPaid(_tokenId, msg.sender, msg.value);
    }

///@notice The ownership of the car can only be transfered to the lessee if the option to buy is exercised
///@dev You can use this function to trigger the transfer of the car if the condition defined are met
    function optionToBuy() external {
        _purchased = true;
    }

///@notice While there is a lessee, the car can only be transfered to the lessee when he decide to exercise the option to buy
///@dev This function override the standard transferFrom function
    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (_users[tokenId].user != address(0)) {
            if (!_purchased || to != leases[tokenId].lesseeAddress) {
                revert Leasing__WrongLessee();
            }
        }
        super.transferFrom(from, to, tokenId);
    }

///@notice While there is a lessee, the car can only be transfered to the lessee when he decide to exercise the option to buy
///@dev This function override the standard transferFrom function
    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        if (_users[tokenId].user != address(0)) {
            if (!_purchased || to != leases[tokenId].lesseeAddress) {
                revert Leasing__WrongLessee();
            }
        }
        super.safeTransferFrom(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC4907) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

}