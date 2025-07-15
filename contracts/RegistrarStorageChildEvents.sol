// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import "./RegistrarStorageUtil.sol";
import "./IUnifiedIdResolver.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title RegistrarStorageChildEvents
 * @author kunalmkv
 * @notice Chain-specific unified ID management contract
 * @dev Optimized version with enum errors and gas optimizations
 */
contract RegistrarStorageChildEvents is Initializable, UUPSUpgradeable, AccessControlUpgradeable {

    // ==================== ROLE DEFINITIONS ====================

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // === ERROR ENUMS FOR GAS OPTIMIZATION ===
    error E1(); error E2(); error E3(); error E4(); error E5(); error E6(); error E7(); error E8(); error E9(); error E10();
    error E11(); error E12(); error E13(); error E14(); error E15(); error E16(); error E17(); error E18(); error E19(); error E20();
    error E21(); error E22(); error E23(); error E24(); error E25(); error E26(); error E27(); error E28(); error E29(); error E30();
    error E31(); error E32(); error E33(); error E34(); error E35(); error E36(); error E37(); error E38(); error E39(); error E40();
    error E41(); error E42(); error E43(); error E44(); error E45(); error E46(); error E47(); error E48();

    // Secondary Address Error Mappings:
    // E34: Cannot add primary address as secondary
    // E35: Secondary address already exists  
    // E36: Maximum secondary addresses exceeded
    // E37: Secondary signature verification failed
    // E38: Secondary address does not exist

    // === EVENT ENUM FOR OPTIMIZATION ===
    enum EventType {
        MaxSecondaryAddressesUpdated,
        PublicRegistrarRegistrationToggled,
        EmergencyModeToggled,
        UnifiedIdLengthLimitsUpdated,
        UtilImplementationUpdated,
        ResolverUpdated,
        ChainIdUpdated,
        AuthorizedRelayerUpdated,
        EmergencyUnifiedIdMarked,
        EmergencyRegistrarRemoved,
        SecondaryAddressAdded,
        SecondaryAddressRemoved,
        RegistrarRegistered,
        RegistrationPaused,
        RegistrationUnpaused,
        UnifiedIDRegistered,
        UnifiedIDUpdated,
        UnifiedIDChanged,
        RegisterUnifiedIdInitiated,
        UpdateUnifiedIdInitiated,
        UpdateUnifiedIdPrimaryAddressInitiated,
        AddSecondaryAddressInitiated,
        RemoveSecondaryAddressInitiated,
        EthWithdrawn,
        ERC20Withdrawn,
        OwnershipTransferStarted,
        OwnershipTransferred
    }

    // === SINGLE UNIFIED EVENT ===
    event UnifiedEvent(EventType indexed eventType, bytes data);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // === OWNABLE2STEP IMPLEMENTATION ===
    address private _owner;
    address private _pendingOwner;

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    modifier onlyOwner() {
        if (owner() != msg.sender) revert E1();
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert E2();
        _pendingOwner = newOwner;
        emit UnifiedEvent(EventType.OwnershipTransferStarted, abi.encode(owner(), newOwner));
    }

    function acceptOwnership() external {
        address sender = msg.sender;
        if (pendingOwner() != sender) revert E3();
        _transferOwnership(sender);
    }

    function _transferOwnership(address newOwner) internal virtual {
        delete _pendingOwner;
        address oldOwner = _owner;
        _owner = newOwner;
        emit UnifiedEvent(EventType.OwnershipTransferred, abi.encode(oldOwner, newOwner));
    }

    // === OPTIMIZED STORAGE STRUCTS ===
    struct UserData {
        address primary;
        mapping(address => bool) isSecondary;
        address[] secondaries;
        bool exists;
    }

    struct PackedConfig {
        uint8 maxSecondaryAddresses;
        uint8 minUnifiedIdLength;
        uint8 maxUnifiedIdLength;
        bool isPaused;
        bool publicRegistrarRegistration;
        bool emergencyMode;
    }

    PackedConfig public config;

    // === STATE VARIABLES ===
    uint256 public totalRegisteredUnifiedIds;
    uint256 public chainId;

    RegistrarStorageUtil public util;
    IUnifiedIdResolver public resolver;

    address[] public registrarAddresses;

    // Optimized mappings using bytes32
    mapping(bytes32 => address) public registrarNameToAddress;
    mapping(address => uint8) public totalRegistrarUpdates;
    mapping(bytes32 => UserData) private userAddresses;
    mapping(bytes32 => bool) public unavailableUnifiedIds;
    mapping(bytes32 => bool) public registeredUnifiedIds;
    mapping(bytes32 => address) public resolveAddressFromUnifiedId;
    mapping(address => bytes32) public resolveUnifiedIdFromAddress;
    mapping(bytes32 => mapping(uint256 => bool)) public usedNonces;

    string[] public registrarNames;

    // === HELPER FUNCTION FOR STRING TO BYTES32 ===
    function _toBytes32(string memory str) private pure returns (bytes32) {
        return keccak256(bytes(str));
    }

    // === MODIFIERS ===
    modifier unifiedIdExists(string calldata _unifiedId) {
        if (!userAddresses[_toBytes32(_unifiedId)].exists) revert E4();
        _;
    }

    modifier whenNotPaused() {
        if (config.isPaused) revert E5();
        _;
    }

    modifier unifiedIdDoesNotExist(string calldata _unifiedId) {
        bytes32 id = _toBytes32(_unifiedId);
        if (userAddresses[id].exists) revert E6();
        if (unavailableUnifiedIds[id]) revert E7();
        _;
    }

    modifier validateRegistrarName(string memory _registrarName) {
        bytes32 nameHash = _toBytes32(_registrarName);
        if (registrarNameToAddress[nameHash] != address(0)) revert E8();
        if (resolveAddressFromUnifiedId[nameHash] != address(0)) revert E9();
        _;
    }

    modifier onlyRegistrar() {
        require(hasRole(REGISTRAR_ROLE, msg.sender));
        _;
    }

    modifier onlyAuthorizedRelayer() {
        require(hasRole(RELAYER_ROLE, msg.sender));
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender) || msg.sender == owner());
        _;
    }

    modifier notInEmergencyMode() {
        if (config.emergencyMode) revert E13();
        _;
    }

    modifier publicRegistrarAllowed() {
        if (!config.publicRegistrarRegistration && !hasRole(ADMIN_ROLE, msg.sender) && msg.sender != owner()) revert E14();
        _;
    }

    modifier onlyEmergency() {
        require(hasRole(EMERGENCY_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender) || msg.sender == owner());
        _;
    }

    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(hasRole(UPGRADER_ROLE, msg.sender) || msg.sender == owner());
    }

    function initialize(address _RegistrarStorageUtil, address _resolver, uint256 _chainId) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();

        _owner = msg.sender;
        emit UnifiedEvent(EventType.OwnershipTransferred, abi.encode(address(0), msg.sender));

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        // Validate contract addresses
        if (_RegistrarStorageUtil == address(0)) revert E15();
        require(_isContract(_RegistrarStorageUtil), "RegistrarStorageUtil address is not a contract");
        
        if (_resolver == address(0)) revert E16();
        require(_isContract(_resolver), "Resolver address is not a contract");

        util = RegistrarStorageUtil(_RegistrarStorageUtil);
        resolver = IUnifiedIdResolver(_resolver);
        chainId = _chainId;

        config = PackedConfig({
            maxSecondaryAddresses: 10,
            minUnifiedIdLength: 4,
            maxUnifiedIdLength: 16,
            isPaused: false,
            publicRegistrarRegistration: false,
            emergencyMode: false
        });
    }

    function setUtilImplementation(address _RegistrarStorageUtil) external onlyRole(ADMIN_ROLE) {
        if (_RegistrarStorageUtil == address(0)) revert E15();
        require(_isContract(_RegistrarStorageUtil), "RegistrarStorageUtil address is not a contract");
        
        address oldUtil = address(util);
        util = RegistrarStorageUtil(_RegistrarStorageUtil);
        emit UnifiedEvent(EventType.UtilImplementationUpdated, abi.encode(oldUtil, _RegistrarStorageUtil, msg.sender));
    }

    function setResolver(address _resolver) external onlyRole(ADMIN_ROLE) {
        if (_resolver == address(0)) revert E16();
        require(_isContract(_resolver), "Resolver address is not a contract");
        
        address oldResolver = address(resolver);
        resolver = IUnifiedIdResolver(_resolver);
        emit UnifiedEvent(EventType.ResolverUpdated, abi.encode(oldResolver, _resolver, msg.sender));
    }

    function setChainId(uint256 _chainId) external onlyRole(ADMIN_ROLE) {
        uint256 oldChainId = chainId;
        chainId = _chainId;
        emit UnifiedEvent(EventType.ChainIdUpdated, abi.encode(oldChainId, _chainId, msg.sender));
    }

    function registerRegistrar(string calldata _registrarName, address _registrarAddress) external payable whenNotPaused validateRegistrarName(_registrarName) publicRegistrarAllowed notInEmergencyMode returns (bool) {
        if (_registrarAddress == address(0)) revert E18();
        if (_isAddressTaken(_registrarAddress)) revert E19();

        bytes32 nameHash = _toBytes32(_registrarName);
        registrarNameToAddress[nameHash] = _registrarAddress;
        registrarAddresses.push(_registrarAddress);
        registrarNames.push(_registrarName);

        _grantRole(REGISTRAR_ROLE, _registrarAddress);
        emit UnifiedEvent(EventType.RegistrarRegistered, abi.encode(_registrarAddress, _registrarName));
        return true;
    }

    function pauseRegistration() external onlyRole(ADMIN_ROLE) {
        config.isPaused = true;
        emit UnifiedEvent(EventType.RegistrationPaused, abi.encode(msg.sender));
    }

    function unpauseRegistration() external onlyRole(ADMIN_ROLE) {
        config.isPaused = false;
        emit UnifiedEvent(EventType.RegistrationUnpaused, abi.encode(msg.sender));
    }

    function initiateRegisterUnifiedId(string calldata _unifiedId, address _primaryAddress, bytes calldata _masterSignature, bytes calldata _primarySignature, bytes calldata _options) external payable whenNotPaused onlyRegistrar returns (bool) {
        if (!util.isUnifiedIdValid(_unifiedId)) revert E20();
        bytes32 id = _toBytes32(_unifiedId);
        if (userAddresses[id].exists) revert E6();
        if (unavailableUnifiedIds[id]) revert E7();
        if (registrarNameToAddress[id] != address(0)) revert E21();
        if (resolveAddressFromUnifiedId[id] != address(0)) revert E22();

        emit UnifiedEvent(EventType.RegisterUnifiedIdInitiated, abi.encode(_unifiedId, _primaryAddress, _masterSignature, _primarySignature, _options));
        return true;
    }

    function completeRegisterUnifiedId(string calldata _unifiedId, address _primaryAddress, bytes calldata _masterSignature, bytes calldata _primarySignature, uint256 _nonce, uint256 _timestamp) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        bytes32 id = _toBytes32(_unifiedId);
        if (usedNonces[id][_nonce]) revert E24();

        // Simple signature verification - encode data with nonce
        bytes memory message = abi.encode(_unifiedId, _primaryAddress);
        bytes memory messageWithNonce = abi.encodePacked(message, _nonce);

        if (!util.verifySignature(messageWithNonce, _primaryAddress, _primarySignature)) revert E25();

        if (_masterSignature.length != 0) {
            if (!util.verifySignature(messageWithNonce, _primaryAddress, _masterSignature)) revert E26();
        }

        usedNonces[id][_nonce] = true;

        UserData storage userData = userAddresses[id];
        userData.primary = _primaryAddress;
        userData.exists = true;

        resolveAddressFromUnifiedId[id] = _primaryAddress;
        resolveUnifiedIdFromAddress[_primaryAddress] = id;
        registeredUnifiedIds[id] = true;
        totalRegisteredUnifiedIds++;
        unavailableUnifiedIds[id] = true;

        resolver.setUnifiedIdPrimaryAddress(_unifiedId, chainId, _primaryAddress);

        emit UnifiedEvent(EventType.UnifiedIDRegistered, abi.encode(_unifiedId, _primaryAddress, block.timestamp));
        return true;
    }

    function initiateUpdateUnifiedId(string calldata _oldUnifiedId, string calldata _newUnifiedId, bytes calldata _signature, bytes calldata _options) external payable whenNotPaused unifiedIdExists(_oldUnifiedId) unifiedIdDoesNotExist(_newUnifiedId) onlyRegistrar returns (bool) {
        if (!util.isUnifiedIdValid(_newUnifiedId)) revert E27();
        emit UnifiedEvent(EventType.UpdateUnifiedIdInitiated, abi.encode(_oldUnifiedId, _newUnifiedId, _signature, _options));
        return true;
    }

    function completeUpdateUnifiedId(string memory _oldUnifiedId, string memory _newUnifiedId, bytes calldata _signature, uint256 _nonce, uint256 _timestamp) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        bytes32 oldId = _toBytes32(_oldUnifiedId);
        bytes32 newId = _toBytes32(_newUnifiedId);

        if (!registeredUnifiedIds[oldId]) revert E28();
        if (registeredUnifiedIds[newId]) revert E29();
        if (oldId == newId) revert E46();

        UserData storage userData = userAddresses[oldId];
        address currentPrimary = userData.primary;

        if (usedNonces[oldId][_nonce]) revert E24();

        // Simple signature verification - encode data with nonce
        bytes memory message = abi.encode(_oldUnifiedId, _newUnifiedId);
        bytes memory messageWithNonce = abi.encodePacked(message, _nonce);

        if (!util.verifySignature(messageWithNonce, currentPrimary, _signature)) revert E30();

        usedNonces[oldId][_nonce] = true;

        address primaryAddress = currentPrimary;

        resolveAddressFromUnifiedId[newId] = primaryAddress;
        delete resolveAddressFromUnifiedId[oldId];
        resolveUnifiedIdFromAddress[primaryAddress] = newId;

        UserData storage newUserData = userAddresses[newId];
        newUserData.primary = primaryAddress;
        newUserData.exists = true;

        resolver.clearUnifiedIdMappings(_oldUnifiedId, chainId);
        resolver.setUnifiedIdPrimaryAddress(_newUnifiedId, chainId, primaryAddress);

        uint256 secLength = userData.secondaries.length;
        for (uint256 i; i < secLength;) {
            address secondaryAddr = userData.secondaries[i];
            if (newUserData.isSecondary[secondaryAddr]) revert E31();

            newUserData.isSecondary[secondaryAddr] = true;
            newUserData.secondaries.push(secondaryAddr);
            resolver.addUnifiedIdSecondaryAddress(_newUnifiedId, chainId, secondaryAddr);

            unchecked { ++i; }
        }

        delete registeredUnifiedIds[oldId];
        registeredUnifiedIds[newId] = true;
        unavailableUnifiedIds[oldId] = true;
        unavailableUnifiedIds[newId] = true;
        delete userAddresses[oldId];

        emit UnifiedEvent(EventType.UnifiedIDChanged, abi.encode(_oldUnifiedId, _newUnifiedId, primaryAddress, block.timestamp));
        return true;
    }

    function initiatePrimaryAddressChange(string calldata _unifiedId, address _newPrimaryAddress, bytes calldata currentPrimarySignature, bytes calldata newPrimarySignature, bytes calldata _options) external payable whenNotPaused unifiedIdExists(_unifiedId) onlyRegistrar returns (bool) {
        emit UnifiedEvent(EventType.UpdateUnifiedIdPrimaryAddressInitiated, abi.encode(_unifiedId, _newPrimaryAddress, currentPrimarySignature, newPrimarySignature, _options));
        return true;
    }

    function finalizePrimaryAddressChange(string calldata _unifiedId, address _newPrimaryAddress, bytes calldata _currentPrimarySignature, bytes calldata _newPrimarySignature, uint256 _nonce, uint256 _timestamp) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        bytes32 id = _toBytes32(_unifiedId);
        UserData storage userData = userAddresses[id];
        address oldPrimary = userData.primary;

        if (oldPrimary == _newPrimaryAddress) revert E47();
        if (_newPrimaryAddress == address(0)) revert E48();
        if (usedNonces[id][_nonce]) revert E24();

        // Simple signature verification - encode data with nonce
        bytes memory message = abi.encode(_unifiedId, _newPrimaryAddress);
        bytes memory messageWithNonce = abi.encodePacked(message, _nonce);

        if (!util.verifySignature(messageWithNonce, oldPrimary, _currentPrimarySignature)) revert E32();
        if (!util.verifySignature(messageWithNonce, _newPrimaryAddress, _newPrimarySignature)) revert E33();

        usedNonces[id][_nonce] = true;
        userData.primary = _newPrimaryAddress;
        resolveAddressFromUnifiedId[id] = _newPrimaryAddress;
        resolveUnifiedIdFromAddress[_newPrimaryAddress] = id;
        resolveUnifiedIdFromAddress[oldPrimary] = bytes32(0);

        resolver.updateUnifiedIdPrimaryAddress(_unifiedId, chainId, _newPrimaryAddress);

        emit UnifiedEvent(EventType.UnifiedIDUpdated, abi.encode(_unifiedId, oldPrimary, _newPrimaryAddress));
        return true;
    }

    function initiateAddSecondaryAddress(string calldata _unifiedId, address _secondaryAddress, bytes calldata _primarySignature, bytes calldata _secondarySignature, bytes calldata _options) external payable whenNotPaused unifiedIdExists(_unifiedId) onlyRegistrar returns (bool) {
        bytes32 id = _toBytes32(_unifiedId);
        UserData storage userData = userAddresses[id];

        if (userData.primary == _secondaryAddress) revert E34();
        if (userData.isSecondary[_secondaryAddress]) revert E35();
        if (userData.secondaries.length >= config.maxSecondaryAddresses) revert E36();

        emit UnifiedEvent(EventType.AddSecondaryAddressInitiated, abi.encode(_unifiedId, _secondaryAddress, _primarySignature, _secondarySignature, _options));
        return true;
    }

    function completeAddSecondaryAddress(string calldata _unifiedId, address _secondaryAddress, bytes calldata _primarySignature, bytes calldata _secondarySignature, uint256 _nonce, uint256 _timestamp) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        bytes32 id = _toBytes32(_unifiedId);
        UserData storage userData = userAddresses[id];

        if (userData.primary == _secondaryAddress) revert E34();
        if (userData.isSecondary[_secondaryAddress]) revert E35();
        if (usedNonces[id][_nonce]) revert E24();

        // Simple signature verification - encode data with nonce
        bytes memory message = abi.encode(_unifiedId, _secondaryAddress);
        bytes memory messageWithNonce = abi.encodePacked(message, _nonce);

        if (!util.verifySignature(messageWithNonce, userData.primary, _primarySignature)) revert E25();
        if (!util.verifySignature(messageWithNonce, _secondaryAddress, _secondarySignature)) revert E37();

        usedNonces[id][_nonce] = true;
        userData.isSecondary[_secondaryAddress] = true;
        userData.secondaries.push(_secondaryAddress);

        resolver.addUnifiedIdSecondaryAddress(_unifiedId, chainId, _secondaryAddress);

        emit UnifiedEvent(EventType.SecondaryAddressAdded, abi.encode(_unifiedId, _secondaryAddress));
        return true;
    }

    function initiateRemoveSecondaryAddress(string calldata _unifiedId, address _secondaryAddress, bytes calldata _signature, bytes calldata _options) external payable whenNotPaused unifiedIdExists(_unifiedId) onlyRegistrar returns (bool) {
        bytes32 id = _toBytes32(_unifiedId);
        UserData storage userData = userAddresses[id];

        // Validation: Ensure the secondary address actually exists before initiating removal
        if (!userData.isSecondary[_secondaryAddress]) revert E38(); // Secondary address does not exist

        emit UnifiedEvent(EventType.RemoveSecondaryAddressInitiated, abi.encode(_unifiedId, _secondaryAddress, _signature, _options));
        return true;
    }

    function completeRemoveSecondaryAddress(string calldata _unifiedId, address _secondaryAddress, bytes calldata _signature, uint256 _nonce, uint256 _timestamp) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        bytes32 id = _toBytes32(_unifiedId);
        UserData storage userData = userAddresses[id];

        if (usedNonces[id][_nonce]) revert E24();

        // Simple signature verification - encode data with nonce
        bytes memory message = abi.encode(_unifiedId, _secondaryAddress);
        bytes memory messageWithNonce = abi.encodePacked(message, _nonce);

        if (!util.verifySignature(messageWithNonce, userData.primary, _signature)) revert E30();

        usedNonces[id][_nonce] = true;
        userData.isSecondary[_secondaryAddress] = false;

        uint256 length = userData.secondaries.length;
        for (uint256 i; i < length;) {
            if (userData.secondaries[i] == _secondaryAddress) {
                userData.secondaries[i] = userData.secondaries[length - 1];
                userData.secondaries.pop();
                break;
            }
            unchecked { ++i; }
        }

        resolver.removeUnifiedIdSecondaryAddress(_unifiedId, chainId, _secondaryAddress);

        emit UnifiedEvent(EventType.SecondaryAddressRemoved, abi.encode(_unifiedId, _secondaryAddress));
        return true;
    }

    // === VIEW FUNCTIONS ===
    function isPrimaryAddress(string calldata _unifiedId, address _address) external view returns (bool) {
        return userAddresses[_toBytes32(_unifiedId)].primary == _address;
    }

    function isSecondaryAddress(string calldata _unifiedId, address _address) external view returns (bool) {
        return userAddresses[_toBytes32(_unifiedId)].isSecondary[_address];
    }

    function getPrimaryAddress(string calldata _unifiedId) external view returns (address) {
        return userAddresses[_toBytes32(_unifiedId)].primary;
    }

    function getSecondaryAddresses(string calldata _unifiedId) external view returns (address[] memory) {
        return userAddresses[_toBytes32(_unifiedId)].secondaries;
    }

    function getTotalRegisteredUnifiedIds() external view returns (uint256) {
        return totalRegisteredUnifiedIds;
    }

    function resolveAddressToUnifiedId(address addr) external view returns (string memory) {
        return resolver.getUnifiedIdFromAddress(addr, chainId);
    }

    function resolvePrimaryAddress(string calldata unifiedId) external view returns (address) {
        return resolver.getPrimaryAddress(unifiedId, chainId);
    }

    function resolveAllAddresses(string calldata unifiedId) external view returns (address primary, address[] memory secondaries) {
        return resolver.getAddresses(unifiedId, chainId);
    }

    function resolveAddressAssociation(string calldata unifiedId, address addr) external view returns (bool isPrimary, bool isSecondary) {
        return resolver.isAddressAssociated(unifiedId, chainId, addr);
    }

    function resolveSecondaryAddressToUnifiedId(address secondaryAddr) external view returns (string memory) {
        return resolver.resolveSecondaryAddressToUnifiedId(secondaryAddr, chainId);
    }

    function resolveAnyAddressToUnifiedId(address addr) external view returns (string memory unifiedId, bool isPrimary, bool isSecondary) {
        return resolver.resolveAnyAddressToUnifiedId(addr, chainId);
    }

    function getAllAddresses(string calldata unifiedId) external view returns (address[] memory allAddresses) {
        return resolver.getAllAddresses(unifiedId, chainId);
    }

    function getAddressCount(string calldata unifiedId) external view returns (uint256 count) {
        return resolver.getAddressCount(unifiedId, chainId);
    }

    function hasMultipleAddresses(string calldata unifiedId) external view returns (bool hasMultiple) {
        return resolver.getAddressCount(unifiedId, chainId) > 1;
    }

    // === UNIFIED ROLE MANAGEMENT ===
    function manageRole(bytes32 role, address account, bool grant) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (grant) {
            _grantRole(role, account);
        } else {
            _revokeRole(role, account);
        }

        if (role == RELAYER_ROLE) {
            emit UnifiedEvent(EventType.AuthorizedRelayerUpdated, abi.encode(account, grant, msg.sender));
        }
    }

    // === ROLE CHECKING FUNCTIONS ===
    function isRelayer(address account) external view returns (bool) {
        return hasRole(RELAYER_ROLE, account);
    }

    function isRegistrar(address account) external view returns (bool) {
        return hasRole(REGISTRAR_ROLE, account);
    }

    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    function isEmergencyResponder(address account) external view returns (bool) {
        return hasRole(EMERGENCY_ROLE, account);
    }

    function isUpgrader(address account) external view returns (bool) {
        return hasRole(UPGRADER_ROLE, account);
    }

    // === ADMIN FUNCTIONS ===
    function setMaxSecondaryAddresses(uint256 _maxSecondaryAddresses) external onlyRole(ADMIN_ROLE) {
        uint256 oldMax = config.maxSecondaryAddresses;
        config.maxSecondaryAddresses = uint8(_maxSecondaryAddresses);
        emit UnifiedEvent(EventType.MaxSecondaryAddressesUpdated, abi.encode(oldMax, _maxSecondaryAddresses));
    }

    function setRegistrarRegistrationPermission(bool _enabled) external onlyRole(ADMIN_ROLE) {
        config.publicRegistrarRegistration = _enabled;
        emit UnifiedEvent(EventType.PublicRegistrarRegistrationToggled, abi.encode(_enabled));
    }

    function setEmergencyMode(bool _enabled) external onlyRole(EMERGENCY_ROLE) {
        config.emergencyMode = _enabled;
        emit UnifiedEvent(EventType.EmergencyModeToggled, abi.encode(_enabled));
    }

    function setUnifiedIdLengthLimits(uint256 _minLength, uint256 _maxLength) external onlyRole(ADMIN_ROLE) {
        if (_minLength == 0 || _maxLength <= _minLength) revert E39();
        config.minUnifiedIdLength = uint8(_minLength);
        config.maxUnifiedIdLength = uint8(_maxLength);
        emit UnifiedEvent(EventType.UnifiedIdLengthLimitsUpdated, abi.encode(_minLength, _maxLength));
    }

    function emergencyMarkUnavailable(string calldata _unifiedId) external onlyEmergency {
        bytes32 id = _toBytes32(_unifiedId);
        unavailableUnifiedIds[id] = true;
        emit UnifiedEvent(EventType.EmergencyUnifiedIdMarked, abi.encode(_unifiedId, false, msg.sender));
    }

    function emergencyMarkAvailable(string calldata _unifiedId) external onlyEmergency {
        bytes32 id = _toBytes32(_unifiedId);
        unavailableUnifiedIds[id] = false;
        emit UnifiedEvent(EventType.EmergencyUnifiedIdMarked, abi.encode(_unifiedId, true, msg.sender));
    }

    function emergencyRemoveRegistrar(address _registrarAddress) external onlyEmergency {
        if (!hasRole(REGISTRAR_ROLE, _registrarAddress)) revert E40();

        string memory registrarName = getRegistrarName(_registrarAddress);
        _revokeRole(REGISTRAR_ROLE, _registrarAddress);
        bytes32 nameHash = _toBytes32(registrarName);
        registrarNameToAddress[nameHash] = address(0);
        delete registrarNameToAddress[nameHash];

        uint256 length = registrarAddresses.length;
        for (uint256 i; i < length;) {
            if (registrarAddresses[i] == _registrarAddress) {
                registrarAddresses[i] = registrarAddresses[length - 1];
                registrarAddresses.pop();
                registrarNames[i] = registrarNames[length - 1];
                registrarNames.pop();
                break;
            }
            unchecked { ++i; }
        }

        emit UnifiedEvent(EventType.EmergencyRegistrarRemoved, abi.encode(_registrarAddress, registrarName, msg.sender));
    }

    function getConfiguration() external view returns (uint256, bool, bool, uint256, uint256) {
        return (config.maxSecondaryAddresses, config.publicRegistrarRegistration, config.emergencyMode, config.minUnifiedIdLength, config.maxUnifiedIdLength);
    }

    function getAllRegistrars() external view returns (address[] memory) {
        return registrarAddresses;
    }

    function getAllRegistrarsWithNames() external view returns (address[] memory addresses, string[] memory names) {
        return (registrarAddresses, registrarNames);
    }

    function getTotalRegistrars() external view returns (uint256) {
        return registrarAddresses.length;
    }

    function getRegistrarInfo(address _address) external view returns (bool isReg, string memory registrarName, uint8 updateCount) {
        return (hasRole(REGISTRAR_ROLE, _address), getRegistrarName(_address), totalRegistrarUpdates[_address]);
    }

    receive() external payable {}
    fallback() external payable {}

    function withdrawEth(address payable to, uint256 amount) external onlyOwner whenNotPaused {
        if (to == address(0)) revert E41();
        if (amount > address(this).balance) revert E42();

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert E43();

        emit UnifiedEvent(EventType.EthWithdrawn, abi.encode(to, amount));
    }

    function withdrawERC20(address token, address to, uint256 amount) external onlyOwner whenNotPaused {
        if (token == address(0)) revert E44();
        if (to == address(0)) revert E41();
        
        // Verify token is a contract using RegistrarStorageUtil
        require(util.isContract(token), "Token address is not a contract");

        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert E45();

        emit UnifiedEvent(EventType.ERC20Withdrawn, abi.encode(token, to, amount));
    }

    function getRegistrarName(address _address) public view returns (string memory) {
        for (uint256 i = 0; i < registrarAddresses.length; i++) {
            if (registrarAddresses[i] == _address) {
                return registrarNames[i];
            }
        }
        return "";
    }

    // === INTERNAL HELPER FUNCTIONS ===
    function _isAddressTaken(address _address) private view returns (bool) {
        for (uint256 i = 0; i < registrarAddresses.length; i++) {
            if (registrarAddresses[i] == _address) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Checks if an address is a contract
     * @dev Uses extcodesize to determine if address contains contract code
     * @param addr Address to check
     * @return True if address is a contract, false if EOA
     */
    function _isContract(address addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(addr)
        }
        return (size != 0);
    }
}