pragma solidity ^0.4.8;

contract Owned {
    address public owner;

    event NewOwner(address indexed _prevOwner, address indexed _newOwner);

    function Owned() {
        owner = msg.sender;
    }

    // allows execution by the owner only
    modifier ownerOnly {
        if (msg.sender != owner)
            throw;
        _;
    }

    /*
        allows transferring the contract ownership
        can only be called by the contract owner
    */
    function setOwner(address _newOwner) public ownerOnly {
        if (owner == _newOwner)
            throw;

        address prevOwner = owner;
        owner = _newOwner;
        NewOwner(prevOwner, owner);
    }
}
