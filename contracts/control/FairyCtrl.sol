// SPDX-License-Identifier: MIT
pragma solidity = 0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./Utils.sol";
import "../core/FairyCore.sol";

contract FairyCtrl is Base, IFairyCtrl {
    using Counters for Counters.Counter;
    using Address for address;

    bytes32 private constant CONTROL_ROLE = keccak256("CONTROL_ROLE");
    
    Counters.Counter private _tokenIdCounter;

    address private _fairyCoreAddress;

    address private _fairyAttrsAddress;
    
    string private _tokenURIPrefix = "https://storage.googleapis.com/sprite-kingdom/";
    
    string private _tokenURISuffix = "/description.json";

    event FairyLevelup(uint256 mainId, uint256 burnId, uint256 currentLevel);

    event FairyBreeding(address indexed owner, uint256 fatherCount, uint256 motherCount, uint256 fatherId, uint256 motherId, uint256 indexed childId, uint256 level);

    constructor(address fairyCoreAddress, address fairyAttrsAddress) isContract(fairyCoreAddress) {
        _fairyCoreAddress = fairyCoreAddress;
        _fairyAttrsAddress = fairyAttrsAddress;
    }

    function setController(address controller) external onlyOwner isContract(controller) {
        grantRole(CONTROL_ROLE, controller);
    }

    function moveOwner(address to) external onlyOwner isExternal(to) {
        transferOwnership(to);
    }
    
    function setTokenURIPrefix(string memory tokenURIPrefix) external onlyOwner {
        _tokenURIPrefix = tokenURIPrefix;
    }
    
    function setTokenURISuffix(string memory tokenURISuffix) external onlyOwner {
        _tokenURISuffix = tokenURISuffix;
    }

    function isOwns(address account, uint256 tokenId) external view isContract(msg.sender) returns (bool) {
        return (IERC721(_fairyCoreAddress).ownerOf(tokenId) == account);
    }

    function currentBreedingCount(uint256 tokenId) external view isContract(msg.sender) returns (uint256) {
        return IFairyAttrs(_fairyAttrsAddress).getAttr(tokenId, 2);
    }

    function currentTokenId() public view isContract(msg.sender) returns (uint256) {
        return _tokenIdCounter.current() * 10 + 10001;
    }

    function mintSpecifyFairy(address to, uint256 level, uint256 breeding_count) public onlyRole(CONTROL_ROLE) isContract(msg.sender) isExternal(to) returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current() * 10 + 10001;

        IFairyCore(_fairyCoreAddress).mintOnce(to, tokenId);

        IFairyCore(_fairyCoreAddress).setTokenURI(tokenId, createTokenURI(tokenId, level));

        IFairyAttrs(_fairyAttrsAddress).setAttr(tokenId, 0, 0);
        IFairyAttrs(_fairyAttrsAddress).setAttr(tokenId, 1, 0);
        IFairyAttrs(_fairyAttrsAddress).setAttr(tokenId, 2, breeding_count);
        IFairyAttrs(_fairyAttrsAddress).setAttr(tokenId, 3, level);

        _tokenIdCounter.increment();

        return tokenId;
    }

    function levelUpFairy(uint256 mainId, uint256 burnId, uint256 level) public onlyRole(CONTROL_ROLE) isContract(msg.sender) {
        bytes memory payload0 = abi.encodeWithSignature("setTokenURI(uint256, string memory)", mainId, createTokenURI(mainId, level)); 
        (bool success0, bytes memory returnData0) = address(_fairyCoreAddress).call(payload0);
        require(success0, string(abi.encodePacked("Mint specify fairy failed, reason: ", returnData0)));


        bytes memory payload1 = abi.encodeWithSignature("burnFairy(uint256)", burnId); 
        (bool success1, bytes memory returnData1) = address(_fairyCoreAddress).call(payload1);
        require(success1, string(abi.encodePacked("Mint specify fairy failed, reason: ", returnData1)));

        
        emit FairyLevelup(mainId, burnId, level);
    }

    function breedFairy(address to, uint256 fatherId, uint256 motherId, uint256 level) public onlyRole(CONTROL_ROLE) returns (uint256) {
        uint256 tokenId = mintSpecifyFairy(to, level, 0);

        uint256 fatherBreedingCount = IFairyAttrs(_fairyAttrsAddress).getAttr(fatherId, 2);
        uint256 motherBreedingCount = IFairyAttrs(_fairyAttrsAddress).getAttr(motherId, 2);
        uint256 newFatherBreedingCount = fatherBreedingCount + 1;
        uint256 newMotherBreedingCount = motherBreedingCount + 1;
        IFairyAttrs(_fairyAttrsAddress).setAttr(fatherId, 2, newFatherBreedingCount);
        IFairyAttrs(_fairyAttrsAddress).setAttr(motherId, 2, newMotherBreedingCount);

        IFairyAttrs(_fairyAttrsAddress).setAttr(tokenId, 0, fatherId);
        IFairyAttrs(_fairyAttrsAddress).setAttr(tokenId, 1, motherId);

        emit FairyBreeding(to, newFatherBreedingCount, newMotherBreedingCount, fatherId, motherId, tokenId, level);

        return tokenId;
    }

    function createTokenURI (uint256 tokenId, uint256 level) internal view returns(string memory) {
        string memory _tokenId = toString(tokenId);
        string memory _level = toString(level);
        string memory uri = concatTokenURI(_tokenId, _level);

        return uri;
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    function concatTokenURI(string memory tokenId, string memory level) internal view returns (string memory) {
        return string(abi.encodePacked(_tokenURIPrefix, tokenId, '/', level, _tokenURISuffix));
    }
}
