// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract Referedum {

    enum CancelationReason { 
        PUBLICATIONTHRESHOLDREACHED,
        SUPERVISIONTHRESHOLDREACHED,
        CANCELEDBYGUARANTEES,
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

    address[] owners;
    string title;
    string description;
    uint creationDate;
    uint announcementThresholdDeadline;
    uint publicationThresholdDeadline;
    Answer[] possibleAnswers;
    address[] voters;
    address [] supporters; 
    State state;
    CancelationReason cancelationReason;

    // All voters, will be placed in umbrella smartContract later
    uint elegibleVoterCount;
    address[] elegibleVoters;

    uint announcementThresholdInDays = 28;
    uint publicationThresholdInDays = 28;

    uint voteShareNeededToAnnounce = 2;
    uint voteShareNeededToPublish = 10;

    struct Answer {
        uint id;
        address creator;
        string title;
        string description;
        address[] voters;
    }

    constructor ( string memory _title, string memory _description, address[] memory _coOwners, string[][] memory _possibleAnswers)
    {
        owners.push(msg.sender);
        title = _title;
        description = _description;
        creationDate = block.timestamp;
        state = State.CREATED;

        for (uint i = 0; i < _coOwners.length; i++) {
            owners.push(_coOwners[i]);
        }
    }

    modifier isElegibleToVote () {
        bool hasNotVoted = true;
        for (uint i = 0; i < elegibleVoters.length; i++) {
            if (elegibleVoters[i] == msg.sender) {
                hasNotVoted = false;
            } 
        }

        require(hasNotVoted, "User has voted already.");
        _;
    }

    modifier isElegibleToSupport () {
        bool isSupporter = true;
        for (uint i = 0; i < supporters.length; i++) {
            if (supporters[i] == msg.sender) {
                isSupporter = false;
            } 
        }
        require(isSupporter, "User has voted already.");
        _;
    }

    function voteForAnswer (uint _answerId) isElegibleToVote public returns (bool) {
        for (uint i = 0; i < possibleAnswers.length; i++) {
            Answer storage a = possibleAnswers[i];
            if (a.id == _answerId) {
                a.voters.push(msg.sender); 
                voters.push(msg.sender);
            return true;
            }
        }
        return false;
    }

    function support() isElegibleToSupport public {
        supporters.push(msg.sender);
    }

    function disableReferendum(CancelationReason _reason) private returns (bool) {
        cancelationReason = _reason;
        advanceReferendumToNextState(State.CANCELED);
    }

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

    function checkParticaptionThreshold() private returns (bool){
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
        }

        //emit(stateMessage);
    }
