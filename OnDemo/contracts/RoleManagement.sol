pragma solidity ^0.8.0;

contract RoleManagement {
    address public owner;
    mapping(address => bool) public isLeader;
    mapping(address => bool) public isCouncilMember;
    mapping(address => bool) public isMember;
    mapping(address => bool) public isGuest;

        enum Roles { 
            LEADER,
            COUNCILMEMBER,
            MEMBER,
            GUEST
        } 
    
    constructor() {
        owner = msg.sender;
        isLeader[owner] = true;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    modifier onlyLeader() {
        require(msg.sender == owner || hasLeaderRole(msg.sender), "Only owner can call this function.");
        _;
    }

    function assignRole(Roles _role, address _user) private onlyLeader {
        
        isLeader[_user] = false;
        isCouncilMember[_user] = false;
        isMember[_user] = false;
        isGuest[_user] = false;

        if(_role == Roles.LEADER) {
            isLeader[_user] = true;
        } else if(_role == Roles.COUNCILMEMBER) {
            isCouncilMember[_user] = true;
        } else if(_role == Roles.MEMBER) {
            isMember[_user] = true;
        } else {
            isGuest[_user] = true;
        }
    }
    
    function assignLeader(address _user) public onlyLeader {
        assignRole(Roles.LEADER, _user);
    }
    
    function assignCouncilMember(address _user) public onlyLeader {
        assignRole(Roles.COUNCILMEMBER, _user);
    }

    function assignMember(address _user) public onlyLeader {
        assignRole(Roles.MEMBER, _user);
    }
    
    function assignGuest(address _user) public onlyLeader {
        assignRole(Roles.GUEST, _user);
    }
    
    function removeRole(address _user) public onlyLeader {
        assignRole(Roles.GUEST, _user);
    }
    
    function hasLeaderRole(address _user) public view returns (bool) {
        return isLeader[_user];
    }

    function hasCouncilMemberRole(address _user) public view returns (bool) {
        return isCouncilMember[_user];
    }
    
    function hasMemberRole(address _user) public view returns (bool) {
        return isMember[_user];
    }
    
    function hasGuestRole(address _user) public view returns (bool) {
        return isGuest[_user];
    }
}