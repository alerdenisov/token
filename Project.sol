pragma solidity 0.4.17;

import './SubCoin.sol';
import './Uint.sol';

contract IdeaProject {
    using IdeaUint for uint;

    string public name;
    address public engine;
    address public owner;
    uint public required;
    uint public requiredDays;
    uint public fundingEndTime;
    uint public earned;
    mapping(address => bool) public isCashBack;
    uint public currentWorkStagePercent;
    uint internal lastWorkStageStartTimestamp;
    int8 public failStage = -1;
    uint public failInvestPercents;
    address[] public products;
    uint public cashBackVotes;
    mapping(address => uint) public cashBackWeight;

    enum States {
        Initial,
        Coming,
        Funding,
        Workflow,
        SuccessDone,
        FundingFail,
        WorkFail
    }

    States public state = States.Initial;

    struct WorkStage {
        uint percent;
        uint stageDays;
        uint sum;
        uint withdrawTime;
    }

    WorkStage[] public workStages;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyEngine() {
        require(msg.sender == engine);
        _;
    }

    modifier onlyState(States _state) {
        require(state == _state);
        _;
    }

    modifier onlyProduct() {
        bool permissionGranted;

        for (uint8 i; i < products.length; i += 1) {
            if (msg.sender == products[i]) {
                permissionGranted = true;
            }
        }

        if (permissionGranted) {
            _;
        } else {
            revert();
        }
    }

    function IdeaProject(
        address _owner,
        string _name,
        uint _required,
        uint _requiredDays
    ) {
        require(bytes(_name).length > 0);
        require(_required != 0);

        require(_requiredDays >= 10);
        require(_requiredDays <= 100);

        engine = msg.sender;
        owner = _owner;
        name = _name;
        required = _required;
        requiredDays = _requiredDays;
    }

    function addEarned(uint _earned) public onlyEngine {
        earned = earned.add(_earned);
    }

    function isFundingState() constant public returns (bool _result) {
        return state == States.Funding;
    }

    function isWorkflowState() constant public returns (bool _result) {
        return state == States.Workflow;
    }

    function isSuccessDoneState() constant public returns (bool _result) {
        return state == States.SuccessDone;
    }

    function isFundingFailState() constant public returns (bool _result) {
        return state == States.FundingFail;
    }

    function isWorkFailState() constant public returns (bool _result) {
        return state == States.WorkFail;
    }

    function markAsComingAndFreeze() public onlyState(States.Initial) onlyOwner {
        require(products.length > 0);
        require(currentWorkStagePercent == 100);

        state = States.Coming;
    }

    function startFunding() public onlyState(States.Coming) onlyOwner {
        state = States.Funding;

        fundingEndTime = uint64(now + requiredDays * 1 days);
        calcLastWorkStageStart();
        calcWithdrawTime();
    }

    function projectWorkStarted() public onlyState(States.Funding) onlyEngine {
        startWorkflow();
    }

    function startWorkflow() internal {
        uint used;
        uint current;
        uint len = workStages.length;

        state = States.Workflow;

        for (uint8 i; i < len; i += 1) {
            current = earned.mul(workStages[i].percent).div(100);
            workStages[i].sum = current;
            used = used.add(current);
        }

        workStages[len - 1].sum = workStages[len - 1].sum.add(earned.sub(used));
    }

    function projectDone() public onlyState(States.Workflow) onlyOwner {
        require(now > lastWorkStageStartTimestamp);

        state = States.SuccessDone;
    }

    function projectFundingFail() public onlyState(States.Funding) onlyEngine {
        state = States.FundingFail;
    }

    function projectWorkFail() internal {
        state = States.WorkFail;

        for (uint8 i = 1; i < workStages.length; i += 1) {
            failInvestPercents += workStages[i - 1].percent;

            if (workStages[i].withdrawTime > now) {
                failStage = int8(i - 1);

                i = uint8(workStages.length);
            }
        }
        
        if (failStage == -1) {
            failStage = int8(workStages.length - 1);
            failInvestPercents = 100;
        }
    }

    function makeWorkStage(
        uint _percent,
        uint _stageDays
    ) public onlyState(States.Initial) {
        require(workStages.length <= 10);
        require(_stageDays >= 10);
        require(_stageDays <= 100);

        if (currentWorkStagePercent.add(_percent) > 100) {
            revert();
        } else {
            currentWorkStagePercent = currentWorkStagePercent.add(_percent);
        }

        workStages.push(WorkStage(
            _percent,
            _stageDays,
            0,
            0
        ));
    }

    function calcLastWorkStageStart() internal {
        lastWorkStageStartTimestamp = fundingEndTime;

        for (uint8 i; i < workStages.length - 1; i += 1) {
            lastWorkStageStartTimestamp += workStages[i].stageDays * 1 days;
        }
    }

    function calcWithdrawTime() internal {
        for (uint8 i; i < workStages.length; i += 1) {
            if (i == 0) {
                workStages[i].withdrawTime = now + requiredDays * 1 days;
            } else {
                workStages[i].withdrawTime = workStages[i - 1].withdrawTime + workStages[i - 1].stageDays * 1 days;
            }
        }
    }

    function withdraw(uint _stage) public onlyEngine returns (uint _sum) {
        WorkStage memory stageStruct = workStages[_stage];

        if (stageStruct.withdrawTime <= now) {
            _sum = stageStruct.sum;

            workStages[_stage].sum = 0;
        }
    }

    function voteForCashBack() public {
        voteForCashBackInPercentOfWeight(100);
    }

    function cancelVoteForCashBack() public {
        voteForCashBackInPercentOfWeight(0);
    }

    function voteForCashBackInPercentOfWeight(uint _percent) public {
        voteForCashBackInPercentOfWeightForAccount(msg.sender, _percent);
    }

    function voteForCashBackInPercentOfWeightForAccount(address _account, uint _percent) internal {
        require(_percent <= 100);

        updateFundingStateIfNeed();

        if (state == States.Workflow) {
            uint currentWeight = cashBackWeight[_account];
            uint supply;
            uint part;

            for (uint8 i; i < products.length; i += 1) {
                supply += IdeaSubCoin(products[i]).totalSupply();
                part += IdeaSubCoin(products[i]).balanceOf(_account);
            }

            cashBackVotes += ((part * (10 ** 10)) / supply) * (_percent - currentWeight);
            cashBackWeight[_account] = _percent;

            if (cashBackVotes > 50 * (10 ** 10)) {
                projectWorkFail();
            }
        }
    }

    function updateVotesOnTransfer(address _from, address _to) public onlyProduct {
        if (isWorkflowState()) {
            voteForCashBackInPercentOfWeightForAccount(_from, 0);
            voteForCashBackInPercentOfWeightForAccount(_to, 0);
        }
    }

    function makeProduct(
        string _name,
        string _symbol,
        uint _price,
        uint _limit
    ) public onlyState(States.Initial) onlyOwner returns (address _productAddress) {
        require(products.length <= 25);

        IdeaSubCoin product = new IdeaSubCoin(msg.sender, _name, _symbol, _price, _limit, engine);

        products.push(address(product));

        return address(product);
    }

    function calcInvesting(address _account) public onlyEngine returns (uint _sum) {
        require(!isCashBack[_account]);

        for (uint8 i = 0; i < products.length; i += 1) {
            IdeaSubCoin product = IdeaSubCoin(products[i]);

            _sum = _sum.add(product.balanceOf(_account) * product.price());
        }

        if (isWorkFailState()) {
            _sum = _sum.mul(100 - failInvestPercents).div(100);
        }

        isCashBack[_account] = true;
    }

    function updateFundingStateIfNeed() internal {
        if (isFundingState() && now > fundingEndTime) {
            if (earned >= required) {
                startWorkflow();
            } else {
                state = States.FundingFail;
            }
        }
    }
}