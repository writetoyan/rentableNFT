// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import './ERC4907.sol';

error Leasing__PaymentTooLateOrLeaseAllPaid();
error Leasing__OnlyCurrentLeaserCanRenew();
error Leasing__WrongLessee();

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

    bool internal _purchased;
    mapping(uint256 => LeasingInfo) public leases;

    constructor() ERC4907("Car Leasing", "CL") {}

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
        return newItemId;
    }

    function setLessee(uint256 _tokenId, address _lesseeAddress, string memory _lesseeName) external {
        leases[_tokenId].leaseStartingDate = block.timestamp;
        leases[_tokenId].lesseeAddress = _lesseeAddress;
        leases[_tokenId].lesseeName = _lesseeName;
        _users[_tokenId].expires = uint64(block.timestamp + 30 days);
        setUser(_tokenId, _lesseeAddress, _users[_tokenId].expires);
    }

    function renewMonthlyLeasing(uint256 _tokenId) external payable {
        if(block.timestamp > _users[_tokenId].expires || leases[_tokenId].numberOfPaymentMade >= leases[_tokenId].leasingDurationInMonth - 1) {
            revert Leasing__PaymentTooLateOrLeaseAllPaid();
        }
        uint64 nextPaymentDate = _users[_tokenId].expires + 30 days;
        leases[_tokenId].numberOfPaymentMade += 1; 
        setUser(_tokenId, leases[_tokenId].lesseeAddress, nextPaymentDate);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (_users[tokenId].user != address(0)) {
            if (!_purchased || to != leases[tokenId].lesseeAddress) {
                revert Leasing__WrongLessee();
            }
        }
        super.transferFrom(from, to, tokenId);
    }

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

    function _optionToBuy() external {
        _purchased = true;
    }

}