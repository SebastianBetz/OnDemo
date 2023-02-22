// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract Election {
    
    address owner;

    struct Candidate {
        string firstName;
        string secondName;
        uint age;
        uint receivedVotes;
    }

    mapping(uint => Candidate) public candidateList;

    string title;
    string description;
    
    address[] private voters;  
    bool isEnabled = true;

    constructor(string memory _title, string memory _description) {
        owner = msg.sender;
        title = _title;
        description = _description;
        isEnabled = true;        
    }

    modifier onlyOwner(){
        require(msg.sender == owner, "must be owner");
        _;
    }

    modifier onlyIfNotVotedYet(){
        bool hasVoted = false;
        for(uint i = 0; i < voters.length; i++)
        {
            if(voters[i] == msg.sender){
                require(false, "Voter has already voted");
            }
        }
        assert(true);
        _;
    }

    function changeTitle ( string memory _newTitle) onlyOwner public {
        title = _newTitle;
    }

    function changeDescription ( string memory _newDscription) onlyOwner public {
        description = _newDscription;
    }


    function addCandidate(uint _id, string memory _firstName, string memory _lastName, uint _age) public {
        candidateList[_id] = Candidate(_firstName, _lastName, _age, 0);
    }

    function voteForCandidate (uint _id) onlyIfNotVotedYet public {
        voters.push(msg.sender);
        candidateList[_id].receivedVotes++;
    }

    function getResult () public view returns (string memory) {
        
    }

    function disable() external{
        isEnabled = false;
    }

}




contract Consultations {

    Consultation[] public consultations;    
    uint[] public consultationIds;

    event ConsultationCreated(address consultationAdress, Consultation consultation);

    function createConsultation (uint _index,  string memory _title, string memory _description) public {
        Consultation c = new Consultation(_index, _title, _description);
        consultationIds.push(_index);
        consultations.push(c);
        emit ConsultationCreated(address(c), c);
    }

    function votePro(Consultation _consultation) public {
        consultations[_consultation.index()].votePro();
    }

    function voteAgainst(Consultation _consultation) public {
        consultations[_consultation.index()].voteAgainst();
    }

    function getAllConsultations() public view returns (Consultation[] memory){
        Consultation[] memory cArray;
        for(uint i = 0; i < consultationIds.length; i++)
        {
            cArray[i] = consultations[consultationIds[i]];
        }
        return cArray;
    }
}

contract Consultation {
    
    address owner;

    uint public index;
    string public title;
    string public description;
    address[] private voters;  
    int public voteProCount = 0;
    int public voteAgainstCount = 0;
    bool isEnabled = true;

    constructor(uint _index, string memory _title, string memory _description) {
        owner = msg.sender;
        index = _index;
        title = _title;
        description = _description;
        isEnabled = true;
    }

    modifier onlyOwner(){
        require(msg.sender == owner, "must be owner");
        _;
    }

    modifier onlyIfNotVotedYet(){
        bool hasVoted = false;
        for(uint i = 0; i < voters.length; i++)
        {
            if(voters[i] == msg.sender){
                require(false, "Voter has already voted");
            }
        }
        assert(true);
        _;
    }

    function changeTitle ( string memory _newTitle) onlyOwner public {
        title = _newTitle;
    }

    function changeDescription ( string memory _newDscription) onlyOwner public {
        description = _newDscription;
    }

    function votePro () onlyIfNotVotedYet external {
        voters.push(msg.sender);
        voteProCount++;
    }

    function voteAgainst () onlyIfNotVotedYet external {
        voters.push(msg.sender);
        voteAgainstCount++;
    }

    function getResult () public view returns (string memory) {
        if(voteProCount == voteAgainstCount){
            return "The Consultation has concluded to a draw!";
        }
        else if(voteProCount > voteAgainstCount)
        {
            return "The Consultation has been accepted!";
        }
        else{
            return "The Consultation has been negated!";
        }
    }

    function disable() external{
        isEnabled = false;
    }
}
