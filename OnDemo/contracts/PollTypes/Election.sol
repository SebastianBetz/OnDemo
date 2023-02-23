// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

import "../AccountManagement.sol";
import "../Poll.sol";
import "../Utils.sol";

contract Election {
    
    enum CancelationReason { DRAW, NOTENOUGHVOTERTURNOUT, CANCELEDBYCOUNCIL }
    enum State { CREATED, APPROVED, PRESELECTION, ELECTION, CLOSED, CANCELED }
    enum Result { AYES, NOES, DRAW }

    event StateChanged(
        address indexed _by,
        State oldState,
        State newState,
        string description
    );

    address[] public owners;
    address[] public guaranteers;
    uint256 public daysOpen = 28;
    uint256 minVoterTurnoutPercent = 50;
    uint256 minVotesBoundary = 1;
    uint256 maxCandidates;
    AccountManagement.Role role;

    State public state;
    CancelationReason public cancelationReason;

    AccountManagement private accMng;
    Poll private preSelectionPoll;
    Poll private electionPoll;
    Utils private utils;

    /*
    constructor(AccountManagement _accMngAddress, address[] memory _owners, string memory _title, string memory _description, AccountManagement.Role _role, uint _maxCandidates) {        
        accMng = _accMngAddress;
        create(_owners, _title, _description, _role, _maxCandidates);  
    }
*/
    constructor() {}

    function testElection() public {
        address leader = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        address[] memory council = new address[](1);
        council[0] = leader;

        accMng = AccountManagement(0x9279F54dAc3570d115AdB6083f85D05a4e6F41Ad);
        string memory _title = "TestElection";
        string memory _description = "TestElectionDEscription";
        AccountManagement.Role _role = AccountManagement.Role.LEADER;
        uint256 _maxCandidates = 2;

        createPreselection( council, _title, _description, _role, _maxCandidates );

        approveElection(council);
        startPreselection(council);
        addCandidate(leader);
        acceptCandidature();
    }

    modifier isActive() {
        // checks if the election is in an active state

        bool active = false;
        if ( state == State.CREATED || state == State.APPROVED || state == State.PRESELECTION || state == State.ELECTION ) {
            if (!hasDeadlinePassed()) {
                active = true;
            }
        }
        require(active, "The poll must be in an active state!");
        _;
    }

    function getPreselectionPoll() public returns (Poll) {
        // checks if the election is in an active state
        return preSelectionPoll;
    }

    function getElectionPoll() public returns (Poll) {
        return electionPoll;
    }

    function setState(State _state, string memory _description) private {
        emit StateChanged(msg.sender, state, _state, _description);
        state = _state;
    }

    // -----------------------------------
    // ------- Manage Life Cycle ---------
    // -----------------------------------

    function createPreselection( address[] memory _owners, string memory _title, string memory _description, AccountManagement.Role _role, uint256 _maxCandidates ) private {
        if (canCreate(_owners)) {
            utils = new Utils();
            preSelectionPoll = new Poll(_owners, _title, _description);
            owners = _owners;
            role = _role;
            maxCandidates = _maxCandidates;
            setState(State.CREATED, "Consultation created!");
        } else {
            revert("One or more users can't create a consultation!");
        }
    }

    function createElection() private {
        string memory electionTitle = preSelectionPoll.getTitle();
        string memory description = preSelectionPoll.getDescription();
        electionPoll = new Poll(owners, electionTitle, description);

        Poll.Option[] memory preWinners = getQualifiedCandidates();

        for (uint256 i = 0; i < preWinners.length; i++) {
            Poll.Option memory candidate = preWinners[i];
            address id = candidate.owner;
            string memory fName = candidate.title;
            string memory lName = candidate.description;

            electionPoll.addOption(id, false, fName, lName);
        }
    }

    function approveElection(address[] memory _guaranteers) public {
        if (state == State.CREATED) {
            if (canApprove(_guaranteers)) {
                setState(
                    State.APPROVED,
                    "Council has approved the referendum!"
                );
            } else {
                revert(
                    "Only Members of the council can approve consultations."
                );
            }
        } else {
            revert(
                "Consultation is not in the 'Created' state and can therefore not be approved."
            );
        }
    }

    function startPreselection(address[] memory _leaders) public {
        if (state == State.APPROVED) {
            if (canStart(_leaders)) {
                setState(
                    State.PRESELECTION,
                    "Council has approved the referendum!"
                );
            } else {
                revert(
                    "Only Members of the council can approve consultations."
                );
            }
        } else {
            revert(
                "Consultation is not in the 'Approved' state and can therefore not be started."
            );
        }
    }

    function startElection(address[] memory _leaders) public {
        if (state == State.PRESELECTION) {
            if (canStart(_leaders)) {
                createElection();
                setState(
                    State.ELECTION,
                    "Council has approved the referendum!"
                );
            } else {
                revert(
                    "Only Members of the council can approve consultations."
                );
            }
        } else {
            revert(
                "Consultation is not in the 'Approved' state and can therefore not be started."
            );
        }
    }

    function finishElection() private {
        if (state == State.ELECTION) {
            if (hasMinimumVoterTurnout()) {} else {
                cancel(
                    CancelationReason.NOTENOUGHVOTERTURNOUT,
                    "Consultation canceled: Voter turnout has been too small!"
                );
            }
        } else {
            revert(
                "Consultation is not in the 'RUNNING' state and can therefore not be finished."
            );
        }
    }

    function cancelElectionByCouncil() public {
        if (canCancel()) {
            cancel(
                CancelationReason.CANCELEDBYCOUNCIL,
                "Consultation canceled by Council!"
            );
        } else {
            revert("Only Members of the council can cancel consultations.");
        }
    }

    function cancel(CancelationReason _reason, string memory _description) private {
        setState(State.CANCELED, _description);
        cancelationReason = _reason;
    }

    // -----------------------------------
    // ----- Manage Preselection ---------
    // -----------------------------------

    function addCandidate(address _candidate) public isActive {
        if (state == State.PRESELECTION) {
            if (canAddCandidate()) {
                if (!isCandidateAlreadyNominated(_candidate)) {
                    AccountManagement.User memory user = accMng.getUser( _candidate );
                    preSelectionPoll.addOption( _candidate, false, user.firstName, user.lastName );
                } else {
                    revert("Candidate already nominated!");
                }
            } else {
                revert("No sufficient rights!");
            }
        } else {
            revert("Election is not in state PreSelection!");
        }
    }

    function acceptCandidature() public isActive {
        if (state == State.PRESELECTION) {
            Poll.Option[] memory candidates = preSelectionPoll.getOptions();
            for (uint256 i = 0; i < candidates.length; i++) {
                if (msg.sender == candidates[i].owner) {
                    if (!candidates[i].isActive) { 
                        preSelectionPoll.enableOption(candidates[i].id);
                        return;
                    } else {
                        revert("Candidature was already accepted!");
                    }
                }
            }
            revert("Candidate is not nominated!");
        } else {
            revert("Election is not in state PreSelection!");
        }
    }

    function supportCandidate(uint256 _optionId) public {
        if (canSupport()) {
            preSelectionPoll.voteForOption(_optionId);
        }
    }

    function removeSupportFromCandidate() public isActive {
        preSelectionPoll.removeVoteForOption();
    }

    // -----------------------------------
    // ------- Manage Results ------------
    // -----------------------------------

    function getNominatedCandidates() public view returns (Poll.Option[] memory) {
        return preSelectionPoll.getOptions();
    }

    function getRunningCandidates() public view returns (Poll.Option[] memory) {
        // Gets all candidates that accepted their candidature

        Poll.Option[] memory candidates = preSelectionPoll.getOptions();
        Poll.Option[] memory acceptedCandidates = new Poll.Option[](candidates.length);

        uint256 count = 0;
        for (uint256 i = 0; i < candidates.length; i++) {
            if (preSelectionPoll.isOptionActive(candidates[i])) {
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

        uint256 count = 0;
        for (uint256 i = 0; i < candidates.length; i++) {
            uint256 voteCount = candidates[i].voterCount;
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

    function getWinningCandidates() public view returns (Poll.Option[] memory) {
        // Gets the top(maxCandidates)candidates, e.g. if maxCandidates = 3, we get 3 candidates back
        // Issues with candidates that score the same amount of votes: needs to be also implemented -> v0.2

        Poll.Option[] memory candidates = getRunningCandidates();
        Poll.Option[] memory topNCandidates = new Poll.Option[](
            candidates.length
        );

        Poll.Option memory candidateWithLowestVotes;
        uint256 indexOfLowest = 0;
        uint256 topNCandidatesCount = 0;
        for (uint256 i = 0; i < candidates.length; i++) {
            uint256 voteCount = candidates[i].voterCount;

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

    function getResult() public view returns (Result) {
        Result res = Result.AYES;
        return res;
    }

    function getVoterTurnout() public view returns (uint256) {
        return preSelectionPoll.getVoterCount();
    }

    function getMinimalVoterTurnout() public view returns (uint256) {
        uint256 votes = getVoterTurnout();
        return utils.divideAndRoundUp(votes * minVoterTurnoutPercent, 100);
    }

    // -----------------------------------
    // ------- Check Rights --------------
    // -----------------------------------

    function canCreate(address[] memory _creators) public view returns (bool) {
        bool can = true;
        for (uint256 i = 0; i < _creators.length; i++) {
            if (!accMng.hasLeaderRole(_creators[i])) {
                can = false;
            }
        }
        return can;
    }

    function canApprove(address[] memory _guaranteers) public view returns (bool) {
        bool can = true;
        for (uint256 i = 0; i < _guaranteers.length; i++) {
            if (!accMng.hasCouncilMemberRole(_guaranteers[i])) {
                can = false;
            }
        }
        return can;
    }

    function canStart(address[] memory _creators) public view returns (bool) {
        bool can = true;
        for (uint256 i = 0; i < _creators.length; i++) {
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
        if (accMng.hasRightToVote(_userAddress)) {
            return true;
        }
        return false;
    }

    function canVote() public view returns (bool) {
        address _userAddress = msg.sender;
        if (accMng.hasRightToVote(_userAddress)) {
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
        uint256 timestamp = block.timestamp;
        uint256 deadline = preSelectionPoll.getCreationDate() + (daysOpen * 1 days);

        if (timestamp > deadline) {
            deadlineReached = true;
        }
        return deadlineReached;
    }

    function hasMinimumVoterTurnout() public view returns (bool) { 
        uint256 votes = getVoterTurnout();
        uint256 minimalVotesNeeded = getMinimalVoterTurnout();

        return votes > minimalVotesNeeded;
    }

    function isCandidateAlreadyNominated(address _candidate) public view returns (bool) {
        Poll.Option[] memory candidates = preSelectionPoll.getOptions();
        for (uint256 i = 0; i < candidates.length; i++) {
            if (_candidate == candidates[i].owner) {
                return true;
            }
        }

        return false;
    }
}
