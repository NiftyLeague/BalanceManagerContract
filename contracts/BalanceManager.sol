// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

contract BalanceManager is Initializable, OwnableUpgradeable {
  using ECDSAUpgradeable for bytes32;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  event NFTLDeposited(address indexed by, uint256 amount);
  event MaintainerUpdated(address indexed by, address indexed oldMaintainer, address indexed newMaintainer);

  address public nftl;
  mapping(address => uint256) private userDeposits;
  address public maintainer;

  modifier onlyMaintainer() {
    require(msg.sender == maintainer, "only maintainer");
    _;
  }

  function initialize(address _nftl, address _maintainer) public initializer {
    __Ownable_init();

    nftl = _nftl;
    maintainer = _maintainer;
  }

  function deposit(uint256 _amount) external {
    IERC20Upgradeable(nftl).safeTransferFrom(msg.sender, address(this), _amount);
    userDeposits[msg.sender] += _amount;

    emit NFTLDeposited(msg.sender, _amount);
  }

  function withdraw(uint256 _amount) external onlyMaintainer {}

  function updateMaintainer(address _maintainer) external onlyOwner {
    emit MaintainerUpdated(msg.sender, maintainer, _maintainer);

    maintainer = _maintainer;
  }
}
