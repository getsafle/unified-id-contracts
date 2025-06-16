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
 * @notice Chain-specific unified ID management contract with comprehensive event tracking and role-based access control
 * @dev Optimized version with enum errors, gas optimizations, and OpenZeppelin AccessControl
 */
contract RegistrarStorageChildEvents is Initializable, UUPSUpgradeable, AccessControlUpgradeable {

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
    error E1(); // "Ownable: caller is not the owner"
    error E2(); // "Ownable: new owner is the zero address"
    error E3(); // "Ownable2Step: caller is not the new owner"
    error E4(); // "UnifiedID does not exist"
    error E5(); // "Contract is Paused"
    error E6(); // "UnifiedID already exists"
    error E7(); // "UnifiedID not available"
    error E8(); // "Registrar name is already taken."
    error E9(); // "This Registrar name is already registered as a UnifiedID."
    error E10(); // "Caller not a registrar"
    error E11(); // "Caller not authorized relayer"
    error E12(); // "Caller not admin or owner"
    error E13(); // "Contract in emergency mode"
    error E14(); // "Public registrar registration disabled"
    error E15(); // "Util implementation: zero address"
    error E16(); // "Resolver: zero address"
    error E17(); // "Relayer: zero address"
    error E18(); // "Registrar address: zero address"
    error E19(); // "This address is already registered."
    error E20(); // "Invalid UnifiedId format"
    error E21(); // "This UnifiedId is taken by a Registrar."
    error E22(); // "This UnifiedId is already registered."
    error E23(); // "Operation expired"
    error E24(); // "Nonce already used"
    error E25(); // "Invalid primary signature"
    error E26(); // "Invalid master signature"
    error E27(); // "Invalid new UnifiedId format"
    error E28(); // "Old UnifiedID not found"
    error E29(); // "New UnifiedID already exists"
    error E30(); // "Invalid signature"
    error E31(); // "Duplicate secondary address in source data"
    error E32(); // "Invalid current primary signature"
    error E33(); // "Invalid new primary signature"
    error E34(); // "Cannot add primary address as secondary"
    error E35(); // "Secondary address already added"
    error E36(); // "Maximum secondary addresses limit reached"
    error E37(); // "Invalid secondary signature"
    error E38(); // "User cannot be zero address"
    error E39(); // "Invalid length limits"
    error E40(); // "Address is not a registrar"
    error E41(); // "Cannot withdraw to zero address"
    error E42(); // "Insufficient balance"
    error E43(); // "ETH transfer failed"
    error E44(); // "Invalid token address"
    error E45(); // "ERC20 transfer failed"
    error E46(); // "Cannot update to same UnifiedId"
    error E47(); // "Cannot set same primary address"
    error E48(); // "Cannot set zero address as primary"

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
    // This saves one mapping while maintaining efficient access
    string[] public registrarNames;

    // === EVENTS (UNCHANGED) ===
    event MaxSecondaryAddressesUpdated(uint256 oldMax, uint256 newMax);
    event PublicRegistrarRegistrationToggled(bool enabled);
    event EmergencyModeToggled(bool enabled);
    event UnifiedIdLengthLimitsUpdated(uint256 minLength, uint256 maxLength);
    event UtilImplementationUpdated(address indexed oldUtil, address indexed newUtil, address indexed updatedBy);
    event ResolverUpdated(address indexed oldResolver, address indexed newResolver, address indexed updatedBy);
    event ChainIdUpdated(uint256 indexed oldChainId, uint256 indexed newChainId, address indexed updatedBy);
    event AuthorizedRelayerUpdated(address indexed relayer, bool authorized, address indexed updatedBy);
    event EmergencyUnifiedIdMarked(string indexed unifiedId, bool available, address indexed updatedBy);
    event EmergencyRegistrarRemoved(address indexed registrar, string registrarName, address indexed removedBy);
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
    event EthWithdrawn(address indexed to, uint256 amount);
    event ERC20Withdrawn(address indexed token, address indexed to, uint256 amount);

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
        address oldUtil = address(util);
        util = RegistrarStorageUtil(_RegistrarStorageUtil);
        emit UtilImplementationUpdated(oldUtil, _RegistrarStorageUtil, msg.sender);
    }

    function setResolver(address _resolver) external onlyRole(ADMIN_ROLE) {
        if (_resolver == address(0)) revert E16();
        address oldResolver = address(resolver);
        resolver = IUnifiedIdResolver(_resolver);
        emit ResolverUpdated(oldResolver, _resolver, msg.sender);
    }

    function setChainId(uint256 _chainId) external onlyRole(ADMIN_ROLE) {
        uint256 oldChainId = chainId;
        chainId = _chainId;
        emit ChainIdUpdated(oldChainId, _chainId, msg.sender);
    }

    function registerRegistrar(
        string calldata _registrarName,
        address _registrarAddress
    ) external payable whenNotPaused validateRegistrarName(_registrarName) publicRegistrarAllowed notInEmergencyMode returns (bool) {
        if (_registrarAddress == address(0)) revert E18();
        if (isAddressTaken(_registrarAddress)) revert E19();

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
        emit RegistrationPaused(msg.sender);
    }

    function unpauseRegistration() external onlyRole(ADMIN_ROLE) {
        config.isPaused = false;
        emit RegistrationUnpaused(msg.sender);
    }

    function initiateRegisterUnifiedId(
        string calldata _unifiedId,
        address _primaryAddress,
        bytes calldata _masterSignature,
        bytes calldata _primarySignature,
        bytes calldata _options
    ) external payable whenNotPaused onlyRegistrar returns (bool) {
        if (!util.isUnifiedIdValid(_unifiedId)) revert E20();
        if (userAddresses[_unifiedId].exists) revert E6();
        if (unavailableUnifiedIds[_unifiedId]) revert E7();
        if (registrarNameToAddress[_unifiedId] != address(0)) revert E21();
        if (resolveAddressFromUnifiedId[_unifiedId] != address(0)) revert E22();

        emit RegisterUnifiedIdInitiated(_unifiedId, _primaryAddress, _masterSignature, _primarySignature, _options);
        return true;
    }

    function completeRegisterUnifiedId(
        string calldata _unifiedId,
        address _primaryAddress,
        bytes calldata _masterSignature,
        bytes calldata _primarySignature,
        uint256 _nonce,
        uint256 _timestamp
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        if (block.timestamp > _timestamp + 1 hours) revert E23();
        if (usedNonces[_unifiedId][_nonce]) revert E24();

        bytes memory message = abi.encode(
            "REGISTER_UNIFIED_ID",
            _unifiedId,
            _primaryAddress,
            chainId,
            _nonce,
            _timestamp
        );

        if (!util.verifySignature(message, _primaryAddress, _primarySignature)) revert E25();

        if (_masterSignature.length != 0) {
            if (!util.verifySignature(message, _primaryAddress, _masterSignature)) revert E26();
        }

        usedNonces[_unifiedId][_nonce] = true;

        UserData storage userData = userAddresses[_unifiedId];
        userData.primary = _primaryAddress;
        userData.exists = true;

        resolveAddressFromUnifiedId[_unifiedId] = _primaryAddress;
        resolveUnifiedIdFromAddress[_primaryAddress] = _unifiedId;
        registeredUnifiedIds[_unifiedId] = true;
        totalRegisteredUnifiedIds++;
        unavailableUnifiedIds[_unifiedId] = true;
        totalUnifiedIdRegistered++;

        resolver.setUnifiedIdPrimaryAddress(_unifiedId, chainId, _primaryAddress);

        emit UnifiedIDRegistered(_unifiedId, _primaryAddress, block.timestamp);
        return true;
    }

    function initiateUpdateUnifiedId(
        string calldata _oldUnifiedId,
        string calldata _newUnifiedId,
        bytes calldata _signature,
        bytes calldata _options
    ) external payable whenNotPaused unifiedIdExists(_oldUnifiedId) unifiedIdDoesNotExist(_newUnifiedId) onlyRegistrar returns (bool) {
        if (!util.isUnifiedIdValid(_newUnifiedId)) revert E27();
        emit UpdateUnifiedIdInitiated(_oldUnifiedId, _newUnifiedId, _signature, _options);
        return true;
    }

    function completeUpdateUnifiedId(
        string memory _oldUnifiedId,
        string memory _newUnifiedId,
        bytes calldata _signature,
        uint256 _nonce,
        uint256 _timestamp
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        if (!registeredUnifiedIds[_oldUnifiedId]) revert E28();
        if (registeredUnifiedIds[_newUnifiedId]) revert E29();

        // EDGE CASE PROTECTION: Prevent updating to the same UnifiedId
        if (keccak256(bytes(_oldUnifiedId)) == keccak256(bytes(_newUnifiedId))) revert E46();

        UserData storage userData = userAddresses[_oldUnifiedId];
        address currentPrimary = userData.primary;

        if (block.timestamp > _timestamp + 1 hours) revert E23();
        if (usedNonces[_oldUnifiedId][_nonce]) revert E24();

        bytes memory message = abi.encode(
            "UPDATE_UNIFIED_ID",
            _oldUnifiedId,
            _newUnifiedId,
            chainId,
            _nonce,
            _timestamp
        );

        if (!util.verifySignature(message, currentPrimary, _signature)) revert E30();

        usedNonces[_oldUnifiedId][_nonce] = true;

        address primaryAddress = currentPrimary;

        resolveAddressFromUnifiedId[_newUnifiedId] = primaryAddress;
        delete resolveAddressFromUnifiedId[_oldUnifiedId];
        resolveUnifiedIdFromAddress[primaryAddress] = _newUnifiedId;

        UserData storage newUserData = userAddresses[_newUnifiedId];
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

        delete registeredUnifiedIds[_oldUnifiedId];
        registeredUnifiedIds[_newUnifiedId] = true;
        unavailableUnifiedIds[_oldUnifiedId] = true;
        unavailableUnifiedIds[_newUnifiedId] = true;
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
        address _newPrimaryAddress,
        bytes calldata _currentPrimarySignature,
        bytes calldata _newPrimarySignature,
        uint256 _nonce,
        uint256 _timestamp
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        UserData storage userData = userAddresses[_unifiedId];
        address oldPrimary = userData.primary;

        // EDGE CASE PROTECTION: Prevent setting the same primary address
        if (oldPrimary == _newPrimaryAddress) revert E47();

        // EDGE CASE PROTECTION: Prevent setting zero address as primary
        if (_newPrimaryAddress == address(0)) revert E48();

        if (block.timestamp > _timestamp + 1 hours) revert E23();
        if (usedNonces[_unifiedId][_nonce]) revert E24();

        bytes memory message = abi.encode(
            "UPDATE_PRIMARY_ADDRESS",
            _unifiedId,
            _newPrimaryAddress,
            chainId,
            _nonce,
            _timestamp
        );

        if (!util.verifySignature(message, oldPrimary, _currentPrimarySignature)) revert E32();
        if (!util.verifySignature(message, _newPrimaryAddress, _newPrimarySignature)) revert E33();

        usedNonces[_unifiedId][_nonce] = true;
        userData.primary = _newPrimaryAddress;
        resolveAddressFromUnifiedId[_unifiedId] = _newPrimaryAddress;
        resolveUnifiedIdFromAddress[_newPrimaryAddress] = _unifiedId;
        resolveUnifiedIdFromAddress[oldPrimary] = "";

        resolver.updateUnifiedIdPrimaryAddress(_unifiedId, chainId, _newPrimaryAddress);

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

        if (userData.primary == _secondaryAddress) revert E34();
        if (userData.isSecondary[_secondaryAddress]) revert E35();
        if (userData.secondaries.length >= config.maxSecondaryAddresses) revert E36();

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
        address _secondaryAddress,
        bytes calldata _primarySignature,
        bytes calldata _secondarySignature,
        uint256 _nonce,
        uint256 _timestamp
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        UserData storage userData = userAddresses[_unifiedId];

        if (userData.primary == _secondaryAddress) revert E34();
        if (userData.isSecondary[_secondaryAddress]) revert E35();
        if (block.timestamp > _timestamp + 1 hours) revert E23();
        if (usedNonces[_unifiedId][_nonce]) revert E24();

        bytes memory message = abi.encode(
            "ADD_SECONDARY_ADDRESS",
            _unifiedId,
            _secondaryAddress,
            chainId,
            _nonce,
            _timestamp
        );

        if (!util.verifySignature(message, userData.primary, _primarySignature)) revert E25();
        if (!util.verifySignature(message, _secondaryAddress, _secondarySignature)) revert E37();

        usedNonces[_unifiedId][_nonce] = true;
        userData.isSecondary[_secondaryAddress] = true;
        userData.secondaries.push(_secondaryAddress);

        resolver.addUnifiedIdSecondaryAddress(_unifiedId, chainId, _secondaryAddress);

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
        address _secondaryAddress,
        bytes calldata _signature,
        uint256 _nonce,
        uint256 _timestamp
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        UserData storage userData = userAddresses[_unifiedId];

        if (block.timestamp > _timestamp + 1 hours) revert E23();
        if (usedNonces[_unifiedId][_nonce]) revert E24();

        bytes memory message = abi.encode(
            "REMOVE_SECONDARY_ADDRESS",
            _unifiedId,
            _secondaryAddress,
            chainId,
            _nonce,
            _timestamp
        );

        if (!util.verifySignature(message, userData.primary, _signature)) revert E30();

        usedNonces[_unifiedId][_nonce] = true;
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

        emit SecondaryAddressRemoved(_unifiedId, _secondaryAddress);
        return true;
    }

    // === VIEW FUNCTIONS (UNCHANGED) ===
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

    /**
     * @notice Resolves a secondary address to its UnifiedId
     * @dev Finds which UnifiedId a secondary address belongs to on this chain
     * @param secondaryAddr The secondary address to resolve
     * @return The UnifiedId that the secondary address belongs to, empty string if not found
     * @custom:gas-optimization Uses resolver's optimized lookup
     */
    function resolveSecondaryAddressToUnifiedId(address secondaryAddr) external view returns (string memory) {
        return resolver.resolveSecondaryAddressToUnifiedId(secondaryAddr, chainId);
    }

    /**
     * @notice Resolves any address (primary or secondary) to its UnifiedId
     * @dev Universal address resolver that works for both primary and secondary addresses
     * @param addr The address to resolve (can be primary or secondary)
     * @return unifiedId The UnifiedId associated with the address
     * @return isPrimary True if the address is a primary address
     * @return isSecondary True if the address is a secondary address
     * @custom:gas-optimization Uses resolver's optimized lookup
     */
    function resolveAnyAddressToUnifiedId(address addr) external view returns (
        string memory unifiedId,
        bool isPrimary,
        bool isSecondary
    ) {
        return resolver.resolveAnyAddressToUnifiedId(addr, chainId);
    }

    // ==================== COMBINED ADDRESS FUNCTIONS ====================

    /**
     * @notice Gets all addresses (primary + secondary) for a UnifiedId in a single array
     * @dev Returns all addresses associated with the UnifiedId on this chain in one array
     * @param unifiedId The UnifiedId to get all addresses for
     * @return allAddresses Array containing primary address followed by all secondary addresses
     * @custom:gas-optimization Efficient single-call solution instead of multiple calls + concatenation
     * @custom:use-cases
     * - DApp integration for displaying all addresses
     * - Wallet interfaces showing complete address list
     * - Permission checking across all addresses
     * - Simplified iteration over all addresses
     * @custom:array-structure [primary, secondary1, secondary2, ...]
     */
    function getAllAddresses(string calldata unifiedId) external view returns (address[] memory allAddresses) {
        return resolver.getAllAddresses(unifiedId, chainId);
    }

    /**
     * @notice Gets the total count of addresses (primary + secondary) for a UnifiedId
     * @dev Returns the total number of addresses associated with the UnifiedId on this chain
     * @param unifiedId The UnifiedId to count addresses for
     * @return count Total number of addresses (1 primary + N secondary addresses)
     * @custom:gas-optimization Lightweight function for getting address count without array allocation
     * @custom:use-cases
     * - Pre-allocating arrays for address operations
     * - Checking if UnifiedId has multiple addresses
     * - Gas estimation for batch operations
     */
    function getAddressCount(string calldata unifiedId) external view returns (uint256 count) {
        return resolver.getAddressCount(unifiedId, chainId);
    }

    /**
     * @notice Checks if a UnifiedId has multiple addresses (more than just primary)
     * @dev Convenience function to check if UnifiedId has secondary addresses
     * @param unifiedId The UnifiedId to check
     * @return hasMultiple True if UnifiedId has secondary addresses in addition to primary
     * @custom:gas-optimization Uses address count instead of fetching full arrays
     */
    function hasMultipleAddresses(string calldata unifiedId) external view returns (bool hasMultiple) {
        return resolver.getAddressCount(unifiedId, chainId) > 1;
    }

    // ==================== ROLE MANAGEMENT FUNCTIONS ====================

    /**
     * @notice Grant relayer role to an address
     * @param relayer Address to grant relayer role
     */
    function grantRelayerRole(address relayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(RELAYER_ROLE, relayer);
        emit AuthorizedRelayerUpdated(relayer, true, msg.sender);
    }

    /**
     * @notice Revoke relayer role from an address
     * @param relayer Address to revoke relayer role
     */
    function revokeRelayerRole(address relayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(RELAYER_ROLE, relayer);
        emit AuthorizedRelayerUpdated(relayer, false, msg.sender);
    }

    /**
     * @notice Grant registrar role to an address
     * @param registrar Address to grant registrar role
     */
    function grantRegistrarRole(address registrar) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(REGISTRAR_ROLE, registrar);
    }

    /**
     * @notice Revoke registrar role from an address
     * @param registrar Address to revoke registrar role
     */
    function revokeRegistrarRole(address registrar) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(REGISTRAR_ROLE, registrar);
    }

    /**
     * @notice Grant admin role to an address
     * @param admin Address to grant admin role
     */
    function grantAdminRole(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, admin);
    }

    /**
     * @notice Revoke admin role from an address
     * @param admin Address to revoke admin role
     */
    function revokeAdminRole(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ADMIN_ROLE, admin);
    }

    /**
     * @notice Grant emergency role to an address
     * @param emergency Address to grant emergency role
     */
    function grantEmergencyRole(address emergency) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(EMERGENCY_ROLE, emergency);
    }

    /**
     * @notice Revoke emergency role from an address
     * @param emergency Address to revoke emergency role
     */
    function revokeEmergencyRole(address emergency) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(EMERGENCY_ROLE, emergency);
    }

    /**
     * @notice Grant upgrader role to an address
     * @param upgrader Address to grant upgrader role
     */
    function grantUpgraderRole(address upgrader) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    /**
     * @notice Revoke upgrader role from an address
     * @param upgrader Address to revoke upgrader role
     */
    function revokeUpgraderRole(address upgrader) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(UPGRADER_ROLE, upgrader);
    }

    /**
     * @notice Check if address has relayer role
     * @param account Address to check
     * @return True if address has relayer role
     */
    function isRelayer(address account) external view returns (bool) {
        return hasRole(RELAYER_ROLE, account);
    }

    /**
     * @notice Check if address has registrar role
     * @param account Address to check
     * @return True if address has registrar role
     */
    function isRegistrar(address account) external view returns (bool) {
        return hasRole(REGISTRAR_ROLE, account);
    }

    /**
     * @notice Check if address has admin role
     * @param account Address to check
     * @return True if address has admin role
     */
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    /**
     * @notice Check if address has emergency role
     * @param account Address to check
     * @return True if address has emergency role
     */
    function isEmergencyResponder(address account) external view returns (bool) {
        return hasRole(EMERGENCY_ROLE, account);
    }

    /**
     * @notice Check if address has upgrader role
     * @param account Address to check
     * @return True if address has upgrader role
     */
    function isUpgrader(address account) external view returns (bool) {
        return hasRole(UPGRADER_ROLE, account);
    }

    // === ADMIN FUNCTIONS ===
    function setMaxSecondaryAddresses(uint256 _maxSecondaryAddresses) external onlyRole(ADMIN_ROLE) {
        uint256 oldMax = config.maxSecondaryAddresses;
        config.maxSecondaryAddresses = uint128(_maxSecondaryAddresses);
        emit MaxSecondaryAddressesUpdated(oldMax, _maxSecondaryAddresses);
    }

    function setRegistrarRegistrationPermission(bool _enabled) external onlyRole(ADMIN_ROLE) {
        config.publicRegistrarRegistration = _enabled;
        emit PublicRegistrarRegistrationToggled(_enabled);
    }

    function setEmergencyMode(bool _enabled) external onlyRole(EMERGENCY_ROLE) {
        config.emergencyMode = _enabled;
        emit EmergencyModeToggled(_enabled);
    }

    function setUnifiedIdLengthLimits(uint256 _minLength, uint256 _maxLength) external onlyRole(ADMIN_ROLE) {
        if (_minLength == 0 || _maxLength <= _minLength) revert E39();
        config.minUnifiedIdLength = uint64(_minLength);
        config.maxUnifiedIdLength = uint64(_maxLength);
        emit UnifiedIdLengthLimitsUpdated(_minLength, _maxLength);
    }

    function emergencyMarkUnavailable(string calldata _unifiedId) external onlyEmergency {
        unavailableUnifiedIds[_unifiedId] = true;
        emit EmergencyUnifiedIdMarked(_unifiedId, false, msg.sender);
    }

    function emergencyMarkAvailable(string calldata _unifiedId) external onlyEmergency {
        unavailableUnifiedIds[_unifiedId] = false;
        emit EmergencyUnifiedIdMarked(_unifiedId, true, msg.sender);
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

        emit EmergencyRegistrarRemoved(_registrarAddress, registrarName, msg.sender);
    }

    function getConfiguration() external view returns (
        uint256 _maxSecondaryAddresses,
        bool _publicRegistrarRegistration,
        bool _emergencyMode,
        uint256 _minUnifiedIdLength,
        uint256 _maxUnifiedIdLength
    ) {
        return (
            config.maxSecondaryAddresses,
            config.publicRegistrarRegistration,
            config.emergencyMode,
            config.minUnifiedIdLength,
            config.maxUnifiedIdLength
        );
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

    function getRegistrarInfo(address _address) external view returns (
        bool isRegistrar,
        string memory registrarName,
        uint8 updateCount
    ) {
        return (
            hasRole(REGISTRAR_ROLE, _address),
            getRegistrarName(_address),
            totalRegistrarUpdates[_address]
        );
    }

    receive() external payable {}
    fallback() external payable {}

    function withdrawEth(address payable to, uint256 amount) external onlyOwner whenNotPaused {
        if (to == address(0)) revert E41();
        if (amount > address(this).balance) revert E42();

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert E43();

        emit EthWithdrawn(to, amount);
    }

    function withdrawERC20(address token, address to, uint256 amount) external onlyOwner whenNotPaused {
        if (token == address(0)) revert E44();
        if (to == address(0)) revert E41();

        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert E45();

        emit ERC20Withdrawn(token, to, amount);
    }

    // === HELPER FUNCTIONS FOR REMOVED MAPPINGS ===

    /**
     * @notice Get registrar name for an address (optimized with parallel arrays)
     * @param _address The registrar address
     * @return The registrar name, empty string if not found
     * @dev Uses parallel arrays instead of bidirectional mappings to save storage
     */
    function getRegistrarName(address _address) public view returns (string memory) {
        for (uint256 i = 0; i < registrarAddresses.length; i++) {
            if (registrarAddresses[i] == _address) {
                return registrarNames[i];
            }
        }
        return "";
    }

    /**
     * @notice Check if an address is taken by a registrar (replaces isAddressTaken mapping)
     * @param _address The address to check
     * @return True if address is taken by a registrar
     */
    function isAddressTaken(address _address) public view returns (bool) {
        // Check if address exists in registrarAddresses array
        for (uint256 i = 0; i < registrarAddresses.length; i++) {
            if (registrarAddresses[i] == _address) {
                return true;
            }
        }
        return false;
    }
}