// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";

interface TokenRecipient { 
    function receiveApproval(address _from, uint256 _value, address _token, bytes memory _extraData) external; 
}

interface PaymentInterface {
    function createCastle(address _trainer, uint _tokens, string memory _name, uint64 _a1, uint64 _a2, uint64 _a3, uint64 _s1, uint64 _s2, uint64 _s3) external returns(uint);
    function catchMonster(address _trainer, uint _tokens, uint32 _classId, string memory _name) external returns(uint);
    function payService(address _trainer, uint _tokens, uint32 _type, string memory _text, uint64 _param1, uint64 _param2, uint64 _param3, uint64 _param4, uint64 _param5, uint64 _param6) external returns(uint);
}

contract EtheremonToken is Ownable, AccessControl, ERC20Pausable {
    // metadata
    string public version = "1.0";
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    
    // deposit address
    address public inGameRewardAddress;
    address public userGrowPoolAddress;
    address public developerAddress;
    
    // Ethermon payment
    address public paymentContract;
    
    // for future feature
    uint256 public sellPrice;
    uint256 public buyPrice;
    bool public trading = false;
    mapping (address => bool) public frozenAccount;
    event FrozenFunds(address target, bool frozen);
    
    modifier isTrading {
        require(trading == true || msg.sender == owner());
        _;
    }
    
    modifier requirePaymentContract {
        require(paymentContract != address(0));
        _;        
    }
    
    fallback () payable external {}
    receive () payable external {}

    // constructor    
    constructor(address _inGameRewardAddress, address _userGrowPoolAddress, address _developerAddress, address _paymentContract) ERC20("EtheremonToken", "EMONT") Ownable() Pausable() {
        _setupDecimals(8);
        require(_inGameRewardAddress != address(0));
        require(_userGrowPoolAddress != address(0));
        require(_developerAddress != address(0));
        inGameRewardAddress = _inGameRewardAddress;
        userGrowPoolAddress = _userGrowPoolAddress;
        developerAddress = _developerAddress;

        _mint(inGameRewardAddress, 14000000 * 10**decimals());
        _mint(userGrowPoolAddress, 5000000 * 10**decimals());
        _mint(developerAddress, 1000000 * 10**decimals());

        paymentContract = _paymentContract;
    }
    
    function AddModerator(address _newModerator) onlyOwner public {
        _setupRole(MODERATOR_ROLE, _newModerator);
    }
    
    function RemoveModerator(address _oldModerator) onlyOwner public {
        revokeRole(MODERATOR_ROLE, _oldModerator);
    }

    function UpdateMaintaining(bool _isMaintaining) onlyOwner public {
        if (_isMaintaining) _pause();
        else _unpause();
    }


    function approveAndCall(address _spender, uint256 _value, bytes memory _extraData) public returns (bool success) {
        TokenRecipient spender = TokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, address(this), _extraData);
            return true;
        }
    }

    // moderators
    function setAddress(address _inGameRewardAddress, address _userGrowPoolAddress, address _developerAddress, address _paymentContract) external {
        require(hasRole(MODERATOR_ROLE, msg.sender), "Caller is not a moderator");
        inGameRewardAddress = _inGameRewardAddress;
        userGrowPoolAddress = _userGrowPoolAddress;
        developerAddress = _developerAddress;
        paymentContract = _paymentContract;
    }
    
    // public
    function withdrawEther(address payable _sendTo, uint _amount) external {
        require(hasRole(MODERATOR_ROLE, msg.sender), "Caller is not a moderator");
        if (_amount > address(this).balance) {
            revert();
        }
        (bool sent, ) = _sendTo.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }
    
    function _transfer(address _from, address _to, uint _value) override internal {
        require(!frozenAccount[_from]);
        require(!frozenAccount[_to]);
        super._transfer(_from, _to, _value);
    }
    
    function freezeAccount(address _target, bool _freeze) onlyOwner public {
        frozenAccount[_target] = _freeze;
        FrozenFunds(_target, _freeze);
    }
    
    function buy() payable isTrading public {
        uint amount = msg.value / buyPrice;
        _transfer(address(this), msg.sender, amount);
    }

    function sell(uint256 amount) isTrading public {
        require(address(this).balance >= amount * sellPrice);
        _transfer(msg.sender, address(this), amount);
        msg.sender.transfer(amount * sellPrice);
    }
    
    // Ethermon 
    function createCastle(uint _tokens, string memory _name, uint64 _a1, uint64 _a2, uint64 _a3, uint64 _s1, uint64 _s2, uint64 _s3) whenNotPaused requirePaymentContract external {
        if (_tokens > balanceOf(msg.sender))
            revert();
        PaymentInterface payment = PaymentInterface(paymentContract);
        uint deductedTokens = payment.createCastle(msg.sender, _tokens, _name, _a1, _a2, _a3, _s1, _s2, _s3);
        if (deductedTokens == 0 || deductedTokens > _tokens)
            revert();
        _transfer(msg.sender, inGameRewardAddress, deductedTokens);
    }
    
    function catchMonster(uint _tokens, uint32 _classId, string memory _name) whenNotPaused requirePaymentContract external {
        if (_tokens > balanceOf(msg.sender))
            revert();
        PaymentInterface payment = PaymentInterface(paymentContract);
        uint deductedTokens = payment.catchMonster(msg.sender, _tokens, _classId, _name);
        if (deductedTokens == 0 || deductedTokens > _tokens)
            revert();
        _transfer(msg.sender, inGameRewardAddress, deductedTokens);
    }
    
    function payService(uint _tokens, uint32 _type, string memory _text, uint64 _param1, uint64 _param2, uint64 _param3, uint64 _param4, uint64 _param5, uint64 _param6) whenNotPaused requirePaymentContract external {
        if (_tokens > balanceOf(msg.sender))
            revert();
        PaymentInterface payment = PaymentInterface(paymentContract);
        uint deductedTokens = payment.payService(msg.sender, _tokens, _type, _text, _param1, _param2, _param3, _param4, _param5, _param6);
        if (deductedTokens == 0 || deductedTokens > _tokens)
            revert();
        _transfer(msg.sender, inGameRewardAddress, deductedTokens);
    }
}