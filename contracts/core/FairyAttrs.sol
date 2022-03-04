// SPDX-License-Identifier: MIT
pragma solidity = 0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../control/Utils.sol";

contract FairyAttrs is Base, IFairyAttrs {
    bytes32 private constant CONTROL_ROLE = keccak256("CONTROL_ROLE");

    mapping (uint256 => mapping (uint256 => uint256)) private fairyAttrsTable;

    constructor() {
        
    }

    function setController(address controller) external onlyOwner isContract(controller) {
        grantRole(CONTROL_ROLE, controller);
    }

    function moveOwner(address to) external onlyOwner isExternal(to) {
        transferOwnership(to);
    }
    function getAttr(uint256 tokenId, uint256 index) external view isContract(msg.sender) returns (uint256) {
        return fairyAttrsTable[tokenId][index];
    }

    function setAttr(uint256 tokenId, uint256 index, uint256 value) external onlyRole(CONTROL_ROLE) {
        fairyAttrsTable[tokenId][index] = value;
    }
}
