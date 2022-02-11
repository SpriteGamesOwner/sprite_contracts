// SPDX-License-Identifier: MIT
pragma solidity = 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./Utils.sol";
import "./FairyCtrl.sol";

contract Breeding is Base {
    using SafeERC20 for IERC20;
    using Address for address;

    mapping (uint256 => uint256[2]) private breedingPriceTable;

    address private _signServerAddress = 0x2E3Eeb98a73909c5D07EA51DF72bFd1a263CC693;

    address private _fairyCtrlAddress;

    address private _spriteCoreAddress;

    address private _moneyCoreAddress;

    constructor(address fairyCtrlAddress, address spriteCoreAddress, address moneyCoreAddress) isContract(fairyCtrlAddress) isContract(spriteCoreAddress) isContract(moneyCoreAddress) {
        _fairyCtrlAddress = fairyCtrlAddress;
        _spriteCoreAddress = spriteCoreAddress;
        _moneyCoreAddress = moneyCoreAddress;

        breedingPriceTable[0] = [750 * 10 ** 18, 1 * 10 ** 18];
        breedingPriceTable[1] = [1250 * 10 ** 18, 2 * 10 ** 18];
        breedingPriceTable[2] = [2000 * 10 ** 18, 4 * 10 ** 18];
        breedingPriceTable[3] = [3250 * 10 ** 18, 8 * 10 ** 18];
        breedingPriceTable[4] = [5000 * 10 ** 18, 12 * 10 ** 18];
        breedingPriceTable[5] = [8000 * 10 ** 18, 16 * 10 ** 18];
        breedingPriceTable[6] = [13000 * 10 ** 18, 20 * 10 ** 18];
    }

    function moveOwner(address to) external onlyOwner isExternal(to) {
        transferOwnership(to);
    }

    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() public onlyOwner whenPaused {
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

    function setFairyCtrlAddress(address account) external onlyOwner isContract(account) {
        _fairyCtrlAddress = account;
    }

    function setBreedingPrice(uint256 breedingCount, uint256[2] memory prices) external onlyOwner {
        breedingPriceTable[breedingCount] = prices;
    }

    function breed(uint256 fatherId, uint256 motherId, uint256 timestamp, bytes memory sign) external {
        if (!IFairyCtrl(_fairyCtrlAddress).isOwns(msg.sender, fatherId)) {
            revert("Breed fairy failed, reason: invalid father id");
        }

        if (!IFairyCtrl(_fairyCtrlAddress).isOwns(msg.sender, motherId)) {
            revert("Breed fairy failed, reason: invalid mother id");
        }

        bytes memory message = abi.encodePacked(Utils.addressToUint256(msg.sender), fatherId, motherId, timestamp);
        if (!Utils.validSign(_signServerAddress, message, sign)) {
            revert("Breed fairy failed, reason: invalid signature");
        }

        uint256 fatherBreedingCount = IFairyCtrl(_fairyCtrlAddress).currentBreedingCount(fatherId);
        if (fatherBreedingCount > 6) {
            revert("Breed fairy failed, reason: out of breeding");
        }

        uint256 motherBreedingCount = IFairyCtrl(_fairyCtrlAddress).currentBreedingCount(motherId);
        if (motherBreedingCount > 6) {
            revert("Breed fairy failed, reason: out of breeding");
        }

        uint256 fatherMoneyAmount = breedingPriceTable[fatherBreedingCount][0];
        uint256 fatherSpriteAmount = breedingPriceTable[fatherBreedingCount][1];
        uint256 motherMoneyAmount = breedingPriceTable[motherBreedingCount][0];
        uint256 motherSpriteAmount = breedingPriceTable[motherBreedingCount][1];
        IERC20(_moneyCoreAddress).safeTransferFrom(msg.sender, address(owner()), fatherMoneyAmount + motherMoneyAmount);
        IERC20(_spriteCoreAddress).safeTransferFrom(msg.sender, address(owner()), fatherSpriteAmount + motherSpriteAmount);

        IFairyCtrl(_fairyCtrlAddress).breedFairy(msg.sender, fatherId, motherId, 0);
    }

}
