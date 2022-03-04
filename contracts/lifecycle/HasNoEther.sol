// SPDX-License-Identifier: MIT
pragma solidity = 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Contracts that should not own Ether
 * @author Remco Bloemen <remco@2π.com>
 * @dev This tries to block incoming ether to prevent accidental loss of Ether. Should Ether end up
 * in the contract, it will allow the owner to reclaim this ether.
 * @notice Ether can still be send to this contract by:
 * calling functions labeled `payable`
 * `selfdestruct(contract_address)`
 * mining directly to the contract address
*/
contract HasNoEther is Ownable {

  /**
   * @dev Transfer all Ether held by the contract to the owner.
   */
  function reclaimEther(address ) external onlyOwner {
     address _owner  = owner();
     payable(_owner).transfer(address(this).balance);
  }
  
  function reclaimToken(address tokenAddress) external onlyOwner {
     require(tokenAddress != address(0),'tokenAddress can not a Zero address');
     IERC20 token = IERC20(tokenAddress);
     address _owner  = owner();
     token.transfer(_owner,token.balanceOf(address(this)));
  }
}