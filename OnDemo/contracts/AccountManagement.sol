// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

contract AccountManagement {
    
    // A contract to create, active, deactivate, remove users
    // Allows users to take roles
    // Allows

    enum Role { 
        LEADER, 
        COUNCILMEMBER, 
        MEMBER, 
        GUEST 
    }

    struct User {
        address userAddress;
        string firstName;
        string lastName;
        string mailAdress;
        bool isActive;
        RoleMap roleMap;
    }

    // a map to keep track of the different roles an account has
    struct RoleMap {
        bool isLeader;
        bool isCouncilMember;
        bool isMember;
        bool isGuest;
    }

    // the current leadership
    struct LeaderBoard{
        address[] members;
        uint electionTime;
        bool approved;
    }

    // the current council
    struct Council{
        address[] members;
        uint electionTime;
        bool approved;
    }

    uint private activeMemberCount; // keep track of how many users with at least the Role "Member" exist, which are active
    address public owner;

    LeaderBoard private leaderBoard;
    Council private council;
    mapping(address => User) private users; // all users registered  
    mapping(address => bool) private activeMembers; // keep track of all users who have a role different to guest and are active, so we know who can vote on referendums

    constructor(string memory _firstName, string memory _lastName, string memory _mailAdress) {
        owner = msg.sender;
        createAccount(msg.sender, _firstName, _lastName, _mailAdress);      
        assignRole(msg.sender, msg.sender, Role.LEADER);
        assignRole(msg.sender, msg.sender, Role.COUNCILMEMBER);
        assignRole(msg.sender, msg.sender, Role.MEMBER);
        removeRole(msg.sender, msg.sender, Role.GUEST);  
        activateAccount(msg.sender);
    }

    function _testAccountManagement() public{

        address[10] memory testAccounts = [ 
            0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
            0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
            0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
            0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB,
            0x617F2E2fD72FD9D5503197092aC168c91465E7f2,
            0x17F6AD8Ef982297579C203069C1DbfFE4348c372,
            0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678,
            0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7,
            0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C,
            0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c
        ];

        string[10] memory firstNames = ["Rick", "Vanessa", "Alex", "Vici", "Lu", "John", "Sarah", "Samantha", "Peter", "David"];
        string[10] memory lastNames = ["Patel","Kim","Brown","Davis","Martinez","Wilson","Garcia","Jones","Jackson","Smith"];
        string[10] memory mailAdresses = [ "Rick.Patel@por.com","Vanessa.Kim@por.com", "Alex.Brown@por.com","Vici.Davis@por.com","Lu.Martinez@por.com","John.Wilson@por.com","Sarah.Garcia@por.com","Samantha.Jones@por.com","Peter.Jackson@por.com","David.Smith@por.com"];
        for(uint i = 0; i < testAccounts.length; i++)
        {
            address acc = testAccounts[i];
            if(!this.userExists(acc))
            {
                createAccount(acc, firstNames[i], lastNames[i], mailAdresses[i]);
                assignRole(msg.sender, acc, Role.MEMBER);
                removeRole(msg.sender, acc, Role.GUEST);  
                activateAccount(acc);
            }
        }
        
        address[] memory newLeaders = new address[](2);
        newLeaders[0] = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        newLeaders[1] = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;

        LeaderBoard memory l = createLeaderBoard(newLeaders);
        appointLeaderBoard(msg.sender, l);

        
        address[] memory newCouncil = new address[](2);
        newCouncil[0] = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
        newCouncil[1] = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;

        Council memory c = createCouncil(newCouncil);
        appointCouncil(msg.sender, c);
        
    }

    // ------------------------------------
    // ------------ Modifiers -------------
    // ------------------------------------
    
    modifier onlyOwner(address _sender) {
        require(_sender == owner, "Only owner can call this function.");
        _;
    }

    modifier onlyLeader(address _sender) {
        require(_sender == owner || this.hasLeaderRole(_sender), "Only owner can call this function.");
        _;
    }

    modifier onlyIfUserExists(address _address){
        require(users[_address].userAddress != address(0), "Account doesn't exist");
        _;
    }

    modifier onlyIfUserNotExists(address _address){
        require(users[_address].userAddress == address(0), "Account already exists");
        _;
    }


    // ------------------------------------
    // ------ Account management ----------
    // ------------------------------------

    function createAccount(address _address, string memory _firstName, string memory _lastName, string memory _mailAdress) public onlyIfUserNotExists(_address){
        RoleMap memory roleMap = RoleMap(false, false, false, true);
        User memory user = User(_address, _firstName, _lastName, _mailAdress, false, roleMap);
        users[_address] = user;     
    }

    function activateAccount(address _address) public onlyIfUserExists(_address){
        // set an account active. Only active accounts can participate in voting
        if(!activeMembers[_address]){
            User storage user = users[_address];
            user.isActive = true;

            // add account to activeMembers
            RoleMap memory roleMap = user.roleMap;
            if(roleMap.isLeader || roleMap.isCouncilMember || roleMap.isMember)
            {
                activeMembers[_address] = true;
                activeMemberCount++;
            }
        }
    }

    function deactivateAccount(address _address) public onlyIfUserExists(_address){
        // set an account passive. Usually that would happen after the account has not been active for x days
        if(activeMembers[_address]){
            User storage user = users[_address];
            user.isActive = false;

            // remove account from activeMembers
            activeMembers[_address] = false;
            activeMemberCount--;
        }   
        
    }

    function burnAccount(address _address) public onlyIfUserExists(_address){  
        // remove an account from the database
        deactivateAccount(_address);       
        delete users[_address];         
    }

   // ------------------------------------
    // ------ Role management ------------
    // -----------------------------------

    function assignRole(address _sender, address _address, Role _role) private onlyLeader(_sender) onlyIfUserExists(_address){
        // assigns a role to a user
        User storage user = users[_address];
        RoleMap storage roleMap = user.roleMap;

        if(_role == Role.LEADER){            
            roleMap.isLeader = true;
        }
        else if(_role == Role.COUNCILMEMBER){
            roleMap.isCouncilMember = true;       
        }
        else if(_role == Role.MEMBER){
            roleMap.isMember = true;
        }
        else if(_role == Role.GUEST){
            roleMap.isGuest = true;
        }
    }

    function removeRole(address _sender, address _address, Role _role) private onlyLeader(_sender) onlyIfUserExists(_address){
        // removes a role from a user
        User storage user = users[_address];
        RoleMap storage roleMap = user.roleMap;

        if(_role == Role.LEADER){
            roleMap.isLeader = false;
        }
        else if(_role == Role.COUNCILMEMBER){
            roleMap.isCouncilMember = false;     
        }
        else if(_role == Role.MEMBER){
            roleMap.isMember = false;
        }
        else if(_role == Role.GUEST){
            roleMap.isGuest = false;            
        }
    }

    // Setting roles

    function assignLeader(address _sender, address _address) private onlyLeader(_sender) onlyIfUserExists(_address){        
        assignRole(_sender, _address, Role.LEADER);
    }
    
    function assignCouncilMember(address _sender, address _address) private onlyLeader(_sender) onlyIfUserExists(_address){
        assignRole(_sender, _address, Role.COUNCILMEMBER);
    }

    function assignMember(address _sender, address _address) private onlyLeader(_sender) onlyIfUserExists(_address){
        assignRole(_sender, _address, Role.MEMBER);
    }
    
    function assignGuest(address _sender, address _address) private onlyLeader(_sender) onlyIfUserExists(_address){
        assignRole(_sender, _address, Role.GUEST);
    }    

    // Removing roles

    function removeLeader(address _sender, address _address) private onlyLeader(_sender) onlyIfUserExists(_address){
        removeRole(_sender, _address, Role.LEADER);
    }
    
    function removeCouncilMember(address _sender, address _address) private onlyLeader(_sender) onlyIfUserExists(_address){
        removeRole(_sender, _address, Role.COUNCILMEMBER);
    }

    function removeMember(address _sender, address _address) private onlyLeader(_sender) onlyIfUserExists(_address){
        removeRole(_sender, _address, Role.MEMBER);
    }
    
    function removeGuest(address _sender, address _address) private onlyLeader(_sender) onlyIfUserExists(_address){
        removeRole(_sender, _address, Role.GUEST);
    }  


    // -----------------------------------
    // --------- LeaderBoard -------------
    // -----------------------------------
    function createLeaderBoard(address[] memory _members) public view returns(LeaderBoard memory){
        uint electionTime = block.timestamp;
        LeaderBoard memory l = LeaderBoard(_members, electionTime, false);
        return l;
    }

    function appointLeaderBoard(address _sender, LeaderBoard memory _leaderBoard) public {
        address[] memory members = _leaderBoard.members;
        for(uint i = 0; i < members.length; i++)
        {
            assignLeader(_sender, members[i]);
        }
        dismissLeaderBoard(_sender);
        _leaderBoard.approved = true;
        leaderBoard = _leaderBoard;
    }

    function dismissLeaderBoard(address _sender) private{
        address[] memory members = leaderBoard.members;
        for(uint i = 0; i < members.length; i++)
        {
            removeLeader(_sender, members[i]);
        }
    }


    // -----------------------------------
    // ------------ Council --------------
    // -----------------------------------

    function createCouncil(address[] memory _members) public view returns(Council memory){
        uint electionTime = block.timestamp;
        Council memory l = Council(_members, electionTime, false);
        return l;
    }

    function appointCouncil(address _sender, Council memory _council) public {
        address[] memory members = _council.members;
        for(uint i = 0; i < members.length; i++)
        {
            assignCouncilMember(_sender, members[i]);
        }
        dismissCouncil(_sender);
        _council.approved = true;
        council = _council;
    }

    function dismissCouncil(address _sender) private{
        address[] memory members = council.members;
        for(uint i = 0; i < members.length; i++)
        {
            removeCouncilMember(_sender, members[i]);
        }
    }


    // -----------------------------------
    // --------- Role checks -------------
    // -----------------------------------

    function hasRole(address _address, Role _role) private view returns (bool){
        User memory user = users[_address];
        RoleMap memory roleMap = user.roleMap;

        if(_role == Role.LEADER){
            return roleMap.isLeader;
        }
        else if(_role == Role.COUNCILMEMBER){
            return roleMap.isCouncilMember;       
        }
        else if(_role == Role.MEMBER){
            return roleMap.isMember;
        }
        else if(_role == Role.GUEST){
            return roleMap.isGuest;
        }
        return false;
    }

    // -----------------------------------
    // ------- External access -----------
    // -----------------------------------
    
    function hasLeaderRole(address _address) external view returns (bool) {
        return hasRole(_address, Role.LEADER);
    }

    function hasCouncilMemberRole(address _address) external view returns (bool) {
        return hasRole(_address, Role.COUNCILMEMBER);
    }
    
    function hasMemberRole(address _address) external view returns (bool) {
        return hasRole(_address, Role.MEMBER);
    }
    
    function hasGuestRole(address _address) external view returns (bool) {
        return hasRole(_address, Role.GUEST);
    }

    function getUser(address _address) external view returns(User memory){
        User memory u = users[_address];
        if(u.userAddress != address(0))
        {
            return u;
        }
        revert("User not found!");
    }

    function getActiveMemberCount() external view returns (uint) {
        return activeMemberCount;
    }

    function userExists(address _address) external view returns(bool){
        User memory u = users[_address];
        return u.userAddress != address(0);
    }

    function getLeaderBoard() external view returns(LeaderBoard memory){
        return leaderBoard;
    }

    function getCouncil() external view returns(Council memory){
        return council;
    }
}

