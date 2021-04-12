// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";

import { AccessControlMixin } from "./AccessControlMixin.sol";
import { IChildToken } from "./IChildToken.sol";
import { NativeMetaTransaction } from "./NativeMetaTransaction.sol";
import { ContextMixin } from "./ContextMixin.sol";

interface TokenRecipient {
  function receiveApproval(
    address _from,
    uint256 _value,
    address _token,
    bytes memory _extraData
  ) external;
}

interface TokenConvertor {
  function convertToOld(uint256, address) external;
}

contract EthermonTokenMatic is
  ERC20Pausable,
  Ownable,
  IChildToken,
  AccessControlMixin,
  NativeMetaTransaction,
  ContextMixin
{
  using SafeMath for uint256;
  // metadata
  string public version = "1.0";
  bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
  bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

  // Ethermon payment
  address public convertorContract;

  mapping(address => bool) public frozenAccount;
  event FrozenFunds(address target, bool frozen);

  modifier onlyModerators {
    require(hasRole(MODERATOR_ROLE, msg.sender), "Caller is not a moderator");
    _;
  }

  // constructor
  constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    address childChainManager
  ) ERC20(name_, symbol_) Ownable() Pausable() {
    _setupDecimals(decimals_);
    _setupContractId("ChildERC20");
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(DEPOSITOR_ROLE, childChainManager);
    _initializeEIP712(name_);

    _mint(msg.sender, 400000000 * 10**decimals());
  }

  // This is to support Native meta transactions
  // never use msg.sender directly, use _msgSender() instead
  function _msgSender()
    internal
    view
    override
    returns (address payable sender)
  {
    return ContextMixin.msgSender();
  }

  function AddModerator(address _newModerator) public onlyOwner {
    _setupRole(MODERATOR_ROLE, _newModerator);
  }

  function RemoveModerator(address _oldModerator) public onlyOwner {
    revokeRole(MODERATOR_ROLE, _oldModerator);
  }

  function UpdateMaintaining(bool _isMaintaining) public onlyOwner {
    if (_isMaintaining) _pause();
    else _unpause();
  }

  function approveAndCall(
    address _spender,
    uint256 _value,
    bytes memory _extraData
  ) public returns (bool success) {
    TokenRecipient spender = TokenRecipient(_spender);
    if (approve(_spender, _value)) {
      spender.receiveApproval(msg.sender, _value, address(this), _extraData);
      return true;
    }
  }

  function transferAndCall(
    address _convertor,
    uint256 _amount,
    bytes memory _extraData
  ) public returns (bool success) {
    require(_amount != 0);
    TokenConvertor convertor = TokenConvertor(_convertor);
    convertor.convertToOld(_amount, msg.sender);
    _transfer(_msgSender(), _convertor, _amount);
    return true;
  }

  function freezeAccount(address _target, bool _freeze) public onlyOwner {
    frozenAccount[_target] = _freeze;
    FrozenFunds(_target, _freeze);
  }

  /**
   * @notice called when token is deposited on root chain
   * @dev Should be callable only by ChildChainManager
   * Should handle deposit by minting the required amount for user
   * Make sure minting is done only by this function
   * @param user user address for whom deposit is being done
   * @param depositData abi encoded amount
   */
  function deposit(address user, bytes calldata depositData)
    external
    override
    only(DEPOSITOR_ROLE)
  {
    uint256 amount = abi.decode(depositData, (uint256));
    _mint(user, amount);
  }

  /**
   * @notice called when user wants to withdraw tokens back to root chain
   * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
   * @param amount amount of tokens to withdraw
   */
  function withdraw(uint256 amount) external {
    _burn(_msgSender(), amount);
  }
}
