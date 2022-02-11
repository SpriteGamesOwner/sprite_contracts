// SPDX-License-Identifier: MIT
pragma solidity = 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract HasNoEther is Ownable {
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