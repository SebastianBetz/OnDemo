// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract AccountManagement {
    
    enum Role { 
        LEADER,
        COUNCILMEMBER,
        MEMBER,
        GUEST
    }

    struct User {
        address userAddress;
        string firstName;
        string secondName;
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

    address public owner;
    mapping(address => User) private users; // all users registered
    mapping(address => bool) private activeMembers; // keep track of all users who have a role different to guest and are active, so we know who can vote on referendums

    constructor(string memory _firstName, string memory _secondName, string memory _mailAdress) {
        owner = msg.sender;
        createAccount(msg.sender, _firstName, _secondName, _mailAdress);      
        assignRole(msg.sender, Role.LEADER);
        removeRole(msg.sender, Role.GUEST);  
    }

    // Modifiers
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    modifier onlyLeader() {
        require(msg.sender == owner || hasLeaderRole(msg.sender), "Only owner can call this function.");
        _;
    }

    modifier userExists(address _address){
        require(users[_address].userAddress != address(0), "Account doesn't exist");
        _;
    }

    modifier userNotExists(address _address){
        require(users[_address].userAddress == address(0), "Account already exists");
        _;
    }

    // Account Management

    function createAccount(address _address, string memory _firstName, string memory _secondName, string memory _mailAdress) public userNotExists(_address){
        RoleMap memory roleMap = RoleMap(false, false, false, true);
        User memory user = User(_address, _firstName, _secondName, _mailAdress, true, roleMap);
        users[_address] = user;     
    }

    function makeAccountActive(address _address) public userExists(_address){
        User storage user = users[_address];
        user.isActive = true;

        // add account to activeMembers
        RoleMap memory roleMap = user.roleMap;
        if(roleMap.isLeader || roleMap.isCouncilMember || roleMap.isMember)
        {
            activeMembers[_address] = true;
        }
    }

    function makeAccountPassive(address _address) public userExists(_address){
        User storage user = users[_address];
        user.isActive = false;

        // remove account from activeMembers
        activeMembers[_address] = false;
    }

    function burnAccount(address _address) public userExists(_address){
        delete users[_address];        
    }

    // Role management

    function assignRole(address _address, Role _role) public onlyLeader userExists(_address){
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

    function removeRole(address _address, Role _role) public onlyLeader userExists(_address){
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

        if(!roleMap.isLeader && !roleMap.isCouncilMember && !roleMap.isMember)
        {
            // remove account from activeMembers
            activeMembers[_address] = false;
        }
    }

    // Setting roles

    function assignLeader(address _address) private onlyLeader userExists(_address){
        assignRole(_address, Role.LEADER);
    }
    
    function assignCouncilMember(address _address) private onlyLeader userExists(_address){
        assignRole(_address, Role.COUNCILMEMBER);
    }

    function assignMember(address _address) private onlyLeader userExists(_address){
        assignRole(_address, Role.MEMBER);
    }
    
    function assignGuest(address _address) private onlyLeader userExists(_address){
        assignRole(_address, Role.GUEST);
    }    

    // Removing roles

    function removeLeader(address _address) private onlyLeader userExists(_address){
        removeRole(_address, Role.LEADER);
    }
    
    function removeCouncilMember(address _address) private onlyLeader userExists(_address){
        removeRole(_address, Role.COUNCILMEMBER);
    }

    function removeMember(address _address) private onlyLeader userExists(_address){
        removeRole(_address, Role.MEMBER);
    }
    
    function removeGuest(address _address) private onlyLeader userExists(_address){
        removeRole(_address, Role.GUEST);
    }  

    // Check if user has role

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
    
    function hasLeaderRole(address _address) public view returns (bool) {
        return hasRole(_address, Role.LEADER);
    }

    function hasCouncilMemberRole(address _address) public view returns (bool) {
        return hasRole(_address, Role.COUNCILMEMBER);
    }
    
    function hasMemberRole(address _address) public view returns (bool) {
        return hasRole(_address, Role.MEMBER);
    }
    
    function hasGuestRole(address _address) public view returns (bool) {
        return hasRole(_address, Role.GUEST);
    }

    // Check if User has Rights

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

