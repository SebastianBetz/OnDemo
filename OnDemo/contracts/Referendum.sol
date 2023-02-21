// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./AccountManagement.sol";

contract ReferendumManagement {

    enum CancelationReason {         
        PUBLICATIONTHRESHOLDNOTREACHED,
        SUPERVISIONTHRESHOLDNOTREACHED,
        CANCELEDBYCOUNCIL,
        CANCELEDBYOWNERS
    }

    enum State { 
        CREATED,
        ANNOUNCED,
        PUBLISHED,
        ACCEPTED,
        REJECTED,
        CANCELED
    }

    struct Referendum {
        
        uint id;
        string title;
        string description;
        uint creationDate;       
        uint announcementThresholdInDays;
        uint publicationThresholdInDays;
        uint voteShareNeededToAnnounce;
        uint voteShareNeededToPublish;
        State state;
        uint answerCount;
        CancelationReason cancelationReason;        
        mapping(address => bool) owners;
        mapping(uint => Answer) answers; // all answers
        mapping(address => bool) voters;
        mapping(address => bool) supporters;
    }

    struct Answer {
        uint id;
        address creator;
        string title;
        string description;
        mapping(address => bool) voters;
    }

    address public owner;
    AccountManagement public accountManagement;

    uint referendumCount;
    mapping(uint => Referendum) public referendums; // all referendums registered

    constructor(AccountManagement _accountManagementAddress) {
        accountManagement = _accountManagementAddress;
    }

    // Manage Referendums

    function createReferendum(string memory _title, string memory _description) public returns (uint) {
        
        // Check if at least one owner has the right to create a referendum: Member / CouncilMember / Leader
        // todo: check if other owners actually exist!
        if(accountManagement.hasRightToCreateReferendum(msg.sender))
        {
            uint referendumId = referendumCount;
            referendumCount++;

            uint announcementThresholdInDays = 28;
            uint publicationThresholdInDays = 28;

            uint voteShareNeededToAnnounce = 2;
            uint voteShareNeededToPublish = 10;

            uint creationDate = block.timestamp;
            State state = State.CREATED;
            uint answerCount = 0;

            Referendum storage ref = referendums[referendumId];
            ref.id = referendumId;
            ref.title = _title;
            ref.description = _description;
            ref.creationDate = creationDate;
            ref.announcementThresholdInDays = announcementThresholdInDays;
            ref.publicationThresholdInDays = publicationThresholdInDays;
            ref.voteShareNeededToAnnounce = voteShareNeededToAnnounce;
            ref.voteShareNeededToPublish = voteShareNeededToPublish;
            ref.state = state;
            ref.answerCount = answerCount;

            addOwner(ref, msg.sender);
            return referendumId;
        }
    }

    function addOwner(Referendum storage _ref, address _owner) private{
        _ref.owners[_owner] = true;
        _ref.supporters[_owner] = true;
    }

    function addOwners(uint _referendumId, address[] memory _owners) public{
        Referendum storage ref = getReferendum(_referendumId);
        if (ref.state == State.CREATED || ref.state == State.ANNOUNCED || ref.state == State.PUBLISHED) {
            for (uint i = 0; i < _owners.length; i++) {
                if(accountManagement.hasRightToCreateReferendum(_owners[i])) {
                    ref.owners[_owners[i]] = true;
                    ref.supporters[_owners[i]] = true;
                }
            }
        }
    }

    function addAnswer(uint _referendumId, string memory _title, string memory _description) public returns (bool) {
        Referendum storage ref = getReferendum(_referendumId);
        address user = msg.sender;
         if (ref.state == State.CREATED || ref.state == State.ANNOUNCED || ref.state == State.PUBLISHED) {
                uint answerId = ref.answerCount + 1;
                Answer storage a = ref.answers[answerId];
                a.id = answerId;
                a.creator = user;
                a.title = _title;
                a.description = _description;
                ref.answerCount++;
                return true;
            }
        return false;
    }

    function removeAnswer(uint _referendumId, uint _answerId) public
    {
        Referendum storage ref = getReferendum(_referendumId);
        delete ref.answers[_answerId];
    }
    
    function getReferendum(uint _id) private view returns (Referendum storage){
        return  referendums[_id];
    }

    function getAnswer(uint _referendumId, uint _answerId) private view returns (Answer storage){
        Referendum storage ref = getReferendum(_referendumId);
        return ref.answers[_answerId];
    }


    // Interact with referendums

    function canSupport(address _userAddress, uint _referendumId) public view returns (bool) {
        if(accountManagement.hasRightToSupport(_userAddress))
        {
            Referendum storage ref = getReferendum(_referendumId);
            if(ref.state == State.CREATED || ref.state == State.ANNOUNCED || ref.state == State.PUBLISHED)
            {
                if(!ref.supporters[_userAddress])
                {
                    return true;
                }
            }
        }
        return false;
    }

    function canVote(address _userAddress, uint _referendumId) public view returns (bool) {
        if(accountManagement.hasRightToVote(_userAddress))
        {
            Referendum storage ref = getReferendum(_referendumId);
            if(ref.state == State.CREATED || ref.state == State.ANNOUNCED || ref.state == State.PUBLISHED)
            {
                if(!ref.voters[_userAddress])
                {
                    return true;
                }
            }
        }
        return false;
    }

    
    function voteForAnswer (uint _referendumId, uint _answerId) public returns (bool) {
        address _userAddress = msg.sender;
        if(canVote(_userAddress, _referendumId))
        {
            Answer storage a = getAnswer(_referendumId, _answerId);
            if(a.id == _answerId){
                Referendum storage ref = getReferendum(_referendumId);
                ref.voters[_userAddress] = true;
                a.voters[_userAddress] = true;
                return true;
            }
        }
        return false;
    }

    
    function disableReferendum(CancelationReason _reason) private returns (bool) {
        //advanceReferendumToNextState(State.CANCELED);
    }

    /*
    modifier checkDeadlines (uint _timeStamp) {
        bool referendumIsActive = true;
        if (_timeStamp > block.timestamp + publicationThresholdInDays){
            disableReferendum(CancelationReason.PUBLICATIONTHRESHOLDREACHED);
            referendumIsActive = false;
        }
        else if (_timeStamp > block.timestamp + publicationThresholdInDays){
            disableReferendum(CancelationReason.SUPERVISIONTHRESHOLDREACHED);
            referendumIsActive = false;
        }
        require(referendumIsActive, "ReferendumHasEndedAlready");
        _;
    }
    */

   /*  function checkParticaptionThreshold() private returns (bool){
        //checkDeadlines(uint _timeStamp)

        bool canAdvance = false;
        if (state == State.ANNOUNCED){
            if (elegibleVoterCount / supporters.length > voteShareNeededToAnnounce){
                advanceReferendumToNextState(State.ANNOUNCED);
                canAdvance = true;
            }
        } else if (state == State.PUBLISHED){
            if (elegibleVoterCount / supporters.length > voteShareNeededToPublish){
                advanceReferendumToNextState(State.PUBLISHED);
                canAdvance = true;
            }
        }
        return canAdvance;
    }

    function advanceReferendumToNextState(State _state) public returns (bool) {
        
        //checkDeadlines(uint _timeStamp)
        string memory stateMessage = "";

        if (_state == State.ANNOUNCED) {
                state = State.ANNOUNCED;

         } else if (_state == State.PUBLISHED){
             state = State.PUBLISHED;

         } else if (_state == State.ACCEPTED){
             state = State.ACCEPTED;

         } else if (_state == State.REJECTED){
             state = State.REJECTED;

         } else if (_state == State.CANCELED){
             state = State.CANCELED;

         } else {
            stateMessage = "State Not Implemented!";
            }
        } */

        //emit(stateMessage);
    }
