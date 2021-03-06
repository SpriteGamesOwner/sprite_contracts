// SPDX-License-Identifier: MIT
pragma solidity = 0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./Utils.sol";
import "../core/SpriteCore.sol";

contract SpriteCtrl is Base {
    using Counters for Counters.Counter;
    using Address for address;

    mapping (address => Counters.Counter) private withDrawAllocators;

    address private _signServerAddress = 0x2E3Eeb98a73909c5D07EA51DF72bFd1a263CC693;
    
    address private _spriteCoreAddress;

    event OwnerWithdrawSprite(address indexed to, uint256 amount);

    event WithdrawSprite(address indexed to, uint256 withDrawType, uint256 amount, uint256 nonce, bytes sign);

    constructor(address spriteCoreAddress) isContract(spriteCoreAddress) {
        _spriteCoreAddress = spriteCoreAddress;
    }

    function moveOwner(address to) external onlyOwner isExternal(to) {
        transferOwnership(to);
    }
    
    function setSignServerAddress(address account) external onlyOwner isExternal(account) {
        _signServerAddress = account;
    }

    function ownerWithDraw(address to, uint256 amount) external onlyRole(MANAGER_ROLE) isExternal(to) {
        uint256 number = amount * 10 ** 18;
        if (number == 0) {
            revert("Withdraw sprite failed, reason: invalid withdraw amount");
        }

        if (currentBalance() < number) {
            revert("Withdraw sprite failed, reason: sprite balance not enough");
        }
        
        ISpriteCore(_spriteCoreAddress).withDraw(to, number);
        emit OwnerWithdrawSprite(to, number);
    }

    function withDraw(uint256 withDrawType, uint256 amount, uint256 timestamp, bytes memory sign) external isExternal(msg.sender) {
        if (amount == 0) {
            revert("Withdraw sprite failed, reason: invalid withdraw amount");
        }

        if (currentBalance() < amount) {
            revert("Withdraw sprite failed, reason: sprite balance not enough");
        }

        uint256 nonce = withDrawAllocators[msg.sender].current();
        bytes memory message = abi.encodePacked(Utils.addressToUint256(_spriteCoreAddress), Utils.addressToUint256(msg.sender), amount, nonce, withDrawType, timestamp);
        if (!Utils.validSign(_signServerAddress, message, sign)) {
            revert("Withdraw sprite failed, reason: invalid signature");
        }
        
        ISpriteCore(_spriteCoreAddress).withDraw(msg.sender, amount);
        withDrawAllocators[msg.sender].increment();
        emit WithdrawSprite(msg.sender, withDrawType, amount, nonce, sign);
    }

    // ??????Sprite???????????????
    function currentBalance() public view returns (uint256) {
        return IERC20(_spriteCoreAddress).balanceOf(getTokensOwner());
    }
}