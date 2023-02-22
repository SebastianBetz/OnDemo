// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

import "./AccountManagement.sol";

contract Referendum {

    enum CancelationReason {         
        NOTENOUGHSUPPORTERSFORANNOUNCEMENT,
        NOTENOUGHSUPPORTERSFORPUBLICATION,
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

    struct Answer {
        uint id;
        address owner;
        string title;
        string description;
        uint voterCount;
    }

    bytes32 public id;
    address[] public owners;
    string public title;
    string public description;
    uint public creationDate;       
    Answer[] public answers;
    uint public announcementThresholdInDays = 28;
    uint public publicationThresholdInDays = 56;
    uint public supportShareNeededToAnnounce = 2;
    uint public supportShareNeededToPublish = 5;
    uint public voterCount;
    uint public supporterCount;
    State public state;
    CancelationReason public cancelationReason;   

    mapping(address => uint) votersToAnswerMapping;
    mapping(address => bool) supporters;

    AccountManagement private accountManagement;

    constructor(AccountManagement _accountManagementAddress, address[] memory _owners, string memory _title, string memory _description) {
        accountManagement = _accountManagementAddress;
        initReferendum(_owners, _title, _description);    
    }




    // -----------------------------------
    // ------- Manage Referendums --------
    // -----------------------------------

    function initReferendum(address[] memory _owners, string memory _title, string memory _description) private returns(bytes32){
        for(uint i = 0; i < _owners.length; i++)
        {
            address owner = _owners[i];
            if(!accountManagement.hasRightToCreateReferendum(owner))
            {
                string memory errorMsg = string.concat("User with address:'", toAsciiString(owner), "' has not permission to create a referendum");
                revert(errorMsg);
            }
        }

        // Check if at least one owner has the right to create a referendum: Member / CouncilMember / Leader
        id = generateGUID();
        title = _title;
        description = _description;
        creationDate = block.timestamp;
        state = State.CREATED;
        state = state;
        owners = _owners;
        return id;
    }

    modifier isActive() {
        require(state == State.CREATED || state == State.ANNOUNCED || state == State.PUBLISHED, "The referendum must be in an active state.");
        _;
    }

    modifier onlyOwners {
        bool isOwner = false;
        for (uint i = 0; i < owners.length; i++) {
            if (msg.sender == owners[i]) {
                isOwner = true;
                break;
            }
        }
        require(isOwner == true, "Only owners can call this function");
        _;
    }

    function setState(State _state) private {        
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

    function updateState() public returns (State){
        // This function needs to be run every x seconds so to check if deadlines have been reached or a certain amount of support has been received
        if(state == State.CREATED){
            if(checkAnnouncementDeadlineReached()){
                if(!checkAnnouncementThresholdReached())
                {
                    setState(State.CANCELED);
                    cancelationReason = CancelationReason.NOTENOUGHSUPPORTERSFORANNOUNCEMENT;
                }
                else{
                    announce();
                }
            }
        } else if (state == State.ANNOUNCED) {
            if(checkPublicationDeadlineReached()){
                if(!checkPublicationThresholdReached())
                {
                    setState(State.CANCELED);
                    cancelationReason = CancelationReason.NOTENOUGHSUPPORTERSFORPUBLICATION;
                }
                else{
                    publish();
                }
            }
            state = State.ANNOUNCED;

         } else if (state == State.PUBLISHED){
             //state = State.PUBLISHED;

         } else if (state == State.ACCEPTED){
             //state = State.ACCEPTED;

         } else if (state == State.REJECTED){
             //state = State.REJECTED;

         } else if (state == State.CANCELED){
             //state = State.CANCELED;

         } else {
            //stateMessage = "State Not Implemented!";
        }
        return state;
    }

    function announce() public {
        if(state == State.CREATED)
        {
            setState(State.ANNOUNCED);
        }
        else{
            revert("Referendum is in wrong state.");
        }
    }

    function publish() private {
        if(state == State.ANNOUNCED)
        {
            setState(State.PUBLISHED);
        }
        else{
            revert("Referendum is in wrong state.");
        }
    }

    function disableReferendum(CancelationReason _reason) onlyOwners private {
        setState(State.CANCELED);
        cancelationReason = _reason;
    }




    // -----------------------------------
    // ---------- Manage owners ----------
    // -----------------------------------

    function addOwner(address _owner) isActive onlyOwners private{
        if(accountManagement.hasRightToCreateReferendum(_owner)) {
            owners.push(_owner);
            supporterCount++;
            supporters[_owner] = true;
        }
        else{
            revert('Owner has no right to create Referendum');
        }
    }





    // -----------------------------------
    // ------- Manage Answers ------------
    // -----------------------------------

    modifier onlyAnswerOwner(uint _answerId) {
        bool isOwner = false;
        Answer memory a = getAnswer(_answerId);
        if(a.owner == msg.sender){
            isOwner = true;
        }

        require(isOwner == true, "Only owner can call this function.");
        _;
    }

    function addAnswer(string memory _title, string memory _description) isActive onlyOwners public {
        // answers are connected to referendums
        // answer ids start with 1000 to be able to distniguish in the mapping who has voted for an answer and who hasn't (meaning returning a value of 0)
        address user = msg.sender;               
        uint answerId = answers.length + 1000;
        Answer memory a = Answer(answerId, user, _title, _description, 0);       
        answers.push(a);            
    }

    function getAnswer(uint _answerId) private view returns (Answer storage) {
        for(uint i; i < answers.length; i++)        {
            if(answers[i].id == _answerId){
                return answers[i];
            }
        }
        revert('Not found');
    }

    function viewAnswers() public view returns (Answer[] memory) {
        return answers;
    }

    function disableAnswer(uint _answerId) onlyAnswerOwner(_answerId) isActive onlyOwners public {
        Answer storage a = getAnswer(_answerId);
        if(a.voterCount == 0){
            delete answers[_answerId];
        }
        else{
            revert("Can't remove answer which already holds votes");
        }
    }   




    // -----------------------------------
    // ------- Manage Voting ------------
    // -----------------------------------

    function voteForAnswer (uint _answerId) isActive public {
        address _userAddress = msg.sender;
        bool success = false;
        if(canVote())
        {
            Answer storage a = getAnswer(_answerId);
            uint oldAnswerId = votersToAnswerMapping[_userAddress];
            if(oldAnswerId != 0){
                //need to remove previous vote
                Answer storage oldAnswer = getAnswer(oldAnswerId);
                oldAnswer.voterCount--;
            }
            else if(oldAnswerId == _answerId){
                revert('User already voted for this answer');
            }
            else {
                voterCount++;
            }
            
            votersToAnswerMapping[_userAddress] = _answerId;
            a.voterCount++;
            success = true;
        }

        if(!success){
            revert('Unable to cast vote');
        }
    }

    function removeVoteForAnswer() isActive public {
        address _userAddress = msg.sender;
        bool success = false;
        uint answerId = votersToAnswerMapping[_userAddress];
        if(answerId != 0)
        {
            // Take care of data in answer
            Answer storage a = getAnswer(answerId);            
            a.voterCount--;
            //Take care of data in referendum
            votersToAnswerMapping[_userAddress] = 0;
            voterCount--;
            success = true;
        }
        else{
            revert('User did non vote for this answer');
        }        

        if(!success){
            revert('Unable to remove vote');
        }
    }





    // -----------------------------------
    // ------- Manage Support ------------
    // -----------------------------------

    function addSupport() isActive public {
        if(canSupport()){
            if(supporters[msg.sender] == false){
                supporters[msg.sender] = true;
                supporterCount++;
                updateState();
            }
            else{
                revert('User supports this referendum already');
            }
        }
    }

    function removeSupport() isActive public {
        if(supporters[msg.sender] == true){
            supporters[msg.sender] = false;
            supporterCount--;
        }
        else{
            revert('User did not support this referendum');
        }
    }
    





    // -----------------------------------
    // ------- Check Rights --------------
    // -----------------------------------

    function canSupport() public view isActive returns (bool) {
        address _userAddress = msg.sender;
        if(accountManagement.hasRightToSupport(_userAddress))
        {
            return true;
        }
        return false;
    }

    function canVote() public view isActive returns (bool) {
        address _userAddress = msg.sender;
        if(accountManagement.hasRightToVote(_userAddress))
        {
            return true;
        }
        return false;
    }

    // todo: Delete
    function getMinSupportCount() public view returns (uint){
        uint elegibleVoterCount = accountManagement.getActiveMemberCount();
        uint minSupporterCount = divideAndRoundUp(elegibleVoterCount * supportShareNeededToAnnounce, 100);
        return minSupporterCount;
    }

    function checkAnnouncementThresholdReached() public view isActive returns (bool){
        bool reached = false;
        uint elegibleVoterCount = accountManagement.getActiveMemberCount();
        uint minSupporterCount = divideAndRoundUp(elegibleVoterCount * 100, supportShareNeededToAnnounce);

        if(supporterCount > minSupporterCount){
            reached = true;
        }
        return reached;    
    }

    function checkPublicationThresholdReached() public view isActive returns (bool){
        bool reached = false;
        uint elegibleVoterCount = accountManagement.getActiveMemberCount();
        uint minSupporterCount = divideAndRoundUp(elegibleVoterCount * 100, supportShareNeededToPublish);

        if(supporterCount > minSupporterCount){
            reached = true;
        }
        return reached;    
    }

    function checkAnnouncementDeadlineReached() public view isActive returns(bool){
        bool deadlineReached = false;
        uint timestamp = block.timestamp;
        uint publicationDeadline = creationDate + (announcementThresholdInDays * 1 days);

        if (timestamp > publicationDeadline){
            deadlineReached = true;
        }
        return deadlineReached;
    }

    function checkPublicationDeadlineReached() public view isActive returns(bool){
        bool deadlineReached = false;
        uint timestamp = block.timestamp;
        uint publicationDeadline = creationDate + (announcementThresholdInDays + publicationThresholdInDays * 1 days);

        if (timestamp > publicationDeadline){
            deadlineReached = true;
        }
        return deadlineReached;
    }



    // -----------------------------------
    // ------------- Utils ---------------
    // -----------------------------------


    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);            
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) {
            return bytes1(uint8(b) + 0x30);
        }
        else {
            return bytes1(uint8(b) + 0x57);
        }
    }

    function generateGUID() internal view returns (bytes32) {
        uint nonce = 0;
        uint rand = uint(keccak256(abi.encodePacked(nonce, block.timestamp, block.difficulty, block.coinbase)));
        nonce++;
        return bytes32(rand);
    }

    function divideAndRoundUp(uint numerator, uint denominator) public pure returns (uint256) {
        uint256 quotient = numerator / denominator;
        if (numerator % denominator != 0) {
            quotient = quotient + 1;
        }
        return quotient;
    }
}