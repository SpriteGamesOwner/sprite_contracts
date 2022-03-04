// SPDX-License-Identifier: MIT
pragma solidity = 0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./Utils.sol";
import "../core/MoneyCore.sol";

contract MoneyCtrl is Base {
    using Counters for Counters.Counter;
    using Address for address;

    mapping (address => Counters.Counter) private withDrawAllocators;

    address private _signServerAddress = 0x2E3Eeb98a73909c5D07EA51DF72bFd1a263CC693;
    
    address private _moneyCoreAddress;

    event OwnerWithdrawMoney(address indexed to, uint256 amount);

    event WithdrawMoney(address indexed to, uint256 withDrawType, uint256 amount, uint256 nonce, bytes sign);

    constructor(address MoneyCoreAddress) isContract(MoneyCoreAddress) {
        _moneyCoreAddress = MoneyCoreAddress;
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
            IMoneyCore(_moneyCoreAddress).mint(to, number);
        } else {
            IMoneyCore(_moneyCoreAddress).withDraw(to, number);
        }

        emit OwnerWithdrawMoney(to, number);
    }

    function withDraw(uint256 withDrawType, uint256 amount, uint256 timestamp, bytes memory sign) external isExternal(msg.sender) {
        if (amount == 0) {
            revert("Withdraw Money failed, reason: invalid withdraw amount");
        }

        uint256 nonce = withDrawAllocators[msg.sender].current();
        bytes memory message = abi.encodePacked(Utils.addressToUint256(_moneyCoreAddress), Utils.addressToUint256(msg.sender), amount, nonce, withDrawType, timestamp);
        if (!Utils.validSign(_signServerAddress, message, sign)) {
            revert("Withdraw Money failed, reason: invalid signature");
        }

        if (currentBalance() < amount) {
            IMoneyCore(_moneyCoreAddress).mint(msg.sender, amount);
        } else {
            IMoneyCore(_moneyCoreAddress).withDraw(msg.sender, amount);
        }
        
        withDrawAllocators[msg.sender].increment();
        emit WithdrawMoney(msg.sender, withDrawType, amount, nonce, sign);
    }

    function currentBalance() private view returns (uint256) {
        return IERC20(_moneyCoreAddress).balanceOf(getTokensOwner());
    }
}
