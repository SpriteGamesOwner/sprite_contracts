// SPDX-License-Identifier: MIT
pragma solidity = 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "../control/Utils.sol";

contract MoneyCore is Base, ERC20, ERC20Burnable, IMoneyCore  {    
    bytes32 private constant CONTROL_ROLE = keccak256("CONTROL_ROLE");
    
    constructor(uint256 init_amount) ERC20("Skg", "SKG") {
        _mint(address(owner()), init_amount * 10 ** decimals());
    }

    function setController(address controller) external onlyOwner isContract(controller) {
        grantRole(CONTROL_ROLE, controller);
    }

    function moveOwner(address to) external onlyOwner isExternal(to) {
        transferOwnership(to);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) external onlyRole(CONTROL_ROLE) {
        _mint(to, amount);
    }
    
    function withDraw(address to, uint256 amount) external onlyRole(CONTROL_ROLE) {
        _transfer(address(owner()), to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}
