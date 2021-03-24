pragma solidity ^0.7.0;

contract EtheremonBattle {
    constructor() public {}
    function isOnBattle(uint64 ) pure external returns(bool) {
        return true;
    }
}

contract EtheremonTradeInterface {
    constructor() public {}
    function isOnTrading(uint64 ) pure external returns(bool){
        return true;
    }
}
