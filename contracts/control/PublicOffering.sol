// SPDX-License-Identifier: MIT
pragma solidity = 0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";

import "./Utils.sol";

contract PublicOffering is Base {
    event PublicOfferingTransfer(address indexed from, address indexed to, uint256 amount);

    uint256 totalOfferingAmount = 0;

    constructor() {
        
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

    function getTotalOfferingAmount() external view returns (uint256) {
        return totalOfferingAmount;
    }

    function offer() payable external isExternal(msg.sender) {
        if (msg.value == 0) {
            revert("Offer failed, reason: invalid offering amount");
        }
        
        payable(address(owner())).transfer(msg.value);
        totalOfferingAmount += msg.value;
        emit PublicOfferingTransfer(msg.sender, address(owner()), msg.value);
    }
}