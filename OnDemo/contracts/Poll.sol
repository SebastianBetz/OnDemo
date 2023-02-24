// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

import "./Utils.sol";

contract Poll {
    // A simple polling contract which can function as an interface for more complex polling like consultations, referendums and elections
    // voting can be exclusive and not exclusive

    enum State { 
        CREATED, 
        ACTIVE,     // Votes can be casted
        DEACTIVATED // Edits are not possible
    }

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
    Option[] private options;   
    uint public voterCount;   
    State public state;
    bool public exclusiveVote; // if true a voter can only vote on one option

    mapping(address => uint[]) votersToOptionMapping; // keep track on which voter voted on what option

    Utils private utils;

    
    constructor(address[] memory _owners, string memory _title, string memory _description, bool _exclusiveVote) {
        utils = new Utils();
        create(_owners, _title, _description, _exclusiveVote);    
    }
    
    /*    
    // testing
    // use this constructor and the testPoll function to test the polling interface
    
    constructor() {
        utils = new Utils();
        testPoll(); 
    }

    function testPoll() public {
        address[] memory _owners = new address[](1);
        _owners[0] = msg.sender;
        string memory _title = "MyPoll";
        string memory _description = "MyPoll";
        create(_owners, _title, _description, false); 
        addOption(msg.sender, msg.sender, true, "A", "");
        addOption(msg.sender, msg.sender, true, "B", "");
    }
    
    */


    // -----------------------------------
    // ------- Manage Polls --------
    // -----------------------------------

    modifier onlyOwners (address _userAddress){
        bool isOwner = true;
        for (uint i = 0; i < owners.length; i++) {
            if (_userAddress == owners[i]) {
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

    function activate(address _userAddress) onlyOwners(_userAddress) public {
        setState(State.ACTIVE, "Poll activated!");
    }

    function disable(address _userAddress) onlyOwners(_userAddress) public {
        setState(State.DEACTIVATED, "Poll disabled!");
    }


    // -----------------------------------
    // ------- Manage Options ------------
    // -----------------------------------

    function addOption(address _creator, address _owner, bool _enabled, string memory _title, string memory _description) isActive onlyOwners(_creator) public {
        // options are connected to polls
        // option ids start with 1000 to be able to distniguish in the mapping who has voted for an option and who hasn't (meaning returning a value of 0)
           
        uint optionId = options.length + 1000;
        Option memory a = Option(optionId, _owner, _creator, _enabled, _title, _description, 0);       
        options.push(a);            
    }

    function getOption(uint _optionId) private view returns (Option storage) {
        for(uint i; i < options.length; i++) {
            if(options[i].id == _optionId){
                return options[i];
            }
        }
        revert("Not found");
    }

    function enableOption(uint _optionId) public {
        for(uint i; i < options.length; i++) {
            if(options[i].id == _optionId){
                options[i].isActive = true;
                return;
            }
        }
        revert("Not found");
    }

    function disableOption(uint _optionId) public {
        for(uint i; i < options.length; i++) {
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

    function voteForOption (address _userAddress, uint _optionId) isActive public {
        // vote on an option
        // if another option is voted on check if its an exclusive voting poll

        Option storage o = getOption(_optionId);
        if(o.isActive)
        {
            uint[] storage votedOptionIds = votersToOptionMapping[_userAddress];
            if(votedOptionIds.length == 0)
            {
                // set new vote      

                uint[] memory newVotedOptionIds = new uint[](1);
                newVotedOptionIds[0] = _optionId;
                votersToOptionMapping[_userAddress] = newVotedOptionIds;
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

    function removeVoteForOption(address _userAddress) isActive public{
        if(!exclusiveVote) {
            revert("Please provide which vote should be removed");
        }
        else{
            uint[] memory votedOptionIds = votersToOptionMapping[_userAddress];
            removeVoteForOption(_userAddress, votedOptionIds[0]);
        }
    }

    function removeVoteForOption(address _userAddress, uint _optionId) isActive public {
        // removes the vote for an option
        
        bool success = false;
        uint[] memory votedOptionIds = votersToOptionMapping[_userAddress];
        if(votedOptionIds.length == 0)
        {
            revert("User did not vote yet");            
        }
        else{
            if(exclusiveVote){
                votedOptionIds = new uint[](0);             
            }   
            else{
                bool found = false;
                uint index;
                for(index = 0; index < votedOptionIds.length; index++)
                {
                    if(_optionId == votedOptionIds[index]){
                        found = true;
                        if(index < votedOptionIds.length - 1)
                        {
                            votedOptionIds[index] = votedOptionIds[index + 1];
                        }
                    }
                }
                if(found)
                {
                    // Resize the array to remove any unused elements
                    uint newSize = votedOptionIds.length - 1;
                    assembly {
                        mstore(votedOptionIds, newSize)
                    }
                }   
                else{
                    revert("User did not vote for this option yet.");
                }
            }  

            Option storage oldOption = getOption(_optionId);
            oldOption.voterCount--;

            if(votedOptionIds.length == 0)
            {
                // if no voted options are left reduce voterCount for poll
                voterCount--;  
            } 

            votersToOptionMapping[_userAddress] = votedOptionIds;
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

    function getVoterCount() external view returns (uint) {
        return voterCount;
    }

    function getOptions() external view returns (Option[] memory) {
        return options;
    }

    function getOptionById(uint _id) external view returns (Option memory){
        return getOption(_id);
    }

    function enablePoll(address _userAddress) external {
        this.activate(_userAddress);
    }

    function disablePoll(address _userAddress) external {
        this.disable(_userAddress);
    }

    function isPollActive() external returns(bool){
        return state == State.ACTIVE;
    }
}