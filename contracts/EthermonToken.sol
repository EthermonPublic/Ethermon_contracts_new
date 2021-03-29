// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";

interface ILocker {
  /**
   * @dev Fails if transaction is not allowed. Otherwise returns the penalty.
   * Returns a bool and a uint16, bool clarifying the penalty applied, and uint16 the penaltyOver1000
   */
  function lockOrGetPenalty(address source, address dest)
    external
    returns (bool, uint256);
}

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

contract EthermonToken is Ownable, AccessControl, ERC20Pausable {
  using SafeMath for uint256;
  // metadata
  string public version = "1.0";
  bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

  // Ethermon payment
  address public convertorContract;
  ILocker public locker;

  mapping(address => bool) public frozenAccount;
  event FrozenFunds(address target, bool frozen);

  modifier onlyModerators {
    require(hasRole(MODERATOR_ROLE, msg.sender), "Caller is not a moderator");
    _;
  }

  // constructor
  constructor() ERC20("EthermonToken", "EMON") Ownable() Pausable() {
    _setupDecimals(18);

    _mint(msg.sender, 400000000 * 10**decimals());
  }

  function setLocker(address _locker) external onlyOwner() {
    locker = ILocker(_locker);
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

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal virtual override {
    if (address(locker) != address(0)) {
      locker.lockOrGetPenalty(sender, recipient);
    }
    return ERC20._transfer(sender, recipient, amount);
  }
}
