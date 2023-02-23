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
        poll = new Poll(_owners, _title, _description);        
        utils = new Utils();
    }

    modifier isActive() {
        require(state == State.CREATED || state == State.ANNOUNCED || state == State.PUBLISHED, "The poll must be in an active state.");
        _;
    }

    // -----------------------------------
    // ------- Manage Options ------------
    // -----------------------------------

    function addOption(string memory _title, string memory _description) public {
        // options are connected to polls
        // option ids start with 1000 to be able to distniguish in the mapping who has voted for an option and who hasn't (meaning returning a value of 0)
        poll.addOption(msg.sender, true, _title, _description);                  
    }

    function disableOption(uint _optionId) public {
        poll.disableOption(_optionId);
    }   

    // -----------------------------------
    // ------- Manage Voting ------------
    // -----------------------------------

    function voteForOption (uint _optionId) public {
        poll.voteForOption(_optionId);
    }

    function removeVoteForOption() public {
        poll.removeVoteForOption();
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
        address _userAddress = msg.sender;
        if(accountManagement.hasLeaderRole(_userAddress) || accountManagement.hasCouncilMemberRole(_userAddress) || accountManagement.hasMemberRole(_userAddress))
        {
            return true;
        }
        return false;
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

        function hasRightToCreateReferendum(address _address) external view returns (bool) {
        User memory user = users[_address];
        if(user.userAddress != address(0))
        {
            if(user.isActive && (user.roleMap.isLeader || user.roleMap.isCouncilMember || user.roleMap.isMember)){
                return true;
            }
        }
        return  false;
    }

    function hasRightToVote(address _address) external view returns (bool) {
        User memory user = users[_address];
        if(user.userAddress != address(0))
        {
            if(user.isActive && (user.roleMap.isLeader || user.roleMap.isCouncilMember || user.roleMap.isMember)){
                return true;
            }
        }
        return  false;
    }

    function hasRightToSupport(address _address) external view returns (bool) {
        User memory user = users[_address];
        if(user.userAddress != address(0))
        {
            if(user.isActive && (user.roleMap.isLeader || user.roleMap.isCouncilMember || user.roleMap.isMember)){
                return true;
            }
        }
        return  false;
    }
}