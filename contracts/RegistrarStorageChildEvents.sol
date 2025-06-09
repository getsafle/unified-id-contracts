//child contract
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./RegistrarStorageUtil.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract RegistrarStorageChildEvents is UUPSUpgradeable, OwnableUpgradeable {
    struct UserData {
        address primary;
        mapping(address => bool) isSecondary;
        address[] secondaries;
        bool exists;
    }
    struct Registrar {
        bool isRegisteredRegistrar;
        string registrarName;
        address registrarAddress;
    }

    uint256 public maxNameUpdates;
    bool public isPaused;
    uint256 public totalUnifiedIdRegistered;
    RegistrarStorageUtil public util;
    mapping(address => bool) public authorizedRelayers;
    mapping(address => bool) public isRegisteredRegistrar;
    mapping(address => string) public registrarNames;
    mapping(string => address) public registrarNameToAddress;
    mapping(address => uint8) public totalRegistrarUpdates;
    address[] public registrarAddresses;
    mapping(string => UserData) private userAddresses;
    mapping(string => bool) public unavailableUnifiedIds;
    mapping(string => bool) public registeredUnifiedIds;
    uint256 public totalRegisteredUnifiedIds;

    mapping(string => address) public resolveAddressFromUnifiedId;
    mapping(address => bool) public isAddressTaken;
    mapping(address => string) public resolveUnifiedIdFromAddress;

    // === ADMIN CONFIGURATION VARIABLES ===
    uint256 public maxSecondaryAddresses;
    bool public publicRegistrarRegistration;
    bool public emergencyMode;
    mapping(address => bool) public adminUsers;
    uint256 public maxUnifiedIdLength;
    uint256 public minUnifiedIdLength;

    // === ADMIN EVENTS ===
    event MaxSecondaryAddressesUpdated(uint256 oldMax, uint256 newMax);
    event PublicRegistrarRegistrationToggled(bool enabled);
    event EmergencyModeToggled(bool enabled);
    event AdminUserUpdated(address user, bool isAdmin);
    event MaxNameUpdatesChanged(uint256 oldMax, uint256 newMax);
    event UnifiedIdLengthLimitsUpdated(uint256 minLength, uint256 maxLength);

    event SecondaryAddressAdded(string unifiedId, address secondary);
    event SecondaryAddressRemoved(string unifiedId, address secondary);
    event RegistrarRegistered(address registrar, string registrarName);
    event RegistrarUpdated(address registrar, string oldName, string newName);
    event RegistrationPaused(address by);
    event RegistrationUnpaused(address by);
    event UnifiedIDRegistered(string indexed unifiedId, address indexed primary, uint256 timestamp);
    event UnifiedIDUpdated(string indexed unifiedId, address indexed oldPrimary, address indexed newPrimary);
    event UnifiedIDChanged(string indexed oldUnifiedId, string indexed newUnifiedId, address indexed primary, uint256 timestamp);
    event RegisterUnifiedIdInitiated(
        string unifiedId,
        address primaryAddress,
        bytes masterSignature,
        bytes primarySignature,
        bytes options
    );
    event UpdateUnifiedIdInitiated(string oldUnifiedId, string newUnifiedId, bytes signature, bytes options);
    event UpdateUnifiedIdPrimaryAddressInitiated(
        string unifiedId,
        address newPrimaryAddress,
        bytes currentPrimarySignature,
        bytes newPrimarySignature,
        bytes options
    );
    event AddSecondaryAddressInitiated(
        string unifiedId,
        address secondaryAddress,
        bytes primarySignature,
        bytes secondarySignature,
        bytes options
    );
    event RemoveSecondaryAddressInitiated(string unifiedId, address secondaryAddress, bytes signature, bytes options);

    modifier unifiedIdExists(string calldata _unifiedId) {
        require(userAddresses[_unifiedId].exists, "UnifiedID does not exist");
        _;
    }
    modifier whenNotPaused() {
        require(!isPaused, "Contract is Paused");
        _;
    }
    modifier unifiedIdDoesNotExist(string calldata _unifiedId) {
        require(!userAddresses[_unifiedId].exists, "UnifiedID already exists");
        require(!unavailableUnifiedIds[_unifiedId], "UnifiedID not available");
        _;
    }
    modifier validateRegistrarName(string memory _registrarName) {
        bytes memory regNameBytes = bytes(_registrarName);
        require(registrarNameToAddress[string(regNameBytes)] == address(0x0), "Registrar name is already taken.");
        require(
            resolveAddressFromUnifiedId[_registrarName] == address(0x0),
            "This Registrar name is already registered as a UnifiedID."
        );
        _;
    }
    modifier onlyRegistrar() {
        require(isRegisteredRegistrar[msg.sender], "Caller not a registrar");
        _;
    }
    modifier onlyAuthorizedRelayer() {
        require(authorizedRelayers[msg.sender], "Caller not authorized relayer");
        _;
    }

    // === ADMIN MODIFIERS ===
    modifier onlyAdmin() {
        require(adminUsers[msg.sender] || msg.sender == owner(), "Caller not admin or owner");
        _;
    }
    
    modifier notInEmergencyMode() {
        require(!emergencyMode, "Contract in emergency mode");
        _;
    }
    
    modifier publicRegistrarAllowed() {
        require(publicRegistrarRegistration || msg.sender == owner() || adminUsers[msg.sender], "Public registrar registration disabled");
        _;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function initialize(address _RegistrarStorageUtil) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        maxNameUpdates = 3;
        util = RegistrarStorageUtil(_RegistrarStorageUtil);
        
        // === ADMIN DEFAULTS ===
        maxSecondaryAddresses = 10;
        publicRegistrarRegistration = false;
        emergencyMode = false;
        adminUsers[msg.sender] = true;
        maxUnifiedIdLength = 16;
        minUnifiedIdLength = 4;
    }

    function setUtilImplementation(address _RegistrarStorageUtil) external onlyOwner {
        util = RegistrarStorageUtil(_RegistrarStorageUtil);
    }

    function setAuthorizedRelayer(address _relayer, bool authorized) external onlyOwner {
        authorizedRelayers[_relayer] = authorized;
    }

    function registerRegistrar(
        string calldata _registrarName,
        address _registrarAddress
    ) external payable whenNotPaused validateRegistrarName(_registrarName) publicRegistrarAllowed notInEmergencyMode returns (bool) {
        require(!isAddressTaken[_registrarAddress], "This address is already registered.");
        registrarNameToAddress[_registrarName] = _registrarAddress;
        registrarNames[_registrarAddress] = _registrarName;
        isRegisteredRegistrar[_registrarAddress] = true;
        isAddressTaken[_registrarAddress] = true;
        registrarAddresses.push(_registrarAddress);
        emit RegistrarRegistered(_registrarAddress, _registrarName);
        return true;
    }

    function updateRegistrar(
        address _registrar,
        string calldata _newRegistrarName
    ) external whenNotPaused validateRegistrarName(_newRegistrarName) onlyOwner returns (bool) {
        require(isAddressTaken[_registrar], "Registrar should register first.");
        require(totalRegistrarUpdates[_registrar] + 1 <= maxNameUpdates, "Maximum update count reached.");
        string memory oldName = registrarNames[_registrar];
        registrarNameToAddress[oldName] = address(0x0);
        registrarNames[_registrar] = _newRegistrarName;
        registrarNameToAddress[_newRegistrarName] = _registrar;
        totalRegistrarUpdates[_registrar]++;
        emit RegistrarUpdated(_registrar, oldName, _newRegistrarName);
        return true;
    }

    function pauseRegistration() external onlyOwner {
        isPaused = true;
        emit RegistrationPaused(msg.sender);
    }

    function unpauseRegistration() external onlyOwner {
        isPaused = false;
        emit RegistrationUnpaused(msg.sender);
    }

    function initiateRegisterUnifiedId(
        string calldata _unifiedId,
        address _primaryAddress,
        bytes calldata _masterSignature,
        bytes calldata _primarySignature,
        bytes calldata _options
    ) external payable whenNotPaused onlyRegistrar returns (bool) {
        require(util.isSafleIdValid(_unifiedId), "Invalid UnifiedId format");
        require(!userAddresses[_unifiedId].exists, "UnifiedID already exists");
        require(!unavailableUnifiedIds[_unifiedId], "UnifiedID not available");
        require(registrarNameToAddress[_unifiedId] == address(0x0), "This UnifiedId is taken by a Registrar.");
        require(resolveAddressFromUnifiedId[_unifiedId] == address(0x0), "This UnifiedId is already registered.");
        emit RegisterUnifiedIdInitiated(_unifiedId, _primaryAddress, _masterSignature, _primarySignature, _options);
        return true;
    }

    function completeRegisterUnifiedId(
        string calldata _unifiedId,
        address _primaryAddress
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        UserData storage userData = userAddresses[_unifiedId];
        userData.primary = _primaryAddress;
        userData.exists = true;
        resolveAddressFromUnifiedId[_unifiedId] = _primaryAddress;
        resolveUnifiedIdFromAddress[_primaryAddress] = _unifiedId;
        registeredUnifiedIds[_unifiedId] = true;
        totalRegisteredUnifiedIds++;
        unavailableUnifiedIds[_unifiedId] = true;
        totalUnifiedIdRegistered++;
        emit UnifiedIDRegistered(_unifiedId, _primaryAddress, block.timestamp);
        return true;
    }

    function initiateUpdateUnifiedId(
        string calldata _oldUnifiedId,
        string calldata _newUnifiedId,
        bytes calldata _signature,
        bytes calldata _options
    )
        external
        payable
        whenNotPaused
        unifiedIdExists(_oldUnifiedId)
        unifiedIdDoesNotExist(_newUnifiedId)
        onlyRegistrar
        returns (bool)
    {
        require(util.isSafleIdValid(_newUnifiedId), "Invalid new UnifiedId format");
        emit UpdateUnifiedIdInitiated(_oldUnifiedId, _newUnifiedId, _signature, _options);
        return true;
    }

    function completeUpdateUnifiedId(
        string memory _oldUnifiedId,
        string memory _newUnifiedId
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        require(registeredUnifiedIds[_oldUnifiedId], "Old UnifiedID not found");
        require(!registeredUnifiedIds[_newUnifiedId], "New UnifiedID already exists");
        
        UserData storage userData = userAddresses[_oldUnifiedId];
        address primaryAddress = userData.primary;
        
        // Update address mappings
        resolveAddressFromUnifiedId[_newUnifiedId] = primaryAddress;
        delete resolveAddressFromUnifiedId[_oldUnifiedId];
        resolveUnifiedIdFromAddress[primaryAddress] = _newUnifiedId;

        // Copy user data to new unified ID
        UserData storage newUserData = userAddresses[_newUnifiedId];
        newUserData.primary = primaryAddress;
        newUserData.exists = true;

        // Copy secondary addresses
        for (uint i = 0; i < userData.secondaries.length; i++) {
            address secondaryAddr = userData.secondaries[i];
            newUserData.isSecondary[secondaryAddr] = true;
            newUserData.secondaries.push(secondaryAddr);
        }

        delete registeredUnifiedIds[_oldUnifiedId];
        registeredUnifiedIds[_newUnifiedId] = true;
        
        // Mark as unavailable
        unavailableUnifiedIds[_oldUnifiedId] = true;
        unavailableUnifiedIds[_newUnifiedId] = true;
        
        // Clean up old user data
        delete userAddresses[_oldUnifiedId];
        
        emit UnifiedIDChanged(_oldUnifiedId, _newUnifiedId, primaryAddress, block.timestamp);
        return true;
    }

    function initiatePrimaryAddressChange(
        string calldata _unifiedId,
        address _newPrimaryAddress,
        bytes calldata currentPrimarySignature,
        bytes calldata newPrimarySignature,
        bytes calldata _options
    ) external payable whenNotPaused unifiedIdExists(_unifiedId) onlyRegistrar returns (bool) {
        emit UpdateUnifiedIdPrimaryAddressInitiated(
            _unifiedId,
            _newPrimaryAddress,
            currentPrimarySignature,
            newPrimarySignature,
            _options
        );
        return true;
    }

    function finalizePrimaryAddressChange(
        string calldata _unifiedId,
        address _newPrimaryAddress
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        UserData storage userData = userAddresses[_unifiedId];
        address oldPrimary = userData.primary;
        userData.primary = _newPrimaryAddress;
        resolveAddressFromUnifiedId[_unifiedId] = _newPrimaryAddress;
        resolveUnifiedIdFromAddress[_newPrimaryAddress] = _unifiedId;
        resolveUnifiedIdFromAddress[oldPrimary] = "";
        emit UnifiedIDUpdated(_unifiedId, oldPrimary, _newPrimaryAddress);
        return true;
    }

    function initiateAddSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress,
        bytes calldata _primarySignature,
        bytes calldata _secondarySignature,
        bytes calldata _options
    ) external payable whenNotPaused unifiedIdExists(_unifiedId) onlyRegistrar returns (bool) {
        UserData storage userData = userAddresses[_unifiedId];
        require(!userData.isSecondary[_secondaryAddress], "Secondary address already added");
        require(userData.secondaries.length < maxSecondaryAddresses, "Maximum secondary addresses limit reached");
        emit AddSecondaryAddressInitiated(
            _unifiedId,
            _secondaryAddress,
            _primarySignature,
            _secondarySignature,
            _options
        );
        return true;
    }

    function completeAddSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        UserData storage userData = userAddresses[_unifiedId];
        userData.isSecondary[_secondaryAddress] = true;
        userData.secondaries.push(_secondaryAddress);
        emit SecondaryAddressAdded(_unifiedId, _secondaryAddress);
        return true;
    }

    function initiateRemoveSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress,
        bytes calldata _signature,
        bytes calldata _options
    ) external payable whenNotPaused unifiedIdExists(_unifiedId) onlyRegistrar returns (bool) {
        emit RemoveSecondaryAddressInitiated(_unifiedId, _secondaryAddress, _signature, _options);
        return true;
    }

    function completeRemoveSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        UserData storage userData = userAddresses[_unifiedId];
        userData.isSecondary[_secondaryAddress] = false;
        for (uint i = 0; i < userData.secondaries.length; i++) {
            if (userData.secondaries[i] == _secondaryAddress) {
                userData.secondaries[i] = userData.secondaries[userData.secondaries.length - 1];
                userData.secondaries.pop();
                break;
            }
        }
        emit SecondaryAddressRemoved(_unifiedId, _secondaryAddress);
        return true;
    }

    function isPrimaryAddress(string calldata _unifiedId, address _address) external view returns (bool) {
        return userAddresses[_unifiedId].primary == _address;
    }

    function isSecondaryAddress(string calldata _unifiedId, address _address) external view returns (bool) {
        return userAddresses[_unifiedId].isSecondary[_address];
    }

    function getPrimaryAddress(string calldata _unifiedId) external view returns (address) {
        return userAddresses[_unifiedId].primary;
    }

    function getSecondaryAddresses(string calldata _unifiedId) external view returns (address[] memory) {
        return userAddresses[_unifiedId].secondaries;
    }

    function isRegisteredUnifiedId(string calldata unifiedId) external view returns (bool) {
        return registeredUnifiedIds[unifiedId];
    }

    function getTotalRegisteredUnifiedIds() external view returns (uint256) {
        return totalRegisteredUnifiedIds;
    }

    // === ADMIN FUNCTIONS ===
    
    /**
     * @notice Set maximum number of secondary addresses per unified ID
     * @param _maxSecondaryAddresses New maximum limit
     */
    function setMaxSecondaryAddresses(uint256 _maxSecondaryAddresses) external onlyOwner {
        uint256 oldMax = maxSecondaryAddresses;
        maxSecondaryAddresses = _maxSecondaryAddresses;
        emit MaxSecondaryAddressesUpdated(oldMax, _maxSecondaryAddresses);
    }
    
    /**
     * @notice Enable/disable public registrar registration
     * @param _enabled True to enable public registration, false to restrict to admin only
     */
    function setPublicRegistrarRegistration(bool _enabled) external onlyOwner {
        publicRegistrarRegistration = _enabled;
        emit PublicRegistrarRegistrationToggled(_enabled);
    }
    

    
    /**
     * @notice Toggle emergency mode - stops all operations except admin functions
     * @param _enabled True to enable emergency mode, false to disable
     */
    function setEmergencyMode(bool _enabled) external onlyOwner {
        emergencyMode = _enabled;
        emit EmergencyModeToggled(_enabled);
    }
    
    /**
     * @notice Add or remove admin user
     * @param _user Address to modify admin status
     * @param _isAdmin True to grant admin rights, false to revoke
     */
    function setAdminUser(address _user, bool _isAdmin) external onlyOwner {
        require(_user != address(0), "User cannot be zero address");
        adminUsers[_user] = _isAdmin;
        emit AdminUserUpdated(_user, _isAdmin);
    }
    
    /**
     * @notice Set maximum name updates allowed per registrar
     * @param _maxNameUpdates New maximum limit
     */
    function setMaxNameUpdates(uint256 _maxNameUpdates) external onlyOwner {
        require(_maxNameUpdates > 0, "Max name updates must be greater than 0");
        uint256 oldMax = maxNameUpdates;
        maxNameUpdates = _maxNameUpdates;
        emit MaxNameUpdatesChanged(oldMax, _maxNameUpdates);
    }
    
    /**
     * @notice Set unified ID length limits
     * @param _minLength Minimum length for unified IDs
     * @param _maxLength Maximum length for unified IDs
     */
    function setUnifiedIdLengthLimits(uint256 _minLength, uint256 _maxLength) external onlyOwner {
        require(_minLength > 0 && _maxLength > _minLength, "Invalid length limits");
        minUnifiedIdLength = _minLength;
        maxUnifiedIdLength = _maxLength;
        emit UnifiedIdLengthLimitsUpdated(_minLength, _maxLength);
    }
    
    /**
     * @notice Emergency function to mark unified ID as unavailable
     * @param _unifiedId Unified ID to mark as unavailable
     */
    function emergencyMarkUnavailable(string calldata _unifiedId) external onlyAdmin {
        unavailableUnifiedIds[_unifiedId] = true;
    }
    
    /**
     * @notice Emergency function to mark unified ID as available
     * @param _unifiedId Unified ID to mark as available
     */
    function emergencyMarkAvailable(string calldata _unifiedId) external onlyAdmin {
        unavailableUnifiedIds[_unifiedId] = false;
    }
    
    /**
     * @notice Emergency function to remove registrar
     * @param _registrarAddress Address of registrar to remove
     */
    function emergencyRemoveRegistrar(address _registrarAddress) external onlyAdmin {
        require(isRegisteredRegistrar[_registrarAddress], "Address is not a registrar");
        string memory registrarName = registrarNames[_registrarAddress];
        
        isRegisteredRegistrar[_registrarAddress] = false;
        isAddressTaken[_registrarAddress] = false;
        registrarNameToAddress[registrarName] = address(0);
        delete registrarNames[_registrarAddress];
        
        // Remove from registrarAddresses array
        for (uint i = 0; i < registrarAddresses.length; i++) {
            if (registrarAddresses[i] == _registrarAddress) {
                registrarAddresses[i] = registrarAddresses[registrarAddresses.length - 1];
                registrarAddresses.pop();
                break;
            }
        }
    }
    

    
    /**
     * @notice Get contract configuration
     * @return Configuration struct with all admin-controlled parameters
     */
    function getConfiguration() external view returns (
        uint256 _maxSecondaryAddresses,
        bool _publicRegistrarRegistration,
        bool _emergencyMode,
        uint256 _maxNameUpdates,
        uint256 _minUnifiedIdLength,
        uint256 _maxUnifiedIdLength
    ) {
        return (
            maxSecondaryAddresses,
            publicRegistrarRegistration,
            emergencyMode,
            maxNameUpdates,
            minUnifiedIdLength,
            maxUnifiedIdLength
        );
    }

    // === REGISTRAR ENUMERATION FUNCTIONS ===
    
    /**
     * @notice Get all registered registrar addresses
     * @return Array of all registrar addresses
     */
    function getAllRegistrars() external view returns (address[] memory) {
        return registrarAddresses;
    }
    
    /**
     * @notice Get all registrars with their names
     * @return addresses Array of registrar addresses
     * @return names Array of corresponding registrar names
     */
    function getAllRegistrarsWithNames() external view returns (address[] memory addresses, string[] memory names) {
        uint256 length = registrarAddresses.length;
        addresses = new address[](length);
        names = new string[](length);
        
        for (uint i = 0; i < length; i++) {
            addresses[i] = registrarAddresses[i];
            names[i] = registrarNames[registrarAddresses[i]];
        }
        
        return (addresses, names);
    }

    
    /**
     * @notice Get total number of registered registrars
     * @return Total count of registrars
     */
    function getTotalRegistrars() external view returns (uint256) {
        return registrarAddresses.length;
    }
    

    
    /**
     * @notice Check if an address is a registrar and get its details
     * @param _address Address to check
     * @return isRegistrar True if address is a registrar
     * @return registrarName Name of the registrar (empty if not a registrar)
     * @return updateCount Number of updates (0 if not a registrar)
     */
    function getRegistrarInfo(address _address) external view returns (
        bool isRegistrar,
        string memory registrarName,
        uint8 updateCount
    ) {
        return (
            isRegisteredRegistrar[_address],
            registrarNames[_address],
            totalRegistrarUpdates[_address]
        );
    }
}
