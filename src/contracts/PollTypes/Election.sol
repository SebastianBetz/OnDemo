// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

import "../AccountManagement.sol";
import "../Poll.sol";
import "../Utils.sol";

contract Election {
    // An Election contract that uses the polling interface
    // An Election has two phases
    // 1.Phase: members can nominate other members. The nominees have to accept their nomination in order to participate in the election. Members can express their support for one or more nominees.
    // 2.Phase: nominees that have passed the minVotesBoundary are advancing to the actual election. In this election every member has only one vote
    // An Election extends the polling interface to include role based rights inherited from the accountmanagement contract.
    
    enum CancelReason { 
        DRAW, 
        NOTENOUGHVOTERTURNOUT, 
        CANCELEDBYCOUNCIL 
    }
    enum State { 
        CREATED, 
        NOMINATION, 
        ELECTION,
        INAUGURATION, 
        CLOSED, 
        CANCELED 
    }
    enum Result { 
        AYES, 
        NOES, 
        DRAW 
    }

    event StateChanged(
        address indexed _by,
        State oldState,
        State newState,
        string description
    );

    address[] public owners;
    address[] public guaranteers;
    uint public daysOpen = 28;
    uint minVoterTurnoutPercent = 50;
    uint minVotesBoundary = 1;
    uint maxCandidates;
    AccountManagement.Role role;

    State public state;
    CancelReason public cancelationReason;

    AccountManagement private accMng;
    Poll private nominationPoll;
    Poll private electionPoll;
    Utils private utils;

    /*
    constructor(AccountManagement _accMngAddress, address[] memory _owners, string memory _title, string memory _description, AccountManagement.Role _role, uint _maxCandidates) {        
        accMng = _accMngAddress;
        createPreselection(_owners, _title, _description, _role, _maxCandidates);  
    }
*/
    constructor() {}

    function _testElection() public {

        address[10] memory testAccounts = [ 
            0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, // leaderboard in test environment
            0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, // leaderboard in test environment
            0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, // council in test environment
            0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB, // council in test environment
            0x617F2E2fD72FD9D5503197092aC168c91465E7f2, // candidates 1
            0x17F6AD8Ef982297579C203069C1DbfFE4348c372, // candidates 2
            0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678, // candidates 3
            0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7,
            0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C,
            0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c
        ];

        address[] memory candidates = new address[](3);
        candidates[0] = 0x617F2E2fD72FD9D5503197092aC168c91465E7f2;
        candidates[1] = 0x17F6AD8Ef982297579C203069C1DbfFE4348c372;
        candidates[2] = 0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678;

        
        accMng = AccountManagement(0xd9145CCE52D386f254917e481eB44e9943F39138);
        string memory _title = "Elect new leadership";
        string memory _description = "A new leadership board should be instituted";
        AccountManagement.Role _role = AccountManagement.Role.LEADER;
        uint _maxCandidates = 2;

        address[] memory initiators = new address[](1);
        initiators[0] = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        
        createPreselection( initiators, _title, _description, _role, _maxCandidates );
        setState(State.CREATED, "Consultation created!");
        
        for(uint i = 0; i < candidates.length; i++)
        {
            addCandidate(candidates[i]);
        }        
    }

    modifier onlyIfIsActive () {
        // checks if the election is in an active state

        bool active = false;
        if (state == State.CREATED) {
            if (!hasDeadlinePassed()) {
                active = true;
            }
        }
        require(active, "The poll must be in an active state!");
        _;
    }

    modifier onlyDuringPreselection () {
        // checks if the election is in an active state

        bool active = false;
        if (state == State.NOMINATION) {
            if (!hasDeadlinePassed()) {
                active = true;
            }
        }
        require(active, "The poll must be nomination state!");
        _;
    }

    modifier onlyDuringElection () {
        // checks if the election is in an active state

        bool active = false;
        if (state == State.ELECTION) {
            if (!hasDeadlinePassed()) {
                active = true;
            }
        }
        require(active, "The poll must be nomination state!");
        _;
    }

    modifier onlyCouncelors (){
        require(accMng.hasCouncilMemberRole(msg.sender), "Only councelors can use this function");
        _;
    }

    // -----------------------------------
    // ---------- Manage State -----------
    // -----------------------------------

    function setState(State _state, string memory _description) private {
        emit StateChanged(msg.sender, state, _state, _description);
        state = _state;
    }

    function createPreselection( address[] memory _owners, string memory _title, string memory _description, AccountManagement.Role _role, uint _maxCandidates ) onlyCouncelors private {
        // Creates a poll in which canidadates can be added
        
        if (canCreate(_owners)) {
            utils = new Utils();
            nominationPoll = new Poll(_owners, _title, _description, false);
            owners = _owners;
            role = _role;
            maxCandidates = _maxCandidates;            
        } else {
            revert("One or more users can't create a consultation!");
        }
    }

    function createElection() onlyCouncelors private {
        // Creates a poll in which all qualified candidates from the nomination poll are added

        string memory electionTitle = nominationPoll.getTitle();
        string memory description = nominationPoll.getDescription();
        electionPoll = new Poll(owners, electionTitle, description, true);

        Poll.Option[] memory preWinners = getQualifiedCandidates();

        for (uint i = 0; i < preWinners.length; i++) {
            Poll.Option memory candidate = preWinners[i];
            address owner = candidate.owner;
            address creator = candidate.owner;
            string memory fName = candidate.title;
            string memory lName = candidate.description;

            electionPoll.addOption(creator, owner, true, fName, lName);
        }
    }

    function startPreselection() onlyCouncelors public {
        if (state == State.CREATED) {
            setState(State.NOMINATION, "Council has approved the referendum!");
        } else {
            revert("Consultation is not in the 'Approved' state and can therefore not be started.");
        }
    }

    function startElection() onlyCouncelors public {
        if (state == State.NOMINATION) {
            createElection();
            nominationPoll.disable(msg.sender);
            setState(State.ELECTION, "Council has approved the referendum!");
        } else {
            revert("Consultation is not in the 'Approved' state and can therefore not be started.");
        }
    }

    function inaugurateElected() onlyCouncelors public {
        if (state == State.ELECTION) {
            if (hasMinimumVoterTurnout()) {
                assignToBoard();
                setState(State.INAUGURATION, "Council has approved the referendum!");
            } else if(hasDeadlinePassed()){
                cancel(CancelReason.NOTENOUGHVOTERTURNOUT, "Consultation canceled: Voter turnout has been too small!");
            }
            else{
                revert("Consultation has not reached minimum voter turnout.");
            }
        } else {
            revert("Consultation is not in the 'ELECTION' state.");
        }
    }

    function closeElection() onlyCouncelors public {
        if (state == State.INAUGURATION) {
            setState(State.CLOSED, "Council has approved the referendum!");
        } else {
            revert("Consultation is not in the 'INAUGURATION' state.");
        }
    } 

    function cancel(CancelReason _reason, string memory _description) onlyCouncelors private {
        setState(State.CANCELED, _description);
        cancelationReason = _reason;
    }

    // -----------------------------------
    // ----- Manage Preselection ---------
    // -----------------------------------

    function addCandidate(address _candidate) public onlyIfIsActive {
        // adds a new candidate to the nomination poll

        if (canAddCandidate()) {
            if (!isCandidateAlreadyNominated(_candidate)) {
                AccountManagement.User memory user = accMng.getUser(_candidate);
                nominationPoll.addOption(msg.sender, _candidate, false, user.firstName, user.lastName );
            } else {
                revert("Candidate already nominated!");
            }
        } else {
            revert("No sufficient rights!");
        }
    }

    function acceptCandidature() public onlyIfIsActive(){
        // lets a candidate accept their own candidature

        Poll.Option[] memory candidates = nominationPoll.getOptions();
        for (uint i = 0; i < candidates.length; i++) {
            if (msg.sender == candidates[i].owner) {
                if (!candidates[i].isActive) { 
                    nominationPoll.enableOption(candidates[i].id);
                    return;
                } else {
                    revert("Candidature was already accepted!");
                }
            }
        }
        revert("Candidate is not nominated!");
    }

    function supportCandidate(uint _optionId) onlyDuringPreselection public {
        // members can support candidates so they reach the election phase

        if (canSupport()) {
            nominationPoll.voteForOption(msg.sender, _optionId);
        }
    }

    function removeSupportFromCandidate(uint _optionId) public onlyDuringPreselection {
        // members can withdraw their support from a candidate

        nominationPoll.removeVoteForOption(msg.sender, _optionId);
    }

    // -----------------------------------
    // -------- Manage Voting ------------
    // -----------------------------------

    function voteForCandidate(uint _optionId) public onlyDuringElection {
        if (canVote()) {
            electionPoll.voteForOption(msg.sender, _optionId);
        }
    }

    function removeVote() public onlyDuringElection {
        // members can withdraw their support from a candidate
        nominationPoll.removeVoteForOption(msg.sender);
    }



    // -----------------------------------
    // ------- Manage Results ------------
    // -----------------------------------

    function getNominatedCandidates() public view returns (Poll.Option[] memory) {
        // Gets all candidates that have been nominated

        return nominationPoll.getOptions();
    }

    function getRunningCandidates() public view returns (Poll.Option[] memory) {
        // Gets all candidates that accepted their candidature

        Poll.Option[] memory candidates = nominationPoll.getOptions();
        Poll.Option[] memory acceptedCandidates = new Poll.Option[](candidates.length);

        uint count = 0;
        for (uint i = 0; i < candidates.length; i++) {
            if (candidates[i].isActive) {
                acceptedCandidates[count] = candidates[i];
                count++;
            }
        }

        // Resize the array to remove any unused elements
        assembly {
            mstore(acceptedCandidates, count)
        }

        return acceptedCandidates;
    }

    function getQualifiedCandidates() public view returns (Poll.Option[] memory) {
        // Gets all candidates that accepted their candidature and received more votes than the minimal vote boundary

        Poll.Option[] memory candidates = getRunningCandidates();
        Poll.Option[] memory qualifiedCandidates = new Poll.Option[](candidates.length);

        uint count = 0;
        for (uint i = 0; i < candidates.length; i++) {
            uint voteCount = candidates[i].voterCount;
            if (voteCount > minVotesBoundary) {
                qualifiedCandidates[count] = candidates[i];
                count++;
            }
        }

        // Resize the array to remove any unused elements
        assembly {
            mstore(qualifiedCandidates, count)
        }
        return qualifiedCandidates;
    }

    function getElectableCandidates() public returns (Poll.Option[] memory) {
        // Gets all candidates that have been nominated
        if(electionPoll.isPollActive())
        {
            return electionPoll.getOptions();
        }
        else{
            revert("Election has not started");
        }
    }

    function getWinningCandidates() public returns (Poll.Option[] memory) {
        // Gets the top(maxCandidates)candidates, e.g. if maxCandidates = 3, we get 3 candidates back
        // Issues with candidates that score the same amount of votes: needs to be also implemented -> v0.2

        if(!electionPoll.isPollActive()){
            revert("Election has not started");
        }

        Poll.Option[] memory candidates = getElectableCandidates();
        Poll.Option[] memory topNCandidates = new Poll.Option[](
            candidates.length
        );

        Poll.Option memory candidateWithLowestVotes;
        uint indexOfLowest = 0;
        uint topNCandidatesCount = 0;
        for (uint i = 0; i < candidates.length; i++) {
            uint voteCount = candidates[i].voterCount;

            if (topNCandidatesCount >= maxCandidates) {
                if (voteCount > candidateWithLowestVotes.voterCount) {
                    topNCandidates[indexOfLowest] = candidates[i];
                }
            } else {
                topNCandidates[topNCandidatesCount] = candidates[i];
                topNCandidatesCount++;
            }
        }

        // Resize the array to remove any unused elements
        assembly {
            mstore(topNCandidates, topNCandidatesCount)
        }
        return topNCandidates;
    }

    function assignToBoard() public {   
        if(state == State.INAUGURATION) {
            Poll.Option[] memory winningCandidates = getWinningCandidates();
            address[] memory candidateAddreses = new address[](winningCandidates.length);
            for (uint i = 0; i < winningCandidates.length; i++) {
                candidateAddreses[i] = winningCandidates[i].owner;
            }

            if(role == AccountManagement.Role.LEADER) {
                AccountManagement.LeaderBoard memory l = accMng.createLeaderBoard(candidateAddreses);
                accMng.appointLeaderBoard(msg.sender, l);
            } else if(role == AccountManagement.Role.COUNCILMEMBER) {
                AccountManagement.Council memory c = accMng.createCouncil(candidateAddreses);
                accMng.appointCouncil(msg.sender, c);
            }   
        }     
        else{
            revert("Election is not in state INAUGURATION");
        }
    }

    function getVoterTurnout() public view returns (uint) {
        return nominationPoll.getVoterCount();
    }

    function getMinimalVoterTurnout() public view returns (uint) {
        uint votes = getVoterTurnout();
        return utils.divideAndRoundUp(votes * minVoterTurnoutPercent, 100);
    }

    // -----------------------------------
    // ------- Check Rights --------------
    // -----------------------------------

    function canCreate(address[] memory _creators) public view returns (bool) {
        bool can = true;
        for (uint i = 0; i < _creators.length; i++) {
            if (!accMng.hasLeaderRole(_creators[i])) {
                can = false;
            }
        }
        return can;
    }

    function canApprove(address[] memory _guaranteers) public view returns (bool) {
        bool can = true;
        for (uint i = 0; i < _guaranteers.length; i++) {
            if (!accMng.hasCouncilMemberRole(_guaranteers[i])) {
                can = false;
            }
        }
        return can;
    }

    function canStart(address[] memory _creators) public view returns (bool) {
        bool can = true;
        for (uint i = 0; i < _creators.length; i++) {
            if (!accMng.hasCouncilMemberRole(_creators[i])) {
                can = false;
            }
        }
        return can;
    }

    function canAddCandidate() public view returns (bool) {
        address _userAddress = msg.sender;
        if (accMng.hasMemberRole(_userAddress) || accMng.hasCouncilMemberRole(_userAddress) || accMng.hasLeaderRole(_userAddress)) {
            return true;
        }
        return false;
    }

    function canSupport() public view returns (bool) {
        address _userAddress = msg.sender;
        if (accMng.hasMemberRole(_userAddress) || accMng.hasCouncilMemberRole(_userAddress) || accMng.hasLeaderRole(_userAddress)) {
            return true;
        }
        return false;
    }

    function canVote() public view returns (bool) {
        address _userAddress = msg.sender;
        if (accMng.hasMemberRole(_userAddress) || accMng.hasCouncilMemberRole(_userAddress) || accMng.hasLeaderRole(_userAddress)) {
            return true;
        }
        return false;
    }

    function canCancel() public view returns (bool) {
        address _userAddress = msg.sender;
        if (accMng.hasCouncilMemberRole(_userAddress)) {
            return true;
        }
        return false;
    }

    // -----------------------------------
    // ----- Check Preconditions ---------
    // -----------------------------------

    function hasDeadlinePassed() public view returns (bool) {
        bool deadlineReached = false;
        uint timestamp = block.timestamp;
        uint deadline = nominationPoll.getCreationDate() + (daysOpen * 1 days);

        if (timestamp > deadline) {
            deadlineReached = true;
        }
        return deadlineReached;
    }

    function hasMinimumVoterTurnout() public view returns (bool) { 
        uint votes = getVoterTurnout();
        uint minimalVotesNeeded = getMinimalVoterTurnout();

        return votes > minimalVotesNeeded;
    }

    function isCandidateAlreadyNominated(address _candidate) public view returns (bool) {
        Poll.Option[] memory candidates = nominationPoll.getOptions();
        for (uint i = 0; i < candidates.length; i++) {
            if (_candidate == candidates[i].owner) {
                return true;
            }
        }

        return false;
    }
}
