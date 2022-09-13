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

///@title A guestbook minter
///@author Yannick J.
///@notice People can rent your guestbook to have the right to leave message. The guestbook can only be transfered to the recipient you define at mint
///@dev The classic transferFrom and safeTransferFrom functions are overriden to meet the project requirement
contract GuestBook is ERC721URIStorage, ERC4907, Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

///@dev Event that is emitted when an user write on the guestbook
///@param _tokenId identifies the guestbook
///@param _user the address of the user that wrote a message on the guestbook
///@param _message the message wrote
  event ComplimentWritten(uint256 indexed _tokenId, address indexed _user, string indexed _message);

///@dev Event that is emitted when a new guestbook is minted
///@param _tokenId is the id of the guestbook minted
///@param _finalOwner is the unique address to which the guestbook can be transfered
  event NewGuestBook(uint256 indexed _tokenId, string _tokenURI, address indexed _finalOwner);

  string[] public compliments;
  mapping(uint256 => address) public finalOwner;

  constructor() ERC4907("GuestBook", "GB") {
  }

///@notice You can personalize the image of the NFT by uploading one on IPFS and providing the URI at mint
///@notice You have to define a recipient at mint. This guest book can only be transfered to him
///@notice The cost of one guestbook is 1 ETH  
///@dev The contract have a balance that only the owner is able to withdraw
///@param _tokenURI is the URI of the cover of th guestbook uploaded on IPFS
///@param _finalOwner is the unique recipient of the guestbook
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

///@notice People who want to leave message on the guestbook have to rent it
///@dev All the compliments are stored in an array
///@param _message Is the message that an user want to write on the guestbook
  function writeCompliment(uint256 tokenId, string memory _message) external {
    if (msg.sender != userOf(tokenId)) {
      revert GuestBook__NotAuthorizedToWrite();
    }
    compliments.push(_message);
    emit ComplimentWritten(tokenId, msg.sender, _message);
  }

///@dev Only the owner of the contract can withdraw the balance 
  function withdraw() external onlyOwner {
    (bool succeed, ) = payable(msg.sender).call{value: address(this).balance}("");
    if(!succeed) {
      revert GuestBook__WithdrawFailed();
    }
  }

///@notice The guestbook can only be transfered to the address defined at mint
///@dev This function override the standard transferFrom function
  function transferFrom(address from, address to, uint256 tokenId) public override {
    if (to != finalOwner[tokenId]) {
      revert GuestBook__WrongFinalOwner();
    }
    super.transferFrom(from, to, tokenId);
  }

///@notice The guestbook can only be transfered to the address defined at mint
///@dev This function override the standard transferFrom function
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
