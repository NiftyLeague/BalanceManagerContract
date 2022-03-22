// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract BalanceManager is Initializable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  event NFTLDeposited(address indexed by, uint256 amount);

  address public nftl;

  function initialize(address _nftl) public initializer {
    nftl = _nftl;
  }

  function deposit(uint256 _amount) external {
    IERC20Upgradeable(nftl).safeTransferFrom(msg.sender, address(this), _amount);

    emit NFTLDeposited(msg.sender, _amount);
  }
}
