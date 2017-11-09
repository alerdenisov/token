pragma solidity 0.4.17;

import './BasicCoin.sol';
import './Project.sol';

contract IdeaSubCoin is IdeaBasicCoin {

    string public name;
    string public symbol;
    uint8 public constant decimals = 0;
    uint public limit;
    uint public price;
    address public project;
    address public engine;
    mapping(address => string) public shipping;

    modifier onlyProject() {
        require(msg.sender == project);
        _;
    }

    modifier onlyEngine() {
        require(msg.sender == engine);
        _;
    }

    function IdeaSubCoin(
        address _owner,
        string _name,
        string _symbol,
        uint _price,
        uint _limit,
        address _engine
    ) {
        require(_price != 0);

        owner = _owner;
        name = _name;
        symbol = _symbol;
        price = _price;
        limit = _limit;
        project = msg.sender;
        engine = _engine;
    }

    function transfer(address _to, uint _value) public returns (bool success) {
        require(!IdeaProject(project).isCashBack(msg.sender));
        require(!IdeaProject(project).isCashBack(_to));

        IdeaProject(project).updateVotesOnTransfer(msg.sender, _to);

        bool result = super.transfer(_to, _value);

        if (!result) {
            revert();
        }

        return result;
    }

    function transferFrom(address _from, address _to, uint _value) public returns (bool success) {
        require(!IdeaProject(project).isCashBack(_from));
        require(!IdeaProject(project).isCashBack(_to));

        IdeaProject(project).updateVotesOnTransfer(_from, _to);

        bool result = super.transferFrom(_from, _to, _value);

        if (!result) {
            revert();
        }

        return result;
    }

    function buy(address _account, uint _amount) public onlyEngine {
        uint total = totalSupply.add(_amount);

        if (limit != 0) {
            require(total <= limit);
        }

        totalSupply = totalSupply.add(_amount);
        balances[_account] = balances[_account].add(_amount);
        tryCreateAccount(_account);
    }

    function setShipping(string _shipping) public {
        require(bytes(_shipping).length > 0);
    
        shipping[msg.sender] = _shipping;
    }

}