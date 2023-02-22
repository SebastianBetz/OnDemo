// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

import "./AccountManagement.sol";
import "./Utils.sol";

contract Poll {

    enum State { 
        ACTIVE,
        FROZEN,
        DEACTIVATED
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
    uint private creationDate;       
    Answer[] public answers;   
    uint public voterCount;   
    State public state;

    mapping(address => uint) votersToAnswerMapping;

    AccountManagement private accountManagement;
    Utils private utils;

    constructor(AccountManagement _accountManagementAddress, address[] memory _owners, string memory _title, string memory _description) {
        accountManagement = _accountManagementAddress;
        utils = new Utils();
        initPoll(_owners, _title, _description);    
    }




    // -----------------------------------
    // ------- Manage Polls --------
    // -----------------------------------

    function initPoll(address[] memory _owners, string memory _title, string memory _description) private returns(bytes32){
        
        // Check if at least one owner has the right to create a poll: Member / CouncilMember / Leader
        id = utils.generateGUID();
        title = _title;
        description = _description;
        creationDate = block.timestamp;
        state = State.ACTIVE;
        owners = _owners;
        return id;
    }

    modifier onlyOwners {
        bool isOwner = true;
        for (uint i = 0; i < owners.length; i++) {
            if (msg.sender == owners[i]) {
                isOwner = true;
                break;
            }
        }
        require(isOwner == true, "Only owners can call this function");
        _;
    }

    modifier isActive() {
        require(state == State.ACTIVE, "The poll must be in an active state.");
        _;
    }

    function setState(State _state) private {
        state = _state;
    }

    function activatePoll() onlyOwners public {
        setState(State.ACTIVE);
    }

    function freezePoll() onlyOwners public {
        setState(State.FROZEN);
    }

    function disablePoll() onlyOwners public {
        setState(State.DEACTIVATED);
    }




    // -----------------------------------
    // ---------- Manage owners ----------
    // -----------------------------------

    function addOwner(address _owner) isActive onlyOwners private{
        if(accountManagement.hasRightToCreateReferendum(_owner)) {
            owners.push(_owner);
        }
        else{
            revert('Owner has no right to create Poll');
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
        // answers are connected to polls
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
            //Take care of data in poll
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
    // ------- External Access -----------
    // -----------------------------------

    function getCreationDate() external view returns (uint) {
        return creationDate;
    }
}