// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface OldToken {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external;
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
}

contract TokenConvertor is Ownable, AccessControl {

    using SafeMath for uint256;

    // metadata
    string public version = "1.0";
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    
    // deposit address
    address public newTokenAddress;
    address public oldTokenAddress;
        

    bool public downgradable = true;
    bool public upgradable = true;
    uint256 ratio = 20;
        
    modifier onlyModerators {
        require(hasRole(MODERATOR_ROLE, msg.sender), "Caller is not a moderator");
        _;
    }

    modifier isUpgradable {
        require(upgradable == true, "Upgradable disallowed");
        _;
    }

    modifier isDowngradable {
        require(downgradable == true, "Downgradable disallowed");
        _;
    }
    
    fallback () payable external {}
    receive () payable external {}

    // constructor    
    constructor() {
        _setupRole(MODERATOR_ROLE, msg.sender);
    }
    
    function AddModerator(address _newModerator) onlyOwner public {
        _setupRole(MODERATOR_ROLE, _newModerator);
    }
    
    function RemoveModerator(address _oldModerator) onlyOwner public {
        revokeRole(MODERATOR_ROLE, _oldModerator);
    }

    // moderators
    function setAddress(address _oldTokenAddress, address _newTokenAddress) onlyModerators external {
        oldTokenAddress = _oldTokenAddress;
        newTokenAddress = _newTokenAddress;
    }

    function convertToOld(uint256 _amount, address _ownerAdd) public isDowngradable {
        require(msg.sender == newTokenAddress, "Must be called from New Token Contract");
        OldToken oldToken = OldToken(oldTokenAddress);
        oldToken.transfer(_ownerAdd, _amount.div(ratio));
    }

    function receiveApproval(address _ownerAdd, uint256 _value, address _token, bytes memory _extraData) public isUpgradable {
        require(msg.sender == oldTokenAddress, "Must be called from Old Token Contract");
        OldToken oldToken = OldToken(_token);
        oldToken.transferFrom(_ownerAdd, address(this), _value);

        IERC20 newToken = IERC20(newTokenAddress);
        newToken.transfer(_ownerAdd, _value.mul(ratio));
    }

    function setDowngradable(bool _downgradable) onlyModerators public {
        downgradable = _downgradable;
    }

    function setUpgradable(bool _upgradable) onlyModerators public {
        upgradable = _upgradable;
    }

    function updateRatio(uint256 _ratio) onlyModerators public {
        ratio = _ratio;
    }
}