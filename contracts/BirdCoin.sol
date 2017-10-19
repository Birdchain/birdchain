pragma solidity ^0.4.13;

import "zeppelin-solidity/contracts/token/MintableToken.sol";

contract BirdCoin is MintableToken {
    string public constant name = "BirdCoin";
    string public constant symbol = "Bird";
    uint8 public constant decimals = 18;
    uint256 public lockedTill = 0;

    // Checks whether it can transfer or otherwise throws.
    modifier canTransfer(address _sender, uint _value) {
        require(lockedTill < now);
        _;
    }

    // Checks modifier and allows transfer if tokens are not locked.
    function transfer(address _to, uint _value) canTransfer(msg.sender, _value) returns (bool success) {
        return super.transfer(_to, _value);
    }

    // Checks modifier and allows transfer if tokens are not locked.
    function transferFrom(address _from, address _to, uint _value) canTransfer(_from, _value) returns (bool success) {
        return super.transferFrom(_from, _to, _value);
    }

    // Set the level which will be required for transferring tokens
    function lockTill(uint256 timeTill) {
        lockedTill = timeTill;
    }
}
