// SPDX-License-Identifier: MIT
pragma solidity = 0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";

import "./Utils.sol";
import "./FairyCtrl.sol";

contract FirstBuy is Base {
    using Address for address;

    uint256 private _inventory;

    uint256 private _pay_amount;

    address private _signServerAddress = 0x2E3Eeb98a73909c5D07EA51DF72bFd1a263CC693;

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

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function setSignServerAddress(address account) external onlyOwner isExternal(account) {
        _signServerAddress = account;
    }

    function getCurrentInventory() external view returns(uint256) {
        return _inventory;
    }

    function setCurrentInventory(uint256 inventory) external onlyOwner {
        _inventory = inventory;
        emit CurrentFairyInventory(_inventory);
    }

    function getRequireAmountPaid() external view returns (uint256) {
        return _pay_amount;
    }

    function setRequireAmountPaid(uint256 pay_amount) external onlyOwner {
        _pay_amount = pay_amount;
    }

    function buyOnce(uint256 timestamp, bytes memory sign) payable external isExternal(msg.sender) {
        if (_inventory == 0) {
            revert("First buy fairy failed, reason: not enough inventory");
        }

        if (address(msg.sender).balance < _pay_amount) {
            revert("First buy fairy failed, reason: not enough balance");
        }

        if (msg.value < _pay_amount) {
            revert("First buy fairy failed, reason: not enough amount paid");
        }

        bytes memory message = abi.encodePacked(Utils.addressToUint256(msg.sender), timestamp);
        if (!Utils.validSign(_signServerAddress, message, sign)) {
            revert("First buy fairy failed, reason: invalid signature");
        }

        payable(address(owner())).transfer(msg.value);

        _inventory = _inventory - 1;

        IFairyCtrl(_fairyCtrlAddress).mintSpecifyFairy(msg.sender, 0, 0);

        emit CurrentFairyInventory(_inventory);
    }

    function freeze() public onlyOwner {
        _pause();
    }
}