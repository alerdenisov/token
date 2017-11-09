pragma solidity 0.4.17;

import './BasicCoin.sol';
import './ProjectAgent.sol';

contract IdeaCoin is IdeaBasicCoin {

    uint public earnedEthWei;
    uint public soldIdeaWei;
    uint public soldIdeaWeiPreIco;
    uint public soldIdeaWeiIco;
    uint public soldIdeaWeiPostIco;
    uint public icoStartTimestamp;
    mapping(address => uint) public pieBalances;
    address[] public pieAccounts;
    mapping(address => bool) internal pieAccountsMap;
    uint public nextRoundReserve;
    address[] public projects;
    address public projectAgent;
    address public bank1;
    address public bank2;
    uint public bank1Val;
    uint public bank2Val;
    uint public bankValReserve;

    enum IcoStates {
        Coming,
        PreIco,
        Ico,
        PostIco,
        Done
    }

    IcoStates public icoState;

    function IdeaCoin() {
        name = 'IdeaCoin';
        symbol = 'IDEA';
        decimals = 18;
        totalSupply = 100000000 ether;

        owner = msg.sender;
        tryCreateAccount(msg.sender);
    }

    function() payable {
        uint tokens;
        bool moreThenPreIcoMin = msg.value >= 20 ether;
        uint totalVal = msg.value + bankValReserve;
        uint halfVal = totalVal / 2;

        if (icoState == IcoStates.PreIco && moreThenPreIcoMin && soldIdeaWeiPreIco <= 2500000 ether) {

            tokens = msg.value * 1500;
            balances[msg.sender] += tokens;
            soldIdeaWeiPreIco += tokens;

        } else if (icoState == IcoStates.Ico && soldIdeaWeiIco <= 35000000 ether) {
            uint elapsed = now - icoStartTimestamp;

            if (elapsed <= 1 days) {

                tokens = msg.value * 1250;
                balances[msg.sender] += tokens;

            } else if (elapsed <= 6 days && elapsed > 1 days) {

                tokens = msg.value * 1150;                          
                balances[msg.sender] += tokens;

            } else if (elapsed <= 11 days && elapsed > 6 days) {

                tokens = msg.value * 1100;
                balances[msg.sender] += tokens;

            } else if (elapsed <= 16 days && elapsed > 11 days) {

                tokens = msg.value * 1050;
                balances[msg.sender] += tokens;

            } else {

                tokens = msg.value * 1000;
                balances[msg.sender] += tokens;

            }

            soldIdeaWeiIco += tokens;

        } else if (icoState == IcoStates.PostIco && soldIdeaWeiPostIco <= 12000000 ether) {

            tokens = msg.value * 500;
            balances[msg.sender] += tokens;
            soldIdeaWeiPostIco += tokens;

        } else {
            revert();
        }

        earnedEthWei += msg.value;
        soldIdeaWei += tokens;

        bank1Val += halfVal;
        bank2Val += halfVal;
        bankValReserve = totalVal - (halfVal * 2);

        tryCreateAccount(msg.sender);
    }

    function setBank(address _bank1, address _bank2) public onlyOwner {
        require(bank1 == address(0x0));
        require(bank2 == address(0x0));
        require(_bank1 != address(0x0));
        require(_bank2 != address(0x0));

        bank1 = _bank1;
        bank2 = _bank2;

        balances[bank1] = 500000 ether;
        balances[bank2] = 500000 ether;
    }

    function startPreIco() public onlyOwner {
        icoState = IcoStates.PreIco;
    }

    function stopPreIcoAndBurn() public onlyOwner {
        stopAnyIcoAndBurn(
            (2500000 ether - soldIdeaWeiPreIco) * 2
        );
        balances[bank1] += soldIdeaWeiPreIco / 2;
        balances[bank2] += soldIdeaWeiPreIco / 2;
    }

    function startIco() public onlyOwner {
        icoState = IcoStates.Ico;
        icoStartTimestamp = now;
    }

    function stopIcoAndBurn() public onlyOwner {
        stopAnyIcoAndBurn(
            (35000000 ether - soldIdeaWeiIco) * 2
        );
        balances[bank1] += soldIdeaWeiIco / 2;
        balances[bank2] += soldIdeaWeiIco / 2;
    }

    function startPostIco() public onlyOwner {
        icoState = IcoStates.PostIco;
    }

    function stopPostIcoAndBurn() public onlyOwner {
        stopAnyIcoAndBurn(
            (12000000 ether - soldIdeaWeiPostIco) * 2
        );
        balances[bank1] += soldIdeaWeiPostIco / 2;
        balances[bank2] += soldIdeaWeiPostIco / 2;
    }

    function stopAnyIcoAndBurn(uint _burn) internal {
        icoState = IcoStates.Coming;
        totalSupply = totalSupply.sub(_burn);
    }

    function withdrawEther() public {
        require(msg.sender == bank1 || msg.sender == bank2);

        if (msg.sender == bank1) {
            bank1.transfer(bank1Val);
            bank1Val = 0;
        }

        if (msg.sender == bank2) {
            bank2.transfer(bank2Val);
            bank2Val = 0;
        }

        if (bank1Val == 0 && bank2Val == 0 && this.balance != 0) {
            owner.transfer(this.balance);
        }
    }

    function pieBalanceOf(address _owner) constant public returns (uint balance) {
        return pieBalances[_owner];
    }

    function transferToPie(uint _amount) public returns (bool success) {
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        pieBalances[msg.sender] = pieBalances[msg.sender].add(_amount);
        tryCreatePieAccount(msg.sender);

        return true;
    }

    function transferFromPie(uint _amount) public returns (bool success) {
        pieBalances[msg.sender] = pieBalances[msg.sender].sub(_amount);
        balances[msg.sender] = balances[msg.sender].add(_amount);

        return true;
    }

    function receiveDividends(uint _amount) internal {
        uint minBalance = 10000 ether;
        uint pieSize = calcPieSize(minBalance);
        uint amount = nextRoundReserve + _amount;

        accrueDividends(minBalance, pieSize, amount);
    }

    function calcPieSize(uint _minBalance) constant internal returns (uint _pieSize) {
        for (uint i = 0; i < pieAccounts.length; i += 1) {
            var balance = pieBalances[pieAccounts[i]];

            if (balance >= _minBalance) {
                _pieSize = _pieSize.add(balance);
            }
        }
    }

    function accrueDividends(uint _minBalance, uint _pieSize, uint _amount) internal {
        uint accrued;

        for (uint i = 0; i < pieAccounts.length; i += 1) {
            address account = pieAccounts[i];
            uint balance = pieBalances[account];

            if (balance >= _minBalance) {
                uint dividends = (balance * _amount) / _pieSize;

                accrued = accrued.add(dividends);
                pieBalances[account] = balance.add(dividends);
            }
        }

        nextRoundReserve = _amount.sub(accrued);
    }

    function tryCreatePieAccount(address _account) internal {
        if (!pieAccountsMap[_account]) {
            pieAccounts.push(_account);
            pieAccountsMap[_account] = true;
        }
    }

    function setProjectAgent(address _project) public onlyOwner {
        projectAgent = _project;
    }

    function makeProject(string _name, uint _required, uint _requiredDays) public returns (address _address) {
        _address = ProjectAgent(projectAgent).makeProject(msg.sender, _name, _required, _requiredDays);

        projects.push(_address);
    }

    function withdrawFromProject(address _project, uint _stage) public returns (bool _success) {
        uint _value;
        (_success, _value) = ProjectAgent(projectAgent).withdrawFromProject(msg.sender, _project, _stage);

        if (_success) {
            receiveTrancheAndDividends(_value);
        }
    }

    function cashBackFromProject(address _project) public returns (bool _success) {
        uint _value;
        (_success, _value) = ProjectAgent(projectAgent).cashBackFromProject(msg.sender, _project);

        if (_success) {
            balances[msg.sender] = balances[msg.sender].add(_value);
        }
    }

    function receiveTrancheAndDividends(uint _sum) internal {
        uint raw = _sum * 965;
        uint reserve = raw % 1000;
        uint tranche = (raw - reserve) / 1000;

        balances[msg.sender] = balances[msg.sender].add(tranche);
        receiveDividends(_sum - tranche);
    }

    function buyProduct(address _product, uint _amount) public {
        ProjectAgent _agent = ProjectAgent(projectAgent);

        uint _price = IdeaSubCoin(_product).price();
    
        balances[msg.sender] = balances[msg.sender].sub(_price * _amount);
        _agent.buyProduct(_product, msg.sender, _amount);
    }
}