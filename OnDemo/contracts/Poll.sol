// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

import "./Utils.sol";

contract Poll {
    // A simple polling contract which can function as an interface for more complex polling like consultations, referendums and elections
    // voting can be exclusive and not exclusive

    enum State { CREATED, ACTIVE, FROZEN, DEACTIVATED }

    event StateChanged(
        address indexed _by,
        State oldState,
        State newState,
        string description
    );

    // a option can be voted on
    struct Option {
        uint id;
        address owner;
        address creator;
        bool isActive;
        string title;
        string description;
        uint voterCount;
    }

    bytes32 public id; // guid
    address[] public owners;
    string public title;
    string public description;
    uint private creationDate;       
    Option[] public options;   
    uint public voterCount;   
    State public state;
    bool public exclusiveVote; // if true a voter can only vote on one option

    mapping(address => uint[]) votersToOptionMapping; // keep track on which voter voted on what option

    Utils private utils;

    constructor(address[] memory _owners, string memory _title, string memory _description, bool _exclusiveVote) {
        utils = new Utils();
        create(_owners, _title, _description, _exclusiveVote);    
    }




    // -----------------------------------
    // ------- Manage Polls --------
    // -----------------------------------

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

    function setState(State _state, string memory _description) private {
        if(state != _state)
        {
            emit StateChanged(msg.sender, state, _state, _description);
            state = _state;
        }
        else{
            revert("State not changed. New state is the same as old state!");
        }

    }

    function create(address[] memory _owners, string memory _title, string memory _description, bool _exclusiveVote) private returns(bytes32){
        
        // Check if at least one owner has the right to create a poll: Member / CouncilMember / Leader
        id = utils.generateGUID();
        title = _title;
        description = _description;
        creationDate = block.timestamp;        
        owners = _owners;
        state = State.CREATED;
        exclusiveVote = _exclusiveVote;
        setState(State.ACTIVE, "Poll created!");
        return id;
    }

    function activate() onlyOwners public {
        setState(State.ACTIVE, "Poll activated!");
    }

    function freeze() onlyOwners public {
        setState(State.FROZEN, "Poll frozen!");
    }

    function disable() onlyOwners public {
        setState(State.DEACTIVATED, "Poll disabled!");
    }


    // -----------------------------------
    // ------- Manage Options ------------
    // -----------------------------------

    modifier onlyOptionOwner(uint _optionId) {
        bool isOwner = false;
        Option memory a = getOption(_optionId);
        if(a.owner == msg.sender){
            isOwner = true;
        }

        require(isOwner == true, "Only owner can call this function.");
        _;
    }

    function addOption(address _owner, bool _enabled, string memory _title, string memory _description) isActive onlyOwners public {
        // options are connected to polls
        // option ids start with 1000 to be able to distniguish in the mapping who has voted for an option and who hasn't (meaning returning a value of 0)

        address user = msg.sender;               
        uint optionId = options.length + 1000;
        Option memory a = Option(optionId, _owner, user, _enabled, _title, _description, 0);       
        options.push(a);            
    }

    function getOption(uint _optionId) private view returns (Option storage) {
        for(uint i; i < options.length; i++)        {
            if(options[i].id == _optionId){
                return options[i];
            }
        }
        revert("Not found");
    }

    function enableOption(uint _optionId) public {
        for(uint i; i < options.length; i++)        {
            if(options[i].id == _optionId){
                options[i].isActive = true;
                return;
            }
        }
        revert("Not found");
    }

    function disableOption(uint _optionId) public {
        for(uint i; i < options.length; i++)        {
            if(options[i].id == _optionId){
                options[i].isActive = false;
                return;
            }
        }
        revert("Not found");
    }


    // -----------------------------------
    // ------- Manage Voting ------------
    // -----------------------------------

    function voteForOption (uint _optionId) isActive public {
        // vote on an option
        // if another option is voted on check if its an exclusive voting poll

        address _userAddress = msg.sender;
        Option storage o = getOption(_optionId);
        if(o.isActive)
        {
            uint[] storage votedOptionIds = votersToOptionMapping[_userAddress];
            if(votedOptionIds.length == 0)
            {
                // set new vote
                votedOptionIds[0] = _optionId;
                voterCount++;
            }
            else if(exclusiveVote)
            {               
                // remove old vote and set new vote                 
                uint oldOptionId = votedOptionIds[0];
                Option storage oldOption = getOption(oldOptionId);
                if(_optionId == oldOptionId)
                {
                    revert("User already voted for this option");
                }
                oldOption.voterCount--;    
                votersToOptionMapping[_userAddress] = [_optionId];            
            }
            else{
                for(uint i = 0; i < votedOptionIds.length; i++)
                {
                    uint oldOptionId = votedOptionIds[i];
                    if(oldOptionId == _optionId){
                        // prevent double voting on one option
                        revert("User already voted for this option");
                    }
                }
                votedOptionIds.push(_optionId);                
            }
            o.voterCount++;
        }
        else{
            revert("Option is not active!");
        }        
    }

    function removeVoteForOption() isActive public{
        if(!exclusiveVote) {
            revert("Please provide which vote should be removed");
        }
        else{
            voterCount = 10;
            uint[] memory votedOptionIds = votersToOptionMapping[msg.sender];
            removeVoteForOption(votedOptionIds[0]);
        }
    }

    function removeVoteForOption(uint _optionId) isActive public {
        // removes the vote for an option
        
        bool success = false;
        uint[] memory votedOptionIds = votersToOptionMapping[msg.sender];
        uint optionsVotedCount = votedOptionIds.length;
        if(optionsVotedCount == 0)
        {
            revert("User did not vote yet");            
        }
        else{
            if(exclusiveVote){
                votedOptionIds = new uint[](0);   
                voterCount--;             
            }   
            else{
                bool found = false;
                uint index;
                for(index = 0; index < optionsVotedCount; index++)
                {
                    uint oldOptionId = votedOptionIds[index];
                    if(oldOptionId == votedOptionIds[index]){
                        found = true;
                        if(index < optionsVotedCount - 1)
                        {
                            votedOptionIds[index] = votedOptionIds[index + 1];
                        }
                    }
                }
                if(found)
                {
                    delete votedOptionIds[votedOptionIds.length - 1];
                }     
                if(votedOptionIds.length == 0)
                {
                    voterCount--;  
                }    
            }  

            Option storage oldOption = getOption(_optionId);
            oldOption.voterCount--;

            votersToOptionMapping[msg.sender] = votedOptionIds;
            success = true;
        }    

        if(!success){
            revert('Unable to remove vote');
        }
        
    }

    // -----------------------------------
    // ------- External Access -----------
    // -----------------------------------

    function getTitle() external view returns (string memory) {
        return title;
    }

    function getDescription() external view returns (string memory) {
        return description;
    }

    function getCreationDate() external view returns (uint) {
        return creationDate;
    }

    function getOptionCount() external view returns (uint) {
        return voterCount;
    }

    function getVoterCount() external view returns (uint) {
        return voterCount;
    }

    function getOptions() external view returns (Option[] memory) {
        return options;
    }

    function getOptionId(Option memory _o) external pure returns(uint){
        return _o.id;
    }

    function isOptionActive(Option memory _o) external pure returns(bool){
        return _o.isActive;
    }
}