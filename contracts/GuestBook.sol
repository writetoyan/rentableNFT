// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC4907.sol";

error GuestBook__NotEnoughETH();
error GuestBook__NotAuthorizedToWrite();
error GuestBook__WrongFinalOwner();
error GuestBook__WithdrawFailed();

contract GuestBook is ERC721URIStorage, ERC4907, Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  event ComplimentWritten(uint256 indexed _tokenId, address indexed _user, string indexed _message);
  event NewGuestBook(uint256 indexed _tokenId, string _tokenURI, address indexed _finalOwner);

  string[] public compliments;
  mapping(uint256 => address) public finalOwner;

  constructor() ERC4907("GuestBook", "GB") {
  }

  function mintNft(string memory _tokenURI, address _finalOwner) payable public returns (uint256) {
    if (msg.value <= 1*10*18) {
      revert GuestBook__NotEnoughETH();
    }
    _tokenIds.increment();
    uint256 newItemId = _tokenIds.current();
    finalOwner[newItemId] = _finalOwner;
    _safeMint(msg.sender, newItemId);
    _setTokenURI(newItemId, _tokenURI); 
    emit NewGuestBook(newItemId, _tokenURI, _finalOwner);
    return newItemId;
  }

  function writeCompliment(uint256 tokenId, string memory _message) external {
    if (msg.sender != userOf(tokenId)) {
      revert GuestBook__NotAuthorizedToWrite();
    }
    compliments.push(_message);
    emit ComplimentWritten(tokenId, msg.sender, _message);
  }

  function withdraw() external onlyOwner {
    (bool succeed, ) = payable(msg.sender).call{value: address(this).balance}("");
    if(!succeed) {
      revert GuestBook__WithdrawFailed();
    }
  }

  function transferFrom(address from, address to, uint256 tokenId) public override {
    if (to != finalOwner[tokenId]) {
      revert GuestBook__WrongFinalOwner();
    }
    super.transferFrom(from, to, tokenId);
  }

 function safeTransferFrom(address from, address to, uint256 tokenId) public override {
    if (to != finalOwner[tokenId]) {
      revert GuestBook__WrongFinalOwner();
    }
    super.safeTransferFrom(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC4907) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

}
