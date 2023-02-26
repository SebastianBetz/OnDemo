// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

import "./AccountManagement.sol";

import "./PollTypes/Consultation.sol";
//import "./PollTypes/Election.sol";
//import "./PollTypes/Referendum.sol";

import "./Utils.sol";

contract Test {

    // contracts
    AccountManagement private accountManagement;    
    Utils private utils;
    Consultation private consultation;
    //Election private election;

    // testData
    

    address[10] private testAccounts = [ 
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

    address[2] private leaders = [ 
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db];

    address[3] private councelmembers = [ 
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB,
        0x617F2E2fD72FD9D5503197092aC168c91465E7f2];

    string[10] private firstNames = ["Rick", "Vanessa", "Alex", "Vici", "Lu", "John", "Sarah", "Samantha", "Peter", "David"];
    string[10] private lastNames = ["Patel","Kim","Brown","Davis","Martinez","Wilson","Garcia","Jones","Jackson","Smith"];
    string[10] private mailAdresses = [ "Rick.Patel","Vanessa.Kim", "Alex.Brown","Vici.Davis","Lu.Martinez","John.Wilson","Sarah.Garcia","Samantha.Jones","Peter.Jackson","David.Smith"];
        
    
    
    constructor() {  
        utils = new Utils();
    }

    function createAccountManagement() public returns(address){

        accountManagement = new AccountManagement("Max", "Mustermann", "max.mustermann@gmail.com");

        for(uint i = 0; i < testAccounts.length; i++)
        {
            address acc = testAccounts[i];
            accountManagement.createAccount(acc, firstNames[i], lastNames[i], mailAdresses[i]);
            accountManagement.assignRole(acc, AccountManagement.Role.MEMBER);
            accountManagement.removeRole(acc, AccountManagement.Role.GUEST);  
            accountManagement.makeAccountActive(acc);
        }

        for(uint i = 0; i < leaders.length; i++)
        {
            address acc = leaders[i];
            accountManagement.assignRole(acc, AccountManagement.Role.LEADER);
        }

        for(uint i = 0; i < councelmembers.length; i++)
        {
            address acc = councelmembers[i];
            accountManagement.assignRole(acc, AccountManagement.Role.COUNCILMEMBER);
        }
        return address(accountManagement);
    }

    function createConsultation() public returns(address){
        
        address[] memory leads = new address[](1);
        leads[0] = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;

        string memory title = "Is this a great party?";
        string memory description = "We have to decide here and now if this is a great party, o-o-eo";

        consultation = new Consultation(accountManagement, leads, title, description, "Yes", "It's the best I've seen!", "No", "I'm a party pooper!");     
        //consultation.approve();
        //consultation.start();
        //consultation.finish();
        return address(consultation);
    }   
    
}