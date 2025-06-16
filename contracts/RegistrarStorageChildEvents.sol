// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import "./RegistrarStorageUtil.sol";
import "./IUnifiedIdResolver.sol";
import "./RegistrarOperationsLib.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title RegistrarStorageChildEvents
 * @author kunalmkv
 * @notice Chain-specific unified ID management contract with comprehensive event tracking and role-based access control
 * @dev Optimized version with enum errors, gas optimizations, and OpenZeppelin AccessControl
 */
contract RegistrarStorageChildEvents is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    using RegistrarOperationsLib for *;

    // ==================== ROLE DEFINITIONS ====================

    /// @notice Role for authorized relayers who can execute operations
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    /// @notice Role for registrars who can initiate operations
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    /// @notice Role for admin users with elevated privileges
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role for emergency operations
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    /// @notice Role for upgrading the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // === ERROR ENUMS FOR GAS OPTIMIZATION ===
    error E1(); error E2(); error E3(); error E4(); error E5(); error E6(); error E7(); error E8(); error E9(); error E10();
    error E11(); error E12(); error E13(); error E14(); error E15(); error E16(); error E17(); error E18(); error E19(); error E20();
    error E21(); error E22(); error E23(); error E24(); error E25(); error E26(); error E27(); error E28(); error E29(); error E30();
    error E31(); error E32(); error E33(); error E34(); error E35(); error E36(); error E37(); error E38(); error E39(); error E40();
    error E41(); error E42(); error E43(); error E44(); error E45(); error E46(); error E47(); error E48();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // === OWNABLE2STEP IMPLEMENTATION ===
    address private _owner;
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

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
        emit OwnershipTransferStarted(owner(), newOwner);
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
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // === OPTIMIZED STORAGE STRUCTS ===
    struct UserData {
        address primary;
        mapping(address => bool) isSecondary;
        address[] secondaries;
        bool exists;
    }

    // Packed struct for gas optimization
    struct PackedConfig {
        uint128 maxSecondaryAddresses;
        uint64 minUnifiedIdLength;
        uint64 maxUnifiedIdLength;
        bool isPaused;
        bool publicRegistrarRegistration;
        bool emergencyMode;
    }

    PackedConfig public config;

    // === STATE VARIABLES (OPTIMIZED ORDER) ===
    uint256 public totalUnifiedIdRegistered;
    uint256 public chainId;
    uint256 public totalRegisteredUnifiedIds;

    RegistrarStorageUtil public util;
    IUnifiedIdResolver public resolver;

    address[] public registrarAddresses;

    mapping(string => address) public registrarNameToAddress;
    mapping(address => uint8) public totalRegistrarUpdates;
    mapping(string => UserData) private userAddresses;
    mapping(string => bool) public unavailableUnifiedIds;
    mapping(string => bool) public registeredUnifiedIds;
    mapping(string => address) public resolveAddressFromUnifiedId;
    mapping(address => string) public resolveUnifiedIdFromAddress;
    mapping(string => mapping(uint256 => bool)) public usedNonces;

    // STORAGE OPTIMIZATION: Store registrar names in array parallel to addresses
    string[] public registrarNames;

    // === CONSOLIDATED EVENTS ===
    event ConfigUpdated(uint256 maxSecondary, bool publicReg, bool emergency, uint256 minLength, uint256 maxLength);
    event SystemUpdated(address indexed component, address indexed newAddr, address indexed updatedBy);
    event RegistrarAction(address indexed registrar, string action, address indexed updatedBy);
    event RegistrarRegistered(address registrar, string registrarName);
    event RegistrationStatusChanged(bool paused, address by);
    event WithdrawalExecuted(address indexed token, address indexed to, uint256 amount);

    // === ROLE-BASED MODIFIERS ===
    modifier unifiedIdExists(string calldata _unifiedId) {
        if (!userAddresses[_unifiedId].exists) revert E4();
        _;
    }

    modifier whenNotPaused() {
        if (config.isPaused) revert E5();
        _;
    }

    modifier unifiedIdDoesNotExist(string calldata _unifiedId) {
        if (userAddresses[_unifiedId].exists) revert E6();
        if (unavailableUnifiedIds[_unifiedId]) revert E7();
        _;
    }

    modifier validateRegistrarName(string memory _registrarName) {
        if (registrarNameToAddress[_registrarName] != address(0)) revert E8();
        if (resolveAddressFromUnifiedId[_registrarName] != address(0)) revert E9();
        _;
    }

    modifier onlyRegistrar() {
        require(hasRole(REGISTRAR_ROLE, msg.sender), "AccessControl: caller is not registrar");
        _;
    }

    modifier onlyAuthorizedRelayer() {
        require(hasRole(RELAYER_ROLE, msg.sender), "AccessControl: caller is not relayer");
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender) || msg.sender == owner(), "AccessControl: caller is not admin");
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
        require(hasRole(EMERGENCY_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender) || msg.sender == owner(), "AccessControl: caller is not emergency responder");
        _;
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        require(hasRole(UPGRADER_ROLE, msg.sender) || msg.sender == owner(), "AccessControl: caller is not upgrader");
    }

    function initialize(address _RegistrarStorageUtil, address _resolver, uint256 _chainId) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();

        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);

        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        util = RegistrarStorageUtil(_RegistrarStorageUtil);
        resolver = IUnifiedIdResolver(_resolver);
        chainId = _chainId;

        // Initialize packed config
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
        emit SystemUpdated(address(util), _RegistrarStorageUtil, msg.sender);
        util = RegistrarStorageUtil(_RegistrarStorageUtil);
    }

    function setResolver(address _resolver) external onlyRole(ADMIN_ROLE) {
        if (_resolver == address(0)) revert E16();
        emit SystemUpdated(address(resolver), _resolver, msg.sender);
        resolver = IUnifiedIdResolver(_resolver);
    }

    function setChainId(uint256 _chainId) external onlyRole(ADMIN_ROLE) {
        emit SystemUpdated(address(0), address(uint160(_chainId)), msg.sender);
        chainId = _chainId;
    }

    function registerRegistrar(
        string calldata _registrarName,
        address _registrarAddress
    ) external payable whenNotPaused validateRegistrarName(_registrarName) publicRegistrarAllowed notInEmergencyMode returns (bool) {
        if (_registrarAddress == address(0)) revert E18();
        if (RegistrarOperationsLib.isAddressTaken(registrarAddresses, _registrarAddress)) revert E19();

        registrarNameToAddress[_registrarName] = _registrarAddress;
        registrarAddresses.push(_registrarAddress);
        registrarNames.push(_registrarName);

        // Grant registrar role
        _grantRole(REGISTRAR_ROLE, _registrarAddress);

        emit RegistrarRegistered(_registrarAddress, _registrarName);
        return true;
    }

    function pauseRegistration() external onlyRole(ADMIN_ROLE) {
        config.isPaused = true;
        emit RegistrationStatusChanged(true, msg.sender);
    }

    function unpauseRegistration() external onlyRole(ADMIN_ROLE) {
        config.isPaused = false;
        emit RegistrationStatusChanged(false, msg.sender);
    }

    function initiateRegisterUnifiedId(
        string calldata _unifiedId,
        address _primaryAddress,
        bytes calldata _masterSignature,
        bytes calldata _primarySignature,
        bytes calldata _options
    ) external payable whenNotPaused onlyRegistrar returns (bool) {
        return RegistrarOperationsLib.initiateRegisterUnifiedId(
            _unifiedId,
            _primaryAddress,
            _masterSignature,
            _primarySignature,
            _options,
            util,
            userAddresses,
            unavailableUnifiedIds,
            registrarNameToAddress,
            resolveAddressFromUnifiedId
        );
    }

    function completeRegisterUnifiedId(
        string calldata _unifiedId,
        address _primaryAddress,
        bytes calldata _masterSignature,
        bytes calldata _primarySignature,
        uint256 _nonce,
        uint256 _timestamp
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        // Create structs for the library call
        RegistrarOperationsLib.RegistrationParams memory params = RegistrarOperationsLib.RegistrationParams({
            unifiedId: _unifiedId,
            primaryAddress: _primaryAddress,
            masterSignature: _masterSignature,
            primarySignature: _primarySignature,
            nonce: _nonce,
            timestamp: _timestamp,
            chainId: chainId
        });

        RegistrarOperationsLib.ContractRefs memory contracts = RegistrarOperationsLib.ContractRefs({
            util: util,
            resolver: resolver
        });

        bool success = RegistrarOperationsLib.completeRegisterUnifiedId(
            params,
            contracts,
            userAddresses,
            usedNonces,
            resolveAddressFromUnifiedId,
            resolveUnifiedIdFromAddress,
            registeredUnifiedIds,
            unavailableUnifiedIds
        );

        if (success) {
            totalRegisteredUnifiedIds++;
            totalUnifiedIdRegistered++;
        }

        return success;
    }

    function initiateUpdateUnifiedId(
        string calldata _oldUnifiedId,
        string calldata _newUnifiedId,
        bytes calldata _signature,
        bytes calldata _options
    ) external payable whenNotPaused unifiedIdExists(_oldUnifiedId) unifiedIdDoesNotExist(_newUnifiedId) onlyRegistrar returns (bool) {
        return RegistrarOperationsLib.initiateUpdateUnifiedId(
            _oldUnifiedId,
            _newUnifiedId,
            _signature,
            _options,
            util,
            userAddresses,
            unavailableUnifiedIds
        );
    }

    function completeUpdateUnifiedId(
        string memory _oldUnifiedId,
        string memory _newUnifiedId,
        bytes calldata _signature,
        uint256 _nonce,
        uint256 _timestamp
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        return RegistrarOperationsLib.completeUpdateUnifiedId(
            _oldUnifiedId,
            _newUnifiedId,
            _signature,
            _nonce,
            _timestamp,
            chainId,
            util,
            resolver,
            userAddresses,
            usedNonces,
            resolveAddressFromUnifiedId,
            resolveUnifiedIdFromAddress,
            registeredUnifiedIds,
            unavailableUnifiedIds
        );
    }

    function initiatePrimaryAddressChange(
        string calldata _unifiedId,
        address _newPrimaryAddress,
        bytes calldata currentPrimarySignature,
        bytes calldata newPrimarySignature,
        bytes calldata _options
    ) external payable whenNotPaused unifiedIdExists(_unifiedId) onlyRegistrar returns (bool) {
        return RegistrarOperationsLib.initiatePrimaryAddressChange(
            _unifiedId,
            _newPrimaryAddress,
            currentPrimarySignature,
            newPrimarySignature,
            _options,
            userAddresses
        );
    }

    function finalizePrimaryAddressChange(
        string calldata _unifiedId,
        address _newPrimaryAddress,
        bytes calldata _currentPrimarySignature,
        bytes calldata _newPrimarySignature,
        uint256 _nonce,
        uint256 _timestamp
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        return RegistrarOperationsLib.finalizePrimaryAddressChange(
            _unifiedId,
            _newPrimaryAddress,
            _currentPrimarySignature,
            _newPrimarySignature,
            _nonce,
            _timestamp,
            chainId,
            util,
            resolver,
            userAddresses,
            usedNonces,
            resolveAddressFromUnifiedId,
            resolveUnifiedIdFromAddress
        );
    }

    function initiateAddSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress,
        bytes calldata _primarySignature,
        bytes calldata _secondarySignature,
        bytes calldata _options
    ) external payable whenNotPaused unifiedIdExists(_unifiedId) onlyRegistrar returns (bool) {
        return RegistrarOperationsLib.initiateAddSecondaryAddress(
            _unifiedId,
            _secondaryAddress,
            _primarySignature,
            _secondarySignature,
            _options,
            userAddresses,
            config
        );
    }

    function completeAddSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress,
        bytes calldata _primarySignature,
        bytes calldata _secondarySignature,
        uint256 _nonce,
        uint256 _timestamp
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        // Create structs for the library call
        RegistrarOperationsLib.SecondaryAddressParams memory params = RegistrarOperationsLib.SecondaryAddressParams({
            unifiedId: _unifiedId,
            secondaryAddress: _secondaryAddress,
            primarySignature: _primarySignature,
            secondarySignature: _secondarySignature,
            signature: "", // Not used for add operations
            nonce: _nonce,
            timestamp: _timestamp,
            chainId: chainId
        });
        
        RegistrarOperationsLib.ContractRefs memory contracts = RegistrarOperationsLib.ContractRefs({
            util: util,
            resolver: resolver
        });
        
        return RegistrarOperationsLib.completeAddSecondaryAddress(
            params,
            contracts,
            userAddresses,
            usedNonces
        );
    }

    function initiateRemoveSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress,
        bytes calldata _signature,
        bytes calldata _options
    ) external payable whenNotPaused unifiedIdExists(_unifiedId) onlyRegistrar returns (bool) {
        return RegistrarOperationsLib.initiateRemoveSecondaryAddress(
            _unifiedId,
            _secondaryAddress,
            _signature,
            _options,
            userAddresses
        );
    }

    function completeRemoveSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress,
        bytes calldata _signature,
        uint256 _nonce,
        uint256 _timestamp
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        // Create structs for the library call
        RegistrarOperationsLib.SecondaryAddressParams memory params = RegistrarOperationsLib.SecondaryAddressParams({
            unifiedId: _unifiedId,
            secondaryAddress: _secondaryAddress,
            primarySignature: "", // Not used for remove operations
            secondarySignature: "", // Not used for remove operations
            signature: _signature,
            nonce: _nonce,
            timestamp: _timestamp,
            chainId: chainId
        });
        
        RegistrarOperationsLib.ContractRefs memory contracts = RegistrarOperationsLib.ContractRefs({
            util: util,
            resolver: resolver
        });
        
        return RegistrarOperationsLib.completeRemoveSecondaryAddress(
            params,
            contracts,
            userAddresses,
            usedNonces
        );
    }

    // === VIEW FUNCTIONS ===
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
        return RegistrarOperationsLib.resolveSecondaryAddressToUnifiedId(resolver, secondaryAddr, chainId);
    }

    function resolveAnyAddressToUnifiedId(address addr) external view returns (
        string memory unifiedId,
        bool isPrimary,
        bool isSecondary
    ) {
        return RegistrarOperationsLib.resolveAnyAddressToUnifiedId(resolver, addr, chainId);
    }

    // ==================== COMBINED ADDRESS FUNCTIONS ====================

    function getAllAddresses(string calldata unifiedId) external view returns (address[] memory allAddresses) {
        return RegistrarOperationsLib.getAllAddresses(resolver, unifiedId, chainId);
    }

    function getAddressCount(string calldata unifiedId) external view returns (uint256 count) {
        return RegistrarOperationsLib.getAddressCount(resolver, unifiedId, chainId);
    }

    function hasMultipleAddresses(string calldata unifiedId) external view returns (bool hasMultiple) {
        return RegistrarOperationsLib.getAddressCount(resolver, unifiedId, chainId) > 1;
    }

    // ==================== ROLE MANAGEMENT FUNCTIONS ====================

    function grantRelayerRole(address relayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RegistrarOperationsLib.grantRelayerRole(this, relayer, RELAYER_ROLE);
        emit RegistrarAction(relayer, "grant_relayer", msg.sender);
    }

    function revokeRelayerRole(address relayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RegistrarOperationsLib.revokeRelayerRole(this, relayer, RELAYER_ROLE);
        emit RegistrarAction(relayer, "revoke_relayer", msg.sender);
    }

    function grantRegistrarRole(address registrar) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RegistrarOperationsLib.grantRegistrarRole(this, registrar, REGISTRAR_ROLE);
    }

    function revokeRegistrarRole(address registrar) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RegistrarOperationsLib.revokeRegistrarRole(this, registrar, REGISTRAR_ROLE);
    }

    function grantAdminRole(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RegistrarOperationsLib.grantAdminRole(this, admin, ADMIN_ROLE);
    }

    function revokeAdminRole(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RegistrarOperationsLib.revokeAdminRole(this, admin, ADMIN_ROLE);
    }

    function grantEmergencyRole(address emergency) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RegistrarOperationsLib.grantEmergencyRole(this, emergency, EMERGENCY_ROLE);
    }

    function revokeEmergencyRole(address emergency) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RegistrarOperationsLib.revokeEmergencyRole(this, emergency, EMERGENCY_ROLE);
    }

    function grantUpgraderRole(address upgrader) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RegistrarOperationsLib.grantUpgraderRole(this, upgrader, UPGRADER_ROLE);
    }

    function revokeUpgraderRole(address upgrader) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RegistrarOperationsLib.revokeUpgraderRole(this, upgrader, UPGRADER_ROLE);
    }

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
        config.maxSecondaryAddresses = uint128(_maxSecondaryAddresses);
        _emitConfigUpdate();
    }

    function setRegistrarRegistrationPermission(bool _enabled) external onlyRole(ADMIN_ROLE) {
        config.publicRegistrarRegistration = _enabled;
        _emitConfigUpdate();
    }

    function setEmergencyMode(bool _enabled) external onlyRole(EMERGENCY_ROLE) {
        config.emergencyMode = _enabled;
        _emitConfigUpdate();
    }

    function setUnifiedIdLengthLimits(uint256 _minLength, uint256 _maxLength) external onlyRole(ADMIN_ROLE) {
        if (_minLength == 0 || _maxLength <= _minLength) revert E39();
        config.minUnifiedIdLength = uint64(_minLength);
        config.maxUnifiedIdLength = uint64(_maxLength);
        _emitConfigUpdate();
    }

    function _emitConfigUpdate() private {
        emit ConfigUpdated(config.maxSecondaryAddresses, config.publicRegistrarRegistration, config.emergencyMode, config.minUnifiedIdLength, config.maxUnifiedIdLength);
    }

    function emergencyMarkUnavailable(string calldata _unifiedId) external onlyEmergency {
        unavailableUnifiedIds[_unifiedId] = true;
        emit RegistrarAction(address(0), "mark_unavailable", msg.sender);
    }

    function emergencyMarkAvailable(string calldata _unifiedId) external onlyEmergency {
        unavailableUnifiedIds[_unifiedId] = false;
        emit RegistrarAction(address(0), "mark_available", msg.sender);
    }

    function emergencyRemoveRegistrar(address _registrarAddress) external onlyEmergency {
        if (!hasRole(REGISTRAR_ROLE, _registrarAddress)) revert E40();

        string memory registrarName = getRegistrarName(_registrarAddress);
        _revokeRole(REGISTRAR_ROLE, _registrarAddress);
        registrarNameToAddress[registrarName] = address(0);
        delete registrarNameToAddress[registrarName];

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

        emit RegistrarAction(_registrarAddress, "emergency_remove", msg.sender);
    }

    function getConfiguration() external view returns (uint256, bool, bool, uint256, uint256) {
        return (config.maxSecondaryAddresses, config.publicRegistrarRegistration, config.emergencyMode, config.minUnifiedIdLength, config.maxUnifiedIdLength);
    }

    function getAllRegistrars() external view returns (address[] memory) {
        return registrarAddresses;
    }

    function getAllRegistrarsWithNames() external view returns (address[] memory, string[] memory) {
        return (registrarAddresses, registrarNames);
    }

    function getTotalRegistrars() external view returns (uint256) {
        return registrarAddresses.length;
    }

    function getRegistrarInfo(address _address) external view returns (bool, string memory, uint8) {
        return RegistrarOperationsLib.getRegistrarInfo(this, registrarAddresses, registrarNames, totalRegistrarUpdates, _address, REGISTRAR_ROLE);
    }

    receive() external payable {}
    fallback() external payable {}

    function withdrawEth(address payable to, uint256 amount) external onlyOwner whenNotPaused {
        if (to == address(0)) revert E41();
        if (amount > address(this).balance) revert E42();

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert E43();

        emit WithdrawalExecuted(address(0), to, amount);
    }

    function withdrawERC20(address token, address to, uint256 amount) external onlyOwner whenNotPaused {
        if (token == address(0)) revert E44();
        if (to == address(0)) revert E41();

        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert E45();

        emit WithdrawalExecuted(token, to, amount);
    }

    // === HELPER FUNCTIONS ===

    function getRegistrarName(address _address) public view returns (string memory) {
        return RegistrarOperationsLib.getRegistrarName(registrarAddresses, registrarNames, _address);
    }

    function isAddressTaken(address _address) public view returns (bool) {
        return RegistrarOperationsLib.isAddressTaken(registrarAddresses, _address);
    }
}