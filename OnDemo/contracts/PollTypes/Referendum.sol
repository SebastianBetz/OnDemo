// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

import "../AccountManagement.sol";
import "../Poll.sol";
import "../Utils.sol";

contract Referendum {
    // A referendum contract that uses the polling interface
    // A referendum can have multiple answers that are created by members. It has a deadline and can be started by any member.
    // A referendum has 3 phases.
    // 1.Phase: Members can create answers and express their support for the referendum. A min amount of support needs to be gathered before the deadline to continue.
    // 2.Phase: Members can create answers and express their support for the referendum. A min amount of support needs to be gathered before the deadline to continue.
    // 3.Phase: The Council approves or cancels the referendum. If approved the members can vote on ONE answer (Exclusive Voting).
    // A referendum extends the polling interface to include role based rights inherited from the accountmanagement contract.
    // Vote ids start with 1000 and are incremented

    enum CancelReason { 
        NOTENOUGHSUPPORTERSFORSTAGE1, // Deadline has passed before enough support was gathered
        NOTENOUGHSUPPORTERSFORSTAGE2, // Deadline has passed before enough support was gathered
        CANCELEDBYCOUNCIL,            // Council canceled
        CANCELEDBYOWNERS              // Owners canceled
    }

    enum State { 
        CREATED, 
        STAGE1,             // Referendum has gathered enough support before the first deadline
        STAGE2,             // Referendum has gathered enough support before the second deadline
        APPROVEDBYCOUNCIL,  // Referendum has been approved by council
        PUBLISHED,          // Referendum has been published by council
        CLOSED,             
        CANCELED 
    } 

    event StateChanged(
        address indexed _by,
        State oldState,
        State newState,
        string description
    );

    address[] public owners;    
    uint public stage1Threshold = 28; // in days
    uint public stage2Threshold = 28; // in days
    uint public stage1SupportThreshold = 20; // in % of elegible voters
    uint public stage2SupportThreshold  = 50;  // in % of elegible voters

    uint public supporterCount;
    State public state;
    CancelReason public cancelationReason;   

    AccountManagement private accMng;
    Poll private poll;
    Utils private utils;

    mapping(address => bool) supporters;

    constructor(AccountManagement _accMngAddress, address[] memory _owners, string memory _title, string memory _description) {
        accMng = _accMngAddress;
        poll = new Poll(_owners, _title, _description, true);        
        utils = new Utils();
    }

    modifier onlyIfIsActive () {
        require(state == State.CREATED || state == State.STAGE1 || state == State.STAGE2, "The poll must be in an active state.");
        _;
    }

    modifier onlyIfIsPublished () {
        require(state == State.PUBLISHED, "The poll must be in an active state.");
        _;
    }

    modifier onlyCouncelors (){
        require(accMng.hasCouncilMemberRole(msg.sender), "The poll must be in an active state.");
        _;
    }



    // -----------------------------------
    // ------- Manage Options ------------
    // -----------------------------------

    function addOption(string memory _title, string memory _description) onlyIfIsActive public {
        // options are connected to polls
        // option ids start with 1000 to be able to distniguish in the mapping who has voted for an option and who hasn't (meaning returning a value of 0)
        poll.addOption(msg.sender, msg.sender, true, _title, _description);                  
    }

    function disableOption(uint _optionId) onlyIfIsActive public {
        Poll.Option memory o = poll.getOptionById(_optionId);
        if(o.owner == msg.sender)
        {
            poll.disableOption(_optionId);
        }
        else{
            revert("Only Option owners can disable their option");
        }

    }   



    // -----------------------------------
    // ------- Manage Support ------------
    // -----------------------------------

    function support() onlyIfIsActive public {
        // referendums need support to push through stage 1 + 2. Here users can add their support
        if(canSupport()){
            if(supporters[msg.sender] == false){
                supporters[msg.sender] = true;
                supporterCount++;
            }
            else{
                revert("User supports this poll already");
            }
        }
        else{
            revert("User is not allowed to support this poll");
        }
    }

    function removeSupport() onlyIfIsActive public {
        // removes support from the referendum
        if(supporters[msg.sender] == true){
            supporters[msg.sender] = false;
            supporterCount--;
        }
        else{
            revert("User did not support this poll");
        }
    }
    


    // -----------------------------------
    // ------- Manage Voting ------------
    // -----------------------------------

    function vote (uint _optionId) onlyIfIsPublished public {
        // let the user vote on a option
        poll.voteForOption(msg.sender, _optionId);
    }

    function removeVote() onlyIfIsPublished public {
        // removes the users vote
        poll.removeVoteForOption(msg.sender);
    }

    



    // -----------------------------------
    // ---------- Manage State -----------
    // -----------------------------------

    function setState(State _state, string memory _description) private {
        emit StateChanged(msg.sender, state, _state, _description);
        state = _state;
    }

    function advanceToStage1() public {
        if(checkStage1ThresholdReached() && !checkStage1DeadlineReached())
        {
            setState(State.STAGE1, "advance");
        }
        else{
            revert("Threshold not reached or passed deadline ");
        }
    }

    function advanceToStage2() public {
        if(checkStage2ThresholdReached() && !checkStage2DeadlineReached())
        {
            setState(State.STAGE2, "advance");
        }
        else{
            revert("Threshold not reached or passed deadline ");
        }
    }

    function approve() onlyCouncelors public {
        setState(State.APPROVEDBYCOUNCIL, "council has approved");
    }

    function publish() onlyCouncelors public {
        setState(State.PUBLISHED, "council has published");
    }

    function close() onlyCouncelors public {
        setState(State.CLOSED, "council has closed the referendum");
    }

    function cancel(CancelReason _reason, string memory _description) onlyCouncelors private {
        setState(State.CANCELED, _description);
        cancelationReason = _reason;
    }



    // -----------------------------------
    // ------- Manage Results ------------
    // -----------------------------------

    function getWinningOption() public view returns (uint) {
        Poll.Option memory winOption;
        uint winoptionVoteCount = 0;

        Poll.Option[] memory options = poll.getOptions();

        for (uint i = 0; i < options.length; i++) {
            uint voteCount = options[i].voterCount;
            if(voteCount > winoptionVoteCount)
            {
                winOption = options[i];
            }
        }

        return winOption.id;
    }

    function getVoterTurnout() public view returns (uint) {
        return poll.getVoterCount();
    }



    // -----------------------------------
    // --------- Check Rights ------------
    // -----------------------------------

    function canCreate() public view returns (bool) {
        address _userAddress = msg.sender;
        if(accMng.hasLeaderRole(_userAddress) || accMng.hasCouncilMemberRole(_userAddress) || accMng.hasMemberRole(_userAddress))
        {
            return true;
        }
        return false;
    }

    function canSupport() public view returns (bool) {
        address _userAddress = msg.sender;
        if(accMng.hasMemberRole(_userAddress) || accMng.hasCouncilMemberRole(_userAddress) || accMng.hasLeaderRole(_userAddress))
        {
            return true;
        }
        return false;
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
        if(accMng.hasCouncilMemberRole(_userAddress) || accMng.hasLeaderRole(_userAddress))
        {
            return true;
        }
        return false;
    }



    // -----------------------------------
    // -------- Check Thresholds ---------
    // -----------------------------------

    function checkStage1ThresholdReached() public view returns (bool){
        bool reached = false;
        uint elegibleVoterCount = accMng.getActiveMemberCount();
        uint minSupporterCount = utils.divideAndRoundUp(elegibleVoterCount * stage1SupportThreshold , 100);

        if(supporterCount > minSupporterCount){
            reached = true;
        }
        return reached;    
    }

    function checkStage2ThresholdReached() public view returns (bool){
        bool reached = false;
        uint elegibleVoterCount = accMng.getActiveMemberCount();
        uint minSupporterCount = utils.divideAndRoundUp(elegibleVoterCount * stage2SupportThreshold , 100);

        if(supporterCount > minSupporterCount){
            reached = true;
        }
        return reached;    
    }

    function checkStage1DeadlineReached() public view returns(bool){
        bool deadlineReached = false;
        uint timestamp = block.timestamp;
        uint stage2Deadline = poll.getCreationDate() + (stage1Threshold * 1 days);

        if (timestamp > stage2Deadline){
            deadlineReached = true;
        }
        return deadlineReached;
    }

    function checkStage2DeadlineReached() public view returns(bool){
        bool deadlineReached = false;
        uint timestamp = block.timestamp;
        uint stage2Deadline = poll.getCreationDate() + (stage1Threshold + stage2Threshold * 1 days);

        if (timestamp > stage2Deadline){
            deadlineReached = true;
        }
        return deadlineReached;
    }
}