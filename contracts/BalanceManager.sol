// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

contract BalanceManager is Initializable, OwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using ECDSAUpgradeable for bytes32;

  event NFTLDeposited(address indexed by, uint256 amount);
  event MaintainerUpdated(address indexed by, address indexed oldMaintainer, address indexed newMaintainer);
  event NFTLWithdrew(address indexed by, address indexed beneficiary, uint256 amount);
  event NFTLWithdrewByDAO(address indexed by, address indexed beneficiary, uint256 amount);

  /// @dev NFTL token address
  address public nftl;

  /// @dev User -> Total deposit amount
  mapping(address => uint256) private userDeposits;

  /// @dev User -> Total withdrawal amount
  mapping(address => uint256) private userWithdrawals;

  /// @dev User -> Nonce
  mapping(address => uint256) public nonce;

  /// @dev Signature -> Bool
  mapping(bytes => bool) public signatures;

  /// @dev Maintainer address
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

  /**
   * @notice Deposit NFTL tokens into the contract
   * @param _amount Deposit amount
   */
  function deposit(uint256 _amount) external {
    IERC20Upgradeable(nftl).safeTransferFrom(msg.sender, address(this), _amount);
    userDeposits[msg.sender] += _amount;

    emit NFTLDeposited(msg.sender, _amount);
  }

  /**
   * @notice Withdraw NFTL tokens from the contract
   * @dev Only maintainer
   * @param _beneficiary Beneficiary address
   * @param _amount NFTL token amount to withdraw
   * @param _nonce Nonce
   * @param _signature Signature
   */
  function withdraw(
    address _beneficiary,
    uint256 _amount,
    uint256 _nonce,
    bytes memory _signature
  ) external onlyMaintainer {
    // check if the nonce is matched
    require(nonce[_beneficiary] == _nonce, "mismatched nonce");
    nonce[_beneficiary] += 1;

    // check if the signature was already used
    require(!signatures[_signature], "used signature");
    signatures[_signature] = true;

    // check the signer
    bytes32 data = keccak256(abi.encodePacked(_beneficiary, _amount, _nonce));
    require(data.toEthSignedMessageHash().recover(_signature) == maintainer, "wrong signer");

    // check if total withdrawal amount is not greater than total deposit one
    userWithdrawals[_beneficiary] += _amount;
    require(userWithdrawals[_beneficiary] <= userDeposits[_beneficiary], "withdrawal amount exceeded");

    // transfer tokens to the user
    IERC20Upgradeable(nftl).safeTransfer(_beneficiary, _amount);

    emit NFTLWithdrew(maintainer, _beneficiary, _amount);
  }

  /**
   * @notice Update maintianer address
   * @dev Only owner
   * @param _maintainer New maintainer address
   */
  function updateMaintainer(address _maintainer) external onlyOwner {
    emit MaintainerUpdated(msg.sender, maintainer, _maintainer);

    maintainer = _maintainer;
  }

  /**
   * @notice Allow DAO to withdraw NFTL token from the contract
   * @dev Only owner
   * @param _beneficiary Beneficiary address
   * @param _amount NFTL token amount to withdraw
   */
  function withdrawByDAO(address _beneficiary, uint256 _amount) external onlyOwner {
    IERC20Upgradeable(nftl).safeTransfer(_beneficiary, _amount);

    emit NFTLWithdrewByDAO(msg.sender, _beneficiary, _amount);
  }
}
