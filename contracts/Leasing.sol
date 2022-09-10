// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import './ERC4907.sol';

contract Leasing is ERC721URIStorage, ERC4907 {

    constructor() ERC4907("Car Leasing", "CL") {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC4907) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

}