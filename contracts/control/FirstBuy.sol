// SPDX-License-Identifier: MIT
pragma solidity = 0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./Utils.sol";
import "./FairyCtrl.sol";

contract FirstBuy is Base {
    using SafeERC20 for IERC20;
    using Address for address;

    uint256 private _inventory;

    uint256 private _pay_amount;

    address private _signServerAddress = 0x2E3Eeb98a73909c5D07EA51DF72bFd1a263CC693;

    address private payTokenAddress = 0xd66c6B4F0be8CE5b39D52E0Fd1344c389929B378; //0x8301F2213c0eeD49a7E28Ae4c3e91722919B8B47;

    address private _fairyCoreAddress;

    address private _fairyCtrlAddress;

    event CurrentFairyInventory(uint256 inventory);

    constructor(address fairyCoreAddress, address fairyCtrlAddress, uint32 inventory, uint256 pay_amount) isContract(fairyCtrlAddress) {
        _fairyCoreAddress = fairyCoreAddress;
        _fairyCtrlAddress = fairyCtrlAddress;
        _inventory = inventory;
        _pay_amount = pay_amount;
        emit CurrentFairyInventory(_inventory);
    }

    function moveOwner(address to) external onlyOwner isExternal(to) {
        transferOwnership(to);
    }
    
    function setSignServerAddress(address account) external onlyOwner isExternal(account) {
        _signServerAddress = account;
    }

    function getCurrentInventory() external view returns(uint256) {
        return _inventory;
    }

    function getRequireAmountPaid() external view returns (uint256) {
        return _pay_amount;
    }

    function setCurrentInventoryAndAmountPaid(uint256 inventory, uint256 pay_amount) external onlyOwner {
        _inventory = inventory;
        _pay_amount = pay_amount;
        emit CurrentFairyInventory(_inventory);
    }

    function buyOnce(uint256 timestamp, bytes memory sign) payable external isExternal(msg.sender) {
        if (_inventory == 0) {
            revert("First buy fairy failed, reason: not enough inventory");
        }

        if (IERC20(payTokenAddress).balanceOf(address(msg.sender)) < _pay_amount) {
            revert("First buy fairy failed, reason: not enough balance");
        }

        if (msg.value < _pay_amount) {
            revert("First buy fairy failed, reason: not enough amount paid");
        }

        bytes memory message = abi.encodePacked(Utils.addressToUint256(msg.sender), timestamp);
        if (!Utils.validSign(_signServerAddress, message, sign)) {
            revert("First buy fairy failed, reason: invalid signature");
        }

        IERC20(payTokenAddress).safeTransferFrom(address(msg.sender), address(getTokensOwner()), _pay_amount);

        _inventory = _inventory - 1;

        IFairyCtrl(_fairyCtrlAddress).mintSpecifyFairy(msg.sender, 0, 0);

        emit CurrentFairyInventory(_inventory);
    }
}