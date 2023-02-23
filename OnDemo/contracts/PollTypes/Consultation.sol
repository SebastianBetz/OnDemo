// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

import "../AccountManagement.sol";
import "../Poll.sol";
import "../Utils.sol";

contract Consultation {

    enum CancelationReason { 
        DRAW,        
        NOTENOUGHVOTERTURNOUT,
        CANCELEDBYCOUNCIL
    }

    enum State { 
        CREATED,
        APPROVED,
        RUNNING,        
        CONFIRMED,
        REJECTED,
        CANCELED
    }

    enum Result{
        AYES,
        NOES,
        DRAW
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
    CancelationReason public cancelationReason;   

    AccountManagement private accountManagement;
    Poll private poll;
    Utils private utils;

    constructor(AccountManagement _accountManagementAddress, address[] memory _owners, string memory _title, string memory _description, string memory _confirmTitle, string memory _confirmDescription, string memory _rejectTitle, string memory _rejectDescription) {        
        accountManagement = _accountManagementAddress;
        if(canCreate(_owners)) {
            utils = new Utils();
            poll = new Poll(_accountManagementAddress, _owners, _title, _description);  
            poll.addAnswer(_confirmTitle, _confirmDescription);       
            poll.addAnswer(_rejectTitle, _rejectDescription);  
            owners = _owners;              
            setState(State.CREATED, "Consultation created!");
        }
        else{
            revert("One or more users can't create a consultation!");
        }        
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

    function setState(State _state, string memory _description) private {
        emit StateChanged(msg.sender, state, _state, _description);
        state = _state;
    }


    // -----------------------------------
    // ------- Manage Life Cycle ---------
    // -----------------------------------

    function approveConsultation(address[] memory _guaranteers) public {
        if(state == State.CREATED)
        {
            if(canApprove(_guaranteers))
            {
                setState(State.APPROVED, "Council has approved the referendum!");
            }
            else{
                revert("Only Members of the council can approve consultations.");
            }
        }
        else{
            revert("Consultation is not in the 'Created' state and can therefore not be approved.");
        }
    }

    function startConsultation(address[] memory _leaders) public {
        if(state == State.APPROVED)
        {
             if(canStart(_leaders))
            {
                setState(State.RUNNING, "Council has approved the referendum!");
            }
            else{
                revert("Only Members of the council can approve consultations.");
            }
        }
        else{
            revert("Consultation is not in the 'Approved' state and can therefore not be started.");
        }
       
    }

    function finishConsultation() private {
        if(state == State.RUNNING)
        {
            if(hasMinimumVoterTurnout())
            {
                Result res = getResult();
                if(res == Result.AYES)
                {
                    setState(State.CONFIRMED, "Ayes have it!");
                }
                else if(res == Result.NOES)
                {
                    setState(State.REJECTED, "Noes have it!");
                }
                else{
                    cancelConsultation(CancelationReason.DRAW, "It's a draw!");
                }
            }
            else{
                cancelConsultation(CancelationReason.NOTENOUGHVOTERTURNOUT, "Consultation canceled: Voter turnout has been too small!");
            }     
        }
        else{
            revert("Consultation is not in the 'RUNNING' state and can therefore not be finished.");
        }           
    }

    function cancelConsultationByCouncil() public {
        if(canCancel())
        {
            cancelConsultation(CancelationReason.CANCELEDBYCOUNCIL, "Consultation canceled by Council!");
        }
        else{
            revert("Only Members of the council can cancel consultations.");
        }
    }

    function cancelConsultation(CancelationReason _reason, string memory _description) private {
        setState(State.CANCELED, _description);
        cancelationReason = _reason;
    }


    // -----------------------------------
    // ------- Manage Results ------------
    // -----------------------------------

    function getConfirmCount() public view returns (uint) {
        Poll.Answer[] memory answers = poll.getAnswers();
        Poll.Answer memory confirmAnswer = answers[0];
        uint confirmCount = confirmAnswer.voterCount;
        return confirmCount;
    }

    function getRejectCount() public view returns (uint) {
        Poll.Answer[] memory answers = poll.getAnswers();
        Poll.Answer memory confirmAnswer = answers[1];
        uint rejectCount = confirmAnswer.voterCount;
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

    function voteAye() isActive public {
        vote(1000);
    }

    function voteNo() isActive public {
        vote(1001);
    }

    function vote (uint _answerId) private {
        poll.voteForAnswer(_answerId);
    }

    function removeVote() isActive public {
        poll.removeVoteForAnswer();
    }



    // -----------------------------------
    // ------- Check Rights --------------
    // -----------------------------------

    function canCreate(address[] memory _creators) public view returns (bool) {
        bool can = true;
        for (uint i = 0; i < _creators.length; i++) {
            if(!accountManagement.hasLeaderRole(_creators[i]))
            {
                can = false;
            }
        }
        return can;
    }

    function canApprove(address[] memory _guaranteers) public view returns (bool) {
        bool can = true;
        for (uint i = 0; i < _guaranteers.length; i++) {
            if(!accountManagement.hasCouncilMemberRole(_guaranteers[i]))
            {
                can = false;
            }
        }
        return can;
    }

    function canStart(address[] memory _creators) public view returns (bool) {
        bool can = true;
        for (uint i = 0; i < _creators.length; i++) {
            if(!accountManagement.hasLeaderRole(_creators[i]))
            {
                can = false;
            }
        }
        return can;
    }

    function canVote() public view returns (bool) {
        address _userAddress = msg.sender;
        if(accountManagement.hasRightToVote(_userAddress))
        {
            return true;
        }
        return false;
    }

    function canCancel() public view returns (bool) {
        address _userAddress = msg.sender;
        if(accountManagement.hasCouncilMemberRole(_userAddress))
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