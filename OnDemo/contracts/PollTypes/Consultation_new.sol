// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

import "../AccountManagement.sol";
import "../Poll.sol";
import "../Utils.sol";

contract Consultation {

    enum CancelationReason {         
        NOTENOUGHVoterTurnout,
        CANCELEDBYCOUNCIL,
        CANCELEDBYOWNERS
    }

    enum State { 
        CREATED,
        ANNOUNCED,        
        ACCEPTED,
        REJECTED,
        CANCELED
    }

    address[] public owners;    
    uint public deadline = 28;
    
    State public state;
    CancelationReason public cancelationReason;   

    AccountManagement private accountManagement;
    Poll private poll;
    Utils private utils;

    constructor(AccountManagement _accountManagementAddress, address[] memory _owners, string memory _title, string memory _description, string memory _confirmTitle, string memory _confirmDescription, string memory _rejectTitle, string memory _rejectDescription) {
        accountManagement = _accountManagementAddress;
        poll = new Poll(_accountManagementAddress, _owners, _title, _description);  
        //poll.addAnswer(_confirmTitle, _confirmDescription);       
        //poll.addAnswer(_rejectTitle, _rejectDescription);       
        utils = new Utils();
    }

    modifier isActive() {
        require(state == State.CREATED || state == State.ANNOUNCED, "The poll must be in an active state.");
        _;
    }

    // -----------------------------------
    // ------- Manage Answers ------------
    // -----------------------------------

    function addAnswer(string memory _title, string memory _description) public {
        // answers are connected to polls
        // answer ids start with 1000 to be able to distniguish in the mapping who has voted for an answer and who hasn't (meaning returning a value of 0)
        poll.addAnswer(_title, _description);                  
    }

    function disableAnswer(uint _answerId) public {
        poll.disableAnswer(_answerId);
    }   

    // -----------------------------------
    // ------- Manage Voting ------------
    // -----------------------------------

    function voteForAnswer (uint _answerId) public {
        poll.voteForAnswer(_answerId);
    }

    function removeVoteForAnswer() public {
        poll.removeVoteForAnswer();
    }


    // -----------------------------------
    // ------- Check Rights --------------
    // -----------------------------------

    function canCreate() public view returns (bool) {

    }

    function canVote() public view returns (bool) {
        address _userAddress = msg.sender;
        if(accountManagement.hasRightToVote(_userAddress))
        {
            return true;
        }
        return false;
    }
}