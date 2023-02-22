// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

import "../AccountManagement.sol";
import "../Poll.sol";
import "../Utils.sol";

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

    address[] public owners;    
    uint public announcementThresholdInDays = 28;
    uint public publicationThresholdInDays = 28;
    uint public supportShareNeededToAnnounce = 20;
    uint public supportShareNeededToPublish = 50;  

    uint public supporterCount;
    State public state;
    CancelationReason public cancelationReason;   

    AccountManagement private accountManagement;
    Poll private poll;
    Utils private utils;

    mapping(address => bool) supporters;

    constructor(AccountManagement _accountManagementAddress, address[] memory _owners, string memory _title, string memory _description) {
        accountManagement = _accountManagementAddress;
        poll = new Poll(_accountManagementAddress, _owners, _title, _description);        
        utils = new Utils();
    }

    modifier isActive() {
        require(state == State.CREATED || state == State.ANNOUNCED || state == State.PUBLISHED, "The poll must be in an active state.");
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
    // ------- Manage Support ------------
    // -----------------------------------

    function addSupport() isActive public {
        if(canSupport()){
            if(supporters[msg.sender] == false){
                supporters[msg.sender] = true;
                supporterCount++;
            }
            else{
                revert('User supports this poll already');
            }
        }
        else{
            revert('User is not allowed to support this poll');
        }
    }

    function removeSupport() isActive public {
        if(supporters[msg.sender] == true){
            supporters[msg.sender] = false;
            supporterCount--;
        }
        else{
            revert('User did not support this poll');
        }
    }
    


    // -----------------------------------
    // ------- Check Rights --------------
    // -----------------------------------

    function canCreate() public view returns (bool) {

    }

    function canSupport() public view returns (bool) {
        address _userAddress = msg.sender;
        if(accountManagement.hasRightToSupport(_userAddress))
        {
            return true;
        }
        return false;
    }

    function canVote() public view returns (bool) {
        address _userAddress = msg.sender;
        if(accountManagement.hasRightToVote(_userAddress))
        {
            return true;
        }
        return false;
    }

    function checkAnnouncementThresholdReached() public view returns (bool){
        bool reached = false;
        uint elegibleVoterCount = accountManagement.getActiveMemberCount();
        uint minSupporterCount = utils.divideAndRoundUp(elegibleVoterCount * supportShareNeededToAnnounce, 100);

        if(supporterCount > minSupporterCount){
            reached = true;
        }
        return reached;    
    }

    function checkPublicationThresholdReached() public view returns (bool){
        bool reached = false;
        uint elegibleVoterCount = accountManagement.getActiveMemberCount();
        uint minSupporterCount = utils.divideAndRoundUp(elegibleVoterCount * supportShareNeededToPublish, 100);

        if(supporterCount > minSupporterCount){
            reached = true;
        }
        return reached;    
    }

    function checkAnnouncementDeadlineReached() public view returns(bool){
        bool deadlineReached = false;
        uint timestamp = block.timestamp;
        uint publicationDeadline = poll.getCreationDate() + (announcementThresholdInDays * 1 days);

        if (timestamp > publicationDeadline){
            deadlineReached = true;
        }
        return deadlineReached;
    }

    function checkPublicationDeadlineReached() public view returns(bool){
        bool deadlineReached = false;
        uint timestamp = block.timestamp;
        uint publicationDeadline = poll.getCreationDate() + (announcementThresholdInDays + publicationThresholdInDays * 1 days);

        if (timestamp > publicationDeadline){
            deadlineReached = true;
        }
        return deadlineReached;
    }
}