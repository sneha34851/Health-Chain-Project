// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title HealthChain - Decentralized Health Records Management
 * @dev Smart contract for secure, decentralized health record storage and access control
 * @author HealthChain Development Team
 */
contract Project {
    
    // Struct to represent a health record
    struct HealthRecord {
        uint256 recordId;
        address patient;
        address doctor;
        string encryptedData; // IPFS hash or encrypted health data
        uint256 timestamp;
        bool isActive;
        string recordType; // e.g., "diagnosis", "prescription", "lab_report"
    }
    
    // Struct to represent user profile
    struct UserProfile {
        string name;
        string email;
        bool isRegistered;
        bool isDoctor;
        uint256[] recordIds;
    }
    
    // State variables
    mapping(address => UserProfile) public users;
    mapping(uint256 => HealthRecord) public healthRecords;
    mapping(address => mapping(address => bool)) public accessPermissions; // patient => doctor => hasAccess
    
    uint256 private recordCounter;
    address public owner;
    
    // Events
    event UserRegistered(address indexed user, string name, bool isDoctor);
    event HealthRecordCreated(uint256 indexed recordId, address indexed patient, address indexed doctor);
    event AccessGranted(address indexed patient, address indexed doctor);
    event AccessRevoked(address indexed patient, address indexed doctor);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can call this function");
        _;
    }
    
    modifier onlyRegistered() {
        require(users[msg.sender].isRegistered, "User must be registered");
        _;
    }
    
    modifier onlyDoctor() {
        require(users[msg.sender].isDoctor, "Only doctors can call this function");
        _;
    }
    
    modifier recordExists(uint256 _recordId) {
        require(_recordId < recordCounter, "Record does not exist");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        recordCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Register a new user (patient or doctor)
     * @param _name User's full name
     * @param _email User's email address
     * @param _isDoctor Boolean flag indicating if user is a doctor
     */
    function registerUser(
        string memory _name,
        string memory _email,
        bool _isDoctor
    ) external {
        require(!users[msg.sender].isRegistered, "User already registered");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_email).length > 0, "Email cannot be empty");
        
        users[msg.sender] = UserProfile({
            name: _name,
            email: _email,
            isRegistered: true,
            isDoctor: _isDoctor,
            recordIds: new uint256[](0)
        });
        
        emit UserRegistered(msg.sender, _name, _isDoctor);
    }
    
    /**
     * @dev Core Function 2: Create a new health record
     * @param _patient Address of the patient
     * @param _encryptedData Encrypted health data or IPFS hash
     * @param _recordType Type of health record (diagnosis, prescription, etc.)
     */
    function createHealthRecord(
        address _patient,
        string memory _encryptedData,
        string memory _recordType
    ) external onlyRegistered onlyDoctor {
        require(users[_patient].isRegistered, "Patient must be registered");
        require(!users[_patient].isDoctor, "Cannot create record for another doctor");
        require(bytes(_encryptedData).length > 0, "Health data cannot be empty");
        require(bytes(_recordType).length > 0, "Record type cannot be empty");
        require(accessPermissions[_patient][msg.sender], "Doctor does not have access permission");
        
        uint256 newRecordId = recordCounter;
        
        healthRecords[newRecordId] = HealthRecord({
            recordId: newRecordId,
            patient: _patient,
            doctor: msg.sender,
            encryptedData: _encryptedData,
            timestamp: block.timestamp,
            isActive: true,
            recordType: _recordType
        });
        
        users[_patient].recordIds.push(newRecordId);
        recordCounter++;
        
        emit HealthRecordCreated(newRecordId, _patient, msg.sender);
    }
    
    /**
     * @dev Core Function 3: Manage access permissions between patients and doctors
     * @param _doctor Address of the doctor
     * @param _grantAccess Boolean flag to grant (true) or revoke (false) access
     */
    function manageAccess(address _doctor, bool _grantAccess) external onlyRegistered {
        require(users[_doctor].isRegistered, "Doctor must be registered");
        require(users[_doctor].isDoctor, "Address must belong to a registered doctor");
        require(!users[msg.sender].isDoctor, "Doctors cannot manage access for themselves");
        
        accessPermissions[msg.sender][_doctor] = _grantAccess;
        
        if (_grantAccess) {
            emit AccessGranted(msg.sender, _doctor);
        } else {
            emit AccessRevoked(msg.sender, _doctor);
        }
    }
    
    // Additional utility functions
    
    /**
     * @dev Get user profile information
     * @param _user Address of the user
     * @return name User's name
     * @return email User's email
     * @return isRegistered Registration status
     * @return isDoctor Doctor status
     */
    function getUserProfile(address _user) external view returns (
        string memory name,
        string memory email,
        bool isRegistered,
        bool isDoctor
    ) {
        UserProfile memory profile = users[_user];
        return (profile.name, profile.email, profile.isRegistered, profile.isDoctor);
    }
    
    /**
     * @dev Get patient's health record IDs
     * @param _patient Address of the patient
     * @return Array of record IDs
     */
    function getPatientRecords(address _patient) external view returns (uint256[] memory) {
        require(
            msg.sender == _patient || 
            (users[msg.sender].isDoctor && accessPermissions[_patient][msg.sender]),
            "Unauthorized access"
        );
        
        return users[_patient].recordIds;
    }
    
    /**
     * @dev Check if doctor has access to patient's records
     * @param _patient Address of the patient
     * @param _doctor Address of the doctor
     * @return Boolean indicating access status
     */
    function hasAccess(address _patient, address _doctor) external view returns (bool) {
        return accessPermissions[_patient][_doctor];
    }
    
    /**
     * @dev Get total number of health records in the system
     * @return Total record count
     */
    function getTotalRecords() external view returns (uint256) {
        return recordCounter;
    }
    
    /**
     * @dev Emergency function to deactivate a health record (only by contract owner)
     * @param _recordId ID of the record to deactivate
     */
    function deactivateRecord(uint256 _recordId) external onlyOwner recordExists(_recordId) {
        healthRecords[_recordId].isActive = false;
    }
}
