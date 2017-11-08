pragma solidity ^0.4.13;

import "zeppelin-solidity/contracts/token/MintableToken.sol";
import "./BirdCoinCrowdsale.sol";

contract BirdCoin is MintableToken {
    string public constant name = "BirdCoin";
    string public constant symbol = "Bird";
    uint8 public constant decimals = 18;
    bool private isFrozen = false;
    mapping (address => uint256) private lockDuration;
    BirdCoinCrowdsale private crowdsale;

    function BirdCoin() MintableToken() {
        crowdsale = BirdCoinCrowdsale(msg.sender);
    }

    // Checks whether it can transfer or otherwise throws.
    modifier canTransfer(address _sender, uint _value) {
        require(lockDuration[_sender] < now);
        require(!isFrozen && crowdsale.isFinalized());
        _;
    }
    // Calls withdraw on BirdCoinCrowdsale contract
    modifier withdraw(address _owner) {
        crowdsale.withdraw(_owner);
        _;
    }

    // Checks modifier and allows transfer if tokens are not locked.
    function transfer(address _to, uint _value) canTransfer(msg.sender, _value) withdraw(msg.sender) returns (bool success) {
        return super.transfer(_to, _value);
    }

    // Checks modifier and allows transfer if tokens are not locked.
    function transferFrom(address _from, address _to, uint _value) canTransfer(_from, _value) withdraw(_from) returns (bool success) {
        return super.transferFrom(_from, _to, _value);
    }

    // This method is used by Crowdsale contract to avoid recursive crowdsale.withdraw() call
    function transferCrowdsale(address _to, uint _value) onlyOwner returns (bool) {
        return super.transfer(_to, _value);
    }

    function balanceOf(address _owner) public constant returns (uint256 balance) {
        return super.balanceOf(_owner).add(crowdsale.calcAdditionalTokens(_owner));
    }

    function lockTill(address addr, uint256 timeTill) onlyOwner {
        lockDuration[addr] = timeTill;
    }

    function freezeForever() onlyOwner {
        isFrozen = true;
    }
}
