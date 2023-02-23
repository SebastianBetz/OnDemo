// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

contract AccountManagement {
    
    // A contract to create, active, deactivate, remove users
    // Allows users to take roles
    // Allows

    enum Role { LEADER, COUNCILMEMBER, MEMBER, GUEST }

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
    struct LeadershipBoard{
        uint electionTime;
        bool approved;
        address[] members;
    }

    // the current council
    struct Council{
        uint electionTime;
        bool approved;
        address[] members;
    }

    uint private activeMemberCount; // keep track of how many users with at least the Role "Member" exist, which are active
    address public owner;
    mapping(address => User) private users; // all users registered  
    mapping(address => bool) private activeMembers; // keep track of all users who have a role different to guest and are active, so we know who can vote on referendums

    constructor(string memory _firstName, string memory _lastName, string memory _mailAdress) {
        owner = msg.sender;
        createAccount(msg.sender, _firstName, _lastName, _mailAdress);      
        assignRole(msg.sender, Role.LEADER);
        removeRole(msg.sender, Role.GUEST);  
        activateAccount(msg.sender);
    }

    // ------------------------------------
    // ------------ Modifiers -------------
    // ------------------------------------
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    modifier onlyLeader() {
        require(msg.sender == owner || this.hasLeaderRole(msg.sender), "Only owner can call this function.");
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

    function assignRole(address _address, Role _role) public onlyLeader onlyIfUserExists(_address){
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

    function removeRole(address _address, Role _role) public onlyLeader onlyIfUserExists(_address){
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

    function assignLeader(address _address) private onlyLeader onlyIfUserExists(_address){        
        assignRole(_address, Role.LEADER);
    }
    
    function assignCouncilMember(address _address) private onlyLeader onlyIfUserExists(_address){
        assignRole(_address, Role.COUNCILMEMBER);
    }

    function assignMember(address _address) private onlyLeader onlyIfUserExists(_address){
        assignRole(_address, Role.MEMBER);
    }
    
    function assignGuest(address _address) private onlyLeader onlyIfUserExists(_address){
        assignRole(_address, Role.GUEST);
    }    

    // Removing roles

    function removeLeader(address _address) private onlyLeader onlyIfUserExists(_address){
        removeRole(_address, Role.LEADER);
    }
    
    function removeCouncilMember(address _address) private onlyLeader onlyIfUserExists(_address){
        removeRole(_address, Role.COUNCILMEMBER);
    }

    function removeMember(address _address) private onlyLeader onlyIfUserExists(_address){
        removeRole(_address, Role.MEMBER);
    }
    
    function removeGuest(address _address) private onlyLeader onlyIfUserExists(_address){
        removeRole(_address, Role.GUEST);
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

    function testAccountManagement() public{

        address[10] memory testAccounts = [ 
            0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
            0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
            0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB,
            0x617F2E2fD72FD9D5503197092aC168c91465E7f2,
            0x17F6AD8Ef982297579C203069C1DbfFE4348c372,
            0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678,
            0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7,
            0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C,
            0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c,
            0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C];

        string[10] memory firstNames = ["Rick", "Vanessa", "Alex", "Vici", "Lu", "John", "Sarah", "Samantha", "Peter", "David"];
        string[10] memory lastNames = ["Patel","Kim","Brown","Davis","Martinez","Wilson","Garcia","Jones","Jackson","Smith"];
        string[10] memory mailAdresses = [ "Rick.Patel@por.com","Vanessa.Kim@por.com", "Alex.Brown@por.com","Vici.Davis@por.com","Lu.Martinez@por.com","John.Wilson@por.com","Sarah.Garcia@por.com","Samantha.Jones@por.com","Peter.Jackson@por.com","David.Smith@por.com"];
        for(uint i = 0; i < testAccounts.length; i++)
        {
            address acc = testAccounts[i];
            if(!this.userExists(acc))
            {
                createAccount(acc, firstNames[i], lastNames[i], mailAdresses[i]);
                assignRole(acc, Role.MEMBER);
                removeRole(acc, Role.GUEST);  

                if(i < 2){
                    assignRole(acc, Role.LEADER);
                }
                else if(i < 4){
                    assignRole(acc, Role.COUNCILMEMBER);
                }

                activateAccount(acc);
            }
        }
    }

}

