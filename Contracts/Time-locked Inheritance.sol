// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Time-locked Inheritance Contract
 * @dev Manages automatic asset transfer after specified time periods
 * @author Smart Contract Developer
 */
contract TimeLockedInheritance {
    
    // Struct to represent an inheritance
    struct Inheritance {
        address beneficiary;
        uint256 amount;
        uint256 unlockTime;
        bool claimed;
        string description;
    }
    
    // State variables
    address public owner;
    uint256 public inheritanceCounter;
    mapping(uint256 => Inheritance) public inheritances;
    mapping(address => uint256[]) public beneficiaryInheritances;
    
    // Events
    event InheritanceCreated(
        uint256 indexed inheritanceId,
        address indexed beneficiary,
        uint256 amount,
        uint256 unlockTime,
        string description
    );
    
    event InheritanceClaimed(
        uint256 indexed inheritanceId,
        address indexed beneficiary,
        uint256 amount
    );
    
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validInheritance(uint256 _inheritanceId) {
        require(_inheritanceId < inheritanceCounter, "Invalid inheritance ID");
        require(!inheritances[_inheritanceId].claimed, "Inheritance already claimed");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        inheritanceCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Create a time-locked inheritance
     * @param _beneficiary Address of the beneficiary
     * @param _lockDuration Duration in seconds before inheritance can be claimed
     * @param _description Description of the inheritance
     */
    function createInheritance(
        address _beneficiary,
        uint256 _lockDuration,
        string memory _description
    ) external payable onlyOwner {
        require(_beneficiary != address(0), "Invalid beneficiary address");
        require(msg.value > 0, "Must send some ETH");
        require(_lockDuration > 0, "Lock duration must be greater than 0");
        
        uint256 unlockTime = block.timestamp + _lockDuration;
        
        inheritances[inheritanceCounter] = Inheritance({
            beneficiary: _beneficiary,
            amount: msg.value,
            unlockTime: unlockTime,
            claimed: false,
            description: _description
        });
        
        beneficiaryInheritances[_beneficiary].push(inheritanceCounter);
        
        emit InheritanceCreated(
            inheritanceCounter,
            _beneficiary,
            msg.value,
            unlockTime,
            _description
        );
        
        inheritanceCounter++;
    }
    
    /**
     * @dev Core Function 2: Claim inheritance after unlock time
     * @param _inheritanceId ID of the inheritance to claim
     */
    function claimInheritance(uint256 _inheritanceId)
        external
        validInheritance(_inheritanceId)
    {
        Inheritance storage inheritance = inheritances[_inheritanceId];
        
        require(
            msg.sender == inheritance.beneficiary,
            "Only beneficiary can claim inheritance"
        );
        require(
            block.timestamp >= inheritance.unlockTime,
            "Inheritance is still locked"
        );
        
        inheritance.claimed = true;
        uint256 amount = inheritance.amount;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit InheritanceClaimed(_inheritanceId, msg.sender, amount);
    }
    
    /**
     * @dev Core Function 3: Check inheritance status and get details
     * @param _inheritanceId ID of the inheritance to check
     * @return beneficiary Address of beneficiary
     * @return amount Amount of inheritance
     * @return unlockTime Timestamp when inheritance unlocks
     * @return claimed Whether inheritance has been claimed
     * @return description Description of inheritance
     * @return timeRemaining Seconds remaining until unlock (0 if unlocked)
     */
    function getInheritanceDetails(uint256 _inheritanceId)
        external
        view
        returns (
            address beneficiary,
            uint256 amount,
            uint256 unlockTime,
            bool claimed,
            string memory description,
            uint256 timeRemaining
        )
    {
        require(_inheritanceId < inheritanceCounter, "Invalid inheritance ID");
        
        Inheritance memory inheritance = inheritances[_inheritanceId];
        
        uint256 remaining = 0;
        if (block.timestamp < inheritance.unlockTime) {
            remaining = inheritance.unlockTime - block.timestamp;
        }
        
        return (
            inheritance.beneficiary,
            inheritance.amount,
            inheritance.unlockTime,
            inheritance.claimed,
            inheritance.description,
            remaining
        );
    }
    
    /**
     * @dev Get all inheritance IDs for a beneficiary
     * @param _beneficiary Address of the beneficiary
     * @return Array of inheritance IDs
     */
    function getBeneficiaryInheritances(address _beneficiary)
        external
        view
        returns (uint256[] memory)
    {
        return beneficiaryInheritances[_beneficiary];
    }
    
    /**
     * @dev Check if inheritance is ready to claim
     * @param _inheritanceId ID of the inheritance
     * @return True if ready to claim, false otherwise
     */
    function isReadyToClaim(uint256 _inheritanceId)
        external
        view
        returns (bool)
    {
        require(_inheritanceId < inheritanceCounter, "Invalid inheritance ID");
        
        Inheritance memory inheritance = inheritances[_inheritanceId];
        
        return (
            !inheritance.claimed &&
            block.timestamp >= inheritance.unlockTime
        );
    }
    
    /**
     * @dev Transfer ownership of the contract
     * @param _newOwner Address of the new owner
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != owner, "New owner must be different");
        
        address previousOwner = owner;
        owner = _newOwner;
        
        emit OwnershipTransferred(previousOwner, _newOwner);
    }
    
    /**
     * @dev Get contract balance
     * @return Contract balance in wei
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Get total number of inheritances created
     * @return Total inheritance count
     */
    function getTotalInheritances() external view returns (uint256) {
        return inheritanceCounter;
    }
    
    /**
     * @dev Emergency function to withdraw unclaimed inheritances (only after very long time)
     * @param _inheritanceId ID of the inheritance
     */
    function emergencyWithdraw(uint256 _inheritanceId)
        external
        onlyOwner
        validInheritance(_inheritanceId)
    {
        Inheritance storage inheritance = inheritances[_inheritanceId];
        
        // Only allow emergency withdrawal after 10 years of unlock time
        require(
            block.timestamp >= inheritance.unlockTime + 315360000, // 10 years in seconds
            "Emergency withdrawal only after 10 years of unlock time"
        );
        
        inheritance.claimed = true;
        uint256 amount = inheritance.amount;
        
        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Emergency withdrawal failed");
    }
}
