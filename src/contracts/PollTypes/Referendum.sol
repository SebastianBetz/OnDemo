// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

import "../AccountManagement.sol";
import "../Poll.sol";
import "../Utils.sol";

contract Referendum {
    // A Referendum contract that uses the polling interface
    // A Referendum can have only two answers, has a deadline and needs to be started by a council member
    // A Referendum extends the polling interface to include role based rights inherited from the accountmanagement contract

    enum CancelReason { 
        DRAW,                   // Referendum has seen equal amount of Ayes and Noes
        NOTENOUGHVOTERTURNOUT,  // Not enough voters participated
        CANCELEDBYCOUNCIL       // Council canceled referendum
    }
    enum State { 
        CREATED,
        APPROVED,    // Council approved referendum
        RUNNING,     // Members can vote
        CLOSED,      // Referendum has been closed, no more voting is possible
        CANCELED     // Council canceled referendum
    }
    enum Result{ 
        NOTAVAILABLE,
        AYES,   // More members voted with Aye
        NOES,   // More members voted with No
        DRAW    // Same amount of members voted with Aye and No respectively
    }

    event StateChanged(
        address indexed _by,
        State oldState,
        State newState,
        string description
    );

    address[] public owners;    
    address[] public guaranteers;
    uint public daysOpen = 28;
    uint minimalVoterTurnoutPercent = 50;
    
    State public state;
    Result public result;
    CancelReason public cancelationReason;   

    AccountManagement private accMng;
    Poll private poll;
    Utils private utils;

    constructor(AccountManagement _accMngAddress, address[] memory _owners, string memory _title, string memory _description, string memory _confirmTitle, string memory _confirmDescription, string memory _rejectTitle, string memory _rejectDescription) {        
        accMng = _accMngAddress;
        create(_owners, _title, _description, _confirmTitle, _confirmDescription, _rejectTitle, _rejectDescription);  
    }

    modifier isActive() {
        bool active = false;
        if(state == State.CREATED || state == State.APPROVED || state == State.RUNNING)
        {
            if(!hasDeadlinePassed()){
                active = true;
            }
        }
        require(active, "The poll must be in an active state!");
        _;
    }

    modifier isRunning() {
        bool active = false;
        if(state == State.RUNNING)
        {
            if(!hasDeadlinePassed()){
                active = true;
            }
        }
        require(active, "The poll must be in a running state!");
        _;
    }

    modifier onlyCouncelors (){
        require(accMng.hasCouncilMemberRole(msg.sender), "Function can only called by Councelors");
        _;
    }

    function setState(State _state, string memory _description) private {
        emit StateChanged(msg.sender, state, _state, _description);
        state = _state;
    }


    // -----------------------------------
    // ------- Manage Life Cycle ---------
    // -----------------------------------

    function create(address[] memory _owners, string memory _title, string memory _description, string memory _confirmTitle, string memory _confirmDescription, string memory _rejectTitle, string memory _rejectDescription) private{
        if(canCreate(_owners)) {
            utils = new Utils();
            poll = new Poll(_owners, _title, _description, true);  
            poll.addOption(msg.sender, msg.sender, true, _confirmTitle, _confirmDescription);       
            poll.addOption(msg.sender, msg.sender, true, _rejectTitle, _rejectDescription);  
            owners = _owners;              
            setState(State.CREATED, "Referendum created!");
        }
        else{
            revert("One or more users can't create a referendum!");
        }       
    }

    function approve() onlyCouncelors public {
        if(state == State.CREATED)
        {
            setState(State.APPROVED, "Council has approved the referendum!");
        }
        else{
            revert("Referendum is not in the 'Created' state and can therefore not be approved.");
        }
    }

    function start() onlyCouncelors public {
        if(state == State.APPROVED)
        {
            setState(State.RUNNING, "Council has approved the referendum!");
        }
        else{
            revert("Referendum is not in the 'Approved' state and can therefore not be started.");
        }
       
    }

    function close() onlyCouncelors public {
        if(state == State.RUNNING)
        {
            if(hasMinimumVoterTurnout())
            {
                result = getResult();   
                setState(State.CLOSED, "Council has closed the referendum!");        
            }
            else{
                cancel(CancelReason.NOTENOUGHVOTERTURNOUT, "Referendum canceled: Voter turnout has been too small!");
            }     
        }
        else{
            revert("Referendum is not in the 'RUNNING' state and can therefore not be finished.");
        }           
    }

    function cancel(CancelReason _reason, string memory _description) onlyCouncelors private {
        setState(State.CANCELED, _description);
        cancelationReason = _reason;
    }


    // -----------------------------------
    // ------- Manage Results ------------
    // -----------------------------------

    function getConfirmCount() public view returns (uint) {
        Poll.Option[] memory options = poll.getOptions();
        Poll.Option memory confirmOption = options[0];
        uint confirmCount = confirmOption.voterCount;
        return confirmCount;
    }

    function getRejectCount() public view returns (uint) {
        Poll.Option[] memory options = poll.getOptions();
        Poll.Option memory confirmOption = options[1];
        uint rejectCount = confirmOption.voterCount;
        return rejectCount;
    }

    function getResult() public view returns (Result) {
        Result res = Result.AYES;
        uint ayeCount = getConfirmCount();
        uint noCount = getRejectCount();
        if(ayeCount == noCount)
        {
            res = Result.DRAW;
        }
        else if(ayeCount < noCount){
            res = Result.NOES;
        }
        return res;
    }

    function getVoterTurnout() public view returns (uint) {
        return poll.getVoterCount();
    }

    function getMinimalVoterTurnout() public view returns (uint){
        uint votes = getVoterTurnout();
        return utils.divideAndRoundUp(votes * minimalVoterTurnoutPercent, 100);
    }   
    

    // -----------------------------------
    // ------- Manage Voting ------------
    // -----------------------------------

    function voteAye() isRunning public {
        vote(1000);
    }

    function voteNo() isRunning public {
        vote(1001);
    }

    function vote (uint _optionId) private {
        poll.voteForOption(msg.sender, _optionId);
    }

    function removeVote() isActive public {
        poll.removeVoteForOption(msg.sender);
    }



    // -----------------------------------
    // ------- Check Rights --------------
    // -----------------------------------

    function canCreate(address[] memory _creators) public view returns (bool) {
        bool can = true;
        for (uint i = 0; i < _creators.length; i++) {
            if(!accMng.hasLeaderRole(_creators[i]))
            {
                can = false;
            }
        }
        return can;
    }

    function canApprove(address[] memory _guaranteers) public view returns (bool) {
        bool can = true;
        for (uint i = 0; i < _guaranteers.length; i++) {
            if(!accMng.hasCouncilMemberRole(_guaranteers[i]))
            {
                can = false;
            }
        }
        return can;
    }

    function canStart(address[] memory _creators) public view returns (bool) {
        bool can = true;
        for (uint i = 0; i < _creators.length; i++) {
            if(!accMng.hasLeaderRole(_creators[i]))
            {
                can = false;
            }
        }
        return can;
    }

    function canVote() public view returns (bool) {
        address _userAddress = msg.sender;
        if(accMng.hasMemberRole(_userAddress) || accMng.hasCouncilMemberRole(_userAddress) || accMng.hasLeaderRole(_userAddress))
        {
            return true;
        }
        return false;
    }

    function canCancel() public view returns (bool) {
        address _userAddress = msg.sender;
        if(accMng.hasCouncilMemberRole(_userAddress))
        {
            return true;
        }
        return false;
    }




    // -----------------------------------
    // ----- Check Preconditions ---------
    // -----------------------------------

    function hasDeadlinePassed() public view returns (bool){
        bool deadlineReached = false;
        uint timestamp = block.timestamp;
        uint deadline = poll.getCreationDate() + (daysOpen * 1 days);

        if (timestamp > deadline){
            deadlineReached = true;
        }
        return deadlineReached;
    }

    function hasMinimumVoterTurnout() public view returns (bool){
        uint votes = getVoterTurnout();
        uint minimalVotesNeeded = getMinimalVoterTurnout();
        return votes > minimalVotesNeeded;
    }
}