// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import "./RegistrarStorageUtil.sol";
import "./IUnifiedIdResolver.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title RegistrarStorageChildEvents
 * @author kunalmkv
 * @notice Chain-specific unified ID management contract with comprehensive event tracking
 * @dev Handles unified ID registration, updates, and address management for a specific blockchain
 * @dev Implements registrar management, admin controls, and emergency functions
 * @dev Uses UUPS upgradeable pattern with two-step ownership and pause functionality
 */
contract RegistrarStorageChildEvents is Initializable, UUPSUpgradeable {

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // === OWNABLE2STEP IMPLEMENTATION ===
    address private _owner;
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() external {
        address sender = msg.sender;
        require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
        _transferOwnership(sender);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        delete _pendingOwner;
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @notice Structure containing user data for a unified ID on this chain
     * @param primary Primary address associated with the unified ID
     * @param isSecondary Mapping to check if an address is a secondary address
     * @param secondaries Array of secondary addresses
     * @param exists Whether the unified ID exists/is registered
     */
    struct UserData {
        address primary;
        mapping(address => bool) isSecondary;
        address[] secondaries;
        bool exists;
    }
    
    /**
     * @notice Structure containing registrar information
     * @param isRegistered Whether the registrar is currently registered
     * @param registrarName Name of the registrar
     * @param registrarAddress Address of the registrar
     */
    struct Registrar {
        bool isRegistered;
        string registrarName;
        address registrarAddress;
    }

    /// @notice Whether registration operations are currently paused
    bool public isPaused;
    
    /// @notice Total number of unified IDs registered (legacy counter)
    uint256 public totalUnifiedIdRegistered;
    
    /// @notice Utility contract for validation and signature verification
    RegistrarStorageUtil public util;
    
    /// @notice Resolver contract for address<->UnifiedId mappings
    IUnifiedIdResolver public resolver;
    
    /// @notice Current chain ID for this contract instance
    uint256 public chainId;
    
    /// @notice Mapping of authorized relayer addresses
    mapping(address => bool) public authorizedRelayers;
    
    /// @notice Mapping to track if an address is already registered as a registrar
    mapping(address => bool) public isRegistrarAlreadyRegistered;
    
    /// @notice Mapping from registrar address to registrar name
    mapping(address => string) public registrarNames;
    
    /// @notice Mapping from registrar name to registrar address
    mapping(string => address) public registrarNameToAddress;
    
    /// @notice Mapping to track number of updates per registrar
    mapping(address => uint8) public totalRegistrarUpdates;
    
    /// @notice Array of all registered registrar addresses
    address[] public registrarAddresses;
    
    /// @notice Mapping from unified ID to user data (private for security)
    mapping(string => UserData) private userAddresses;
    
    /// @notice Mapping of unified IDs that are permanently unavailable
    mapping(string => bool) public unavailableUnifiedIds;
    
    /// @notice Mapping to track which unified IDs are registered
    mapping(string => bool) public registeredUnifiedIds;
    
    /// @notice Total count of registered unified IDs
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
    event UnifiedIdLengthLimitsUpdated(uint256 minLength, uint256 maxLength);

    // === MISSING CRITICAL EVENTS ===
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

    // Events for withdrawal
    event EthWithdrawn(address indexed to, uint256 amount);
    event ERC20Withdrawn(address indexed token, address indexed to, uint256 amount);

    /**
     * @notice Modifier to ensure a unified ID exists
     * @dev Reverts if the unified ID has not been registered
     * @param _unifiedId The unified ID to check
     */
    modifier unifiedIdExists(string calldata _unifiedId) {
        require(userAddresses[_unifiedId].exists, "UnifiedID does not exist");
        _;
    }
    
    /**
     * @notice Modifier to ensure contract is not paused
     * @dev Reverts if the contract is in paused state
     */
    modifier whenNotPaused() {
        require(!isPaused, "Contract is Paused");
        _;
    }
    
    /**
     * @notice Modifier to ensure a unified ID does not exist and is available
     * @dev Reverts if the unified ID already exists or is marked as unavailable
     * @param _unifiedId The unified ID to check
     */
    modifier unifiedIdDoesNotExist(string calldata _unifiedId) {
        require(!userAddresses[_unifiedId].exists, "UnifiedID already exists");
        require(!unavailableUnifiedIds[_unifiedId], "UnifiedID not available");
        _;
    }
    
    /**
     * @notice Modifier to validate registrar name availability
     * @dev Ensures the registrar name is not taken by another registrar or unified ID
     * @param _registrarName The registrar name to validate
     */
    modifier validateRegistrarName(string memory _registrarName) {
        require(registrarNameToAddress[_registrarName] == address(0x0), "Registrar name is already taken.");
        require(
            resolveAddressFromUnifiedId[_registrarName] == address(0x0),
            "This Registrar name is already registered as a UnifiedID."
        );
        _;
    }
    
    /**
     * @notice Modifier to restrict access to registered registrars only
     * @dev Reverts if caller is not a registered registrar
     */
    modifier onlyRegistrar() {
        require(isRegistrarAlreadyRegistered[msg.sender], "Caller not a registrar");
        _;
    }
    
    /**
     * @notice Modifier to restrict access to authorized relayers only
     * @dev Reverts if caller is not an authorized relayer
     */
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

    function initialize(address _RegistrarStorageUtil, address _resolver, uint256 _chainId) public initializer {
        __UUPSUpgradeable_init();
        
        // Initialize ownership
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        
        util = RegistrarStorageUtil(_RegistrarStorageUtil);
        resolver = IUnifiedIdResolver(_resolver);
        chainId = _chainId;

        // === ADMIN DEFAULTS ===
        maxSecondaryAddresses = 10;
        publicRegistrarRegistration = false;
        emergencyMode = false;
        adminUsers[msg.sender] = true;
        maxUnifiedIdLength = 16;
        minUnifiedIdLength = 4;
    }

    /**
     * @notice Sets the utility contract implementation address
     * @dev Updates the address of the RegistrarStorageUtil contract used for validation and signature verification
     * @param _RegistrarStorageUtil Address of the new utility contract
     * @custom:requirements
     * - Only owner can call this function
     * - _RegistrarStorageUtil cannot be zero address
     * @custom:events Emits UtilImplementationUpdated
     */
    function setUtilImplementation(address _RegistrarStorageUtil) external onlyOwner {
        require(_RegistrarStorageUtil != address(0), "Util implementation: zero address");
        address oldUtil = address(util);
        util = RegistrarStorageUtil(_RegistrarStorageUtil);
        emit UtilImplementationUpdated(oldUtil, _RegistrarStorageUtil, msg.sender);
    }

    /**
     * @notice Sets the resolver contract address
     * @dev Updates the address of the UnifiedIdResolver contract used for address mappings
     * @param _resolver Address of the new resolver contract
     * @custom:requirements
     * - Only owner can call this function
     * - _resolver cannot be zero address
     * @custom:events Emits ResolverUpdated
     */
    function setResolver(address _resolver) external onlyOwner {
        require(_resolver != address(0), "Resolver: zero address");
        address oldResolver = address(resolver);
        resolver = IUnifiedIdResolver(_resolver);
        emit ResolverUpdated(oldResolver, _resolver, msg.sender);
    }

    /**
     * @notice Sets the chain ID for this contract instance
     * @dev Updates the chain ID used for cross-chain operations and resolver integration
     * @param _chainId New chain ID to set
     * @custom:requirements Only owner can call this function
     * @custom:events Emits ChainIdUpdated
     */
    function setChainId(uint256 _chainId) external onlyOwner {
        uint256 oldChainId = chainId;
        chainId = _chainId;
        emit ChainIdUpdated(oldChainId, _chainId, msg.sender);
    }

    /**
     * @notice Sets authorization status for a relayer address
     * @dev Grants or revokes permission for an address to act as an authorized relayer
     * @param _relayer Address to set authorization for
     * @param authorized True to authorize, false to revoke authorization
     * @custom:requirements
     * - Only owner can call this function
     * - _relayer cannot be zero address
     * @custom:events Emits AuthorizedRelayerUpdated
     */
    function setAuthorizedRelayer(address _relayer, bool authorized) external onlyOwner {
        require(_relayer != address(0), "Relayer: zero address");
        authorizedRelayers[_relayer] = authorized;
        emit AuthorizedRelayerUpdated(_relayer, authorized, msg.sender);
    }

    function registerRegistrar(
        string calldata _registrarName,
        address _registrarAddress
    ) external payable whenNotPaused validateRegistrarName(_registrarName) publicRegistrarAllowed notInEmergencyMode returns (bool) {
        require(_registrarAddress != address(0), "Registrar address: zero address");
        require(!isAddressTaken[_registrarAddress], "This address is already registered.");
        registrarNameToAddress[_registrarName] = _registrarAddress;
        registrarNames[_registrarAddress] = _registrarName;
        isRegistrarAlreadyRegistered[_registrarAddress] = true;
        isAddressTaken[_registrarAddress] = true;
        registrarAddresses.push(_registrarAddress);
        emit RegistrarRegistered(_registrarAddress, _registrarName);
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
        require(util.isUnifiedIdValid(_unifiedId), "Invalid UnifiedId format");
        require(!userAddresses[_unifiedId].exists, "UnifiedID already exists");
        require(!unavailableUnifiedIds[_unifiedId], "UnifiedID not available");
        require(registrarNameToAddress[_unifiedId] == address(0x0), "This UnifiedId is taken by a Registrar.");
        require(resolveAddressFromUnifiedId[_unifiedId] == address(0x0), "This UnifiedId is already registered.");
        emit RegisterUnifiedIdInitiated(_unifiedId, _primaryAddress, _masterSignature, _primarySignature, _options);
        return true;
    }

    // Add nonce tracking for replay protection
    mapping(string => mapping(uint256 => bool)) public usedNonces;

    function completeRegisterUnifiedId(
        string calldata _unifiedId,
        address _primaryAddress,
        bytes calldata _masterSignature,
        bytes calldata _primarySignature,
        uint256 _nonce,
        uint256 _timestamp
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        // 1. Verify timestamp is recent
        require(block.timestamp <= _timestamp + 1 hours, "Operation expired");

        // 2. Verify nonce hasn't been used
        require(!usedNonces[_unifiedId][_nonce], "Nonce already used");

        // 3. Construct message that was signed
        bytes memory message = abi.encode(
            "REGISTER_UNIFIED_ID",
            _unifiedId,
            _primaryAddress,
            chainId,
            _nonce,
            _timestamp
        );

        // 4. Verify signatures
        require(
            util.verifySignature(message, _primaryAddress, _primarySignature),
            "Invalid primary signature"
        );

        // 5. If not first registration, verify master signature
        if (bytes(_masterSignature).length != 0) {
            // This should get the master address from the Mother contract if available
            // For now, we'll assume primary is the master for new registrations
            require(
                util.verifySignature(message, _primaryAddress, _masterSignature),
                "Invalid master signature"
            );
        }

        // 6. Mark nonce as used
        usedNonces[_unifiedId][_nonce] = true;

        // 7. Then proceed with registration
        UserData storage userData = userAddresses[_unifiedId];
        userData.primary = _primaryAddress;
        userData.exists = true;
        resolveAddressFromUnifiedId[_unifiedId] = _primaryAddress;
        resolveUnifiedIdFromAddress[_primaryAddress] = _unifiedId;
        registeredUnifiedIds[_unifiedId] = true;
        totalRegisteredUnifiedIds++;
        unavailableUnifiedIds[_unifiedId] = true;
        totalUnifiedIdRegistered++;

        // Update resolver with unified ID registration
        resolver.setUnifiedIdPrimaryAddress(_unifiedId, chainId, _primaryAddress);

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
        require(util.isUnifiedIdValid(_newUnifiedId), "Invalid new UnifiedId format");
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
        require(registeredUnifiedIds[_oldUnifiedId], "Old UnifiedID not found");
        require(!registeredUnifiedIds[_newUnifiedId], "New UnifiedID already exists");

        // Get the current primary address
        UserData storage userData = userAddresses[_oldUnifiedId];
        address currentPrimary = userData.primary;

        // 1. Verify timestamp is recent
        require(block.timestamp <= _timestamp + 1 hours, "Operation expired");

        // 2. Verify nonce hasn't been used
        require(!usedNonces[_oldUnifiedId][_nonce], "Nonce already used");

        // 3. Construct message that was signed
        bytes memory message = abi.encode(
            "UPDATE_UNIFIED_ID",
            _oldUnifiedId,
            _newUnifiedId,
            chainId,
            _nonce,
            _timestamp
        );

        // 4. Verify signature from current primary address
        require(
            util.verifySignature(message, currentPrimary, _signature),
            "Invalid signature"
        );

        // 5. Mark nonce as used
        usedNonces[_oldUnifiedId][_nonce] = true;

        // 6. Proceed with the update using the existing userData and currentPrimary
        address primaryAddress = currentPrimary;

        // Update address mappings
        resolveAddressFromUnifiedId[_newUnifiedId] = primaryAddress;
        delete resolveAddressFromUnifiedId[_oldUnifiedId];
        resolveUnifiedIdFromAddress[primaryAddress] = _newUnifiedId;

        // Copy user data to new unified ID
        UserData storage newUserData = userAddresses[_newUnifiedId];
        newUserData.primary = primaryAddress;
        newUserData.exists = true;

        // Update resolver - clear old mappings and set new ones
        resolver.clearUnifiedIdMappings(_oldUnifiedId, chainId);
        resolver.setUnifiedIdPrimaryAddress(_newUnifiedId, chainId, primaryAddress);

        // Copy secondary addresses
        for (uint i = 0; i < userData.secondaries.length; ++i) {
            address secondaryAddr = userData.secondaries[i];

            // Additional safety check (though source data should already be clean)
            require(!newUserData.isSecondary[secondaryAddr], "Duplicate secondary address in source data");

            newUserData.isSecondary[secondaryAddr] = true;
            newUserData.secondaries.push(secondaryAddr);

            // Update resolver with secondary address
            resolver.addUnifiedIdSecondaryAddress(_newUnifiedId, chainId, secondaryAddr);
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
        address _newPrimaryAddress,
        bytes calldata _currentPrimarySignature,
        bytes calldata _newPrimarySignature,
        uint256 _nonce,
        uint256 _timestamp
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        UserData storage userData = userAddresses[_unifiedId];
        address oldPrimary = userData.primary;

        // 1. Verify timestamp is recent
        require(block.timestamp <= _timestamp + 1 hours, "Operation expired");

        // 2. Verify nonce hasn't been used
        require(!usedNonces[_unifiedId][_nonce], "Nonce already used");

        // 3. Construct message that was signed
        bytes memory message = abi.encode(
            "UPDATE_PRIMARY_ADDRESS",
            _unifiedId,
            _newPrimaryAddress,
            chainId,
            _nonce,
            _timestamp
        );

        // 4. Verify signatures
        require(
            util.verifySignature(message, oldPrimary, _currentPrimarySignature),
            "Invalid current primary signature"
        );

        require(
            util.verifySignature(message, _newPrimaryAddress, _newPrimarySignature),
            "Invalid new primary signature"
        );

        // 5. Mark nonce as used
        usedNonces[_unifiedId][_nonce] = true;
        userData.primary = _newPrimaryAddress;
        resolveAddressFromUnifiedId[_unifiedId] = _newPrimaryAddress;
        resolveUnifiedIdFromAddress[_newPrimaryAddress] = _unifiedId;
        resolveUnifiedIdFromAddress[oldPrimary] = "";

        // Update resolver with new primary address
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

        // Prevent adding primary address as secondary
        require(userData.primary != _secondaryAddress, "Cannot add primary address as secondary");

        // Check if already added as secondary
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
        address _secondaryAddress,
        bytes calldata _primarySignature,
        bytes calldata _secondarySignature,
        uint256 _nonce,
        uint256 _timestamp
    ) external whenNotPaused onlyAuthorizedRelayer returns (bool) {
        UserData storage userData = userAddresses[_unifiedId];

        // Prevent adding primary address as secondary
        require(userData.primary != _secondaryAddress, "Cannot add primary address as secondary");

        // Check if already added as secondary
        require(!userData.isSecondary[_secondaryAddress], "Secondary address already added");

        // 1. Verify timestamp is recent
        require(block.timestamp <= _timestamp + 1 hours, "Operation expired");

        // 2. Verify nonce hasn't been used
        require(!usedNonces[_unifiedId][_nonce], "Nonce already used");

        // 3. Construct message that was signed
        bytes memory message = abi.encode(
            "ADD_SECONDARY_ADDRESS",
            _unifiedId,
            _secondaryAddress,
            chainId,
            _nonce,
            _timestamp
        );

        // 4. Verify signatures
        require(
            util.verifySignature(message, userData.primary, _primarySignature),
            "Invalid primary signature"
        );

        require(
            util.verifySignature(message, _secondaryAddress, _secondarySignature),
            "Invalid secondary signature"
        );

        // 5. Mark nonce as used
        usedNonces[_unifiedId][_nonce] = true;

        userData.isSecondary[_secondaryAddress] = true;
        userData.secondaries.push(_secondaryAddress);

        // Update resolver with secondary address
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

        // 1. Verify timestamp is recent
        require(block.timestamp <= _timestamp + 1 hours, "Operation expired");

        // 2. Verify nonce hasn't been used
        require(!usedNonces[_unifiedId][_nonce], "Nonce already used");

        // 3. Construct message that was signed
        bytes memory message = abi.encode(
            "REMOVE_SECONDARY_ADDRESS",
            _unifiedId,
            _secondaryAddress,
            chainId,
            _nonce,
            _timestamp
        );

        // 4. Verify signature from primary address
        require(
            util.verifySignature(message, userData.primary, _signature),
            "Invalid signature"
        );

        // 5. Mark nonce as used
        usedNonces[_unifiedId][_nonce] = true;

        userData.isSecondary[_secondaryAddress] = false;
        for (uint i = 0; i < userData.secondaries.length; ++i) {
            if (userData.secondaries[i] == _secondaryAddress) {
                userData.secondaries[i] = userData.secondaries[userData.secondaries.length - 1];
                userData.secondaries.pop();
                break;
            }
        }

        // Update resolver to remove secondary address
        resolver.removeUnifiedIdSecondaryAddress(_unifiedId, chainId, _secondaryAddress);

        emit SecondaryAddressRemoved(_unifiedId, _secondaryAddress);
        return true;
    }

    /**
     * @notice Checks if an address is the primary address for a unified ID
     * @dev Returns whether the given address is registered as the primary address for the unified ID
     * @param _unifiedId The unified ID to check
     * @param _address The address to verify
     * @return True if the address is the primary address for the unified ID
     */
    function isPrimaryAddress(string calldata _unifiedId, address _address) external view returns (bool) {
        return userAddresses[_unifiedId].primary == _address;
    }

    /**
     * @notice Checks if an address is a secondary address for a unified ID
     * @dev Returns whether the given address is registered as a secondary address for the unified ID
     * @param _unifiedId The unified ID to check
     * @param _address The address to verify
     * @return True if the address is a secondary address for the unified ID
     */
    function isSecondaryAddress(string calldata _unifiedId, address _address) external view returns (bool) {
        return userAddresses[_unifiedId].isSecondary[_address];
    }

    /**
     * @notice Gets the primary address for a unified ID
     * @dev Returns the primary address associated with the unified ID on this chain
     * @param _unifiedId The unified ID to query
     * @return The primary address for the unified ID
     */
    function getPrimaryAddress(string calldata _unifiedId) external view returns (address) {
        return userAddresses[_unifiedId].primary;
    }

    /**
     * @notice Gets all secondary addresses for a unified ID
     * @dev Returns an array of all secondary addresses associated with the unified ID on this chain
     * @param _unifiedId The unified ID to query
     * @return Array of secondary addresses
     */
    function getSecondaryAddresses(string calldata _unifiedId) external view returns (address[] memory) {
        return userAddresses[_unifiedId].secondaries;
    }

    /**
     * @notice Checks if a unified ID is registered
     * @dev Returns whether the unified ID has been registered on this chain
     * @param unifiedId The unified ID to check
     * @return True if the unified ID is registered
     */
    function isRegisteredUnifiedId(string calldata unifiedId) external view returns (bool) {
        return registeredUnifiedIds[unifiedId];
    }

    /**
     * @notice Gets the total number of registered unified IDs
     * @dev Returns the count of all unified IDs registered on this chain
     * @return Total number of registered unified IDs
     */
    function getTotalRegisteredUnifiedIds() external view returns (uint256) {
        return totalRegisteredUnifiedIds;
    }

    // === RESOLVER INTEGRATION FUNCTIONS ===

    /**
     * @notice Get unified ID from address via resolver
     * @param addr Address to lookup
     * @return Unified ID associated with the address on current chain
     */
    function resolveAddressToUnifiedId(address addr) external view returns (string memory) {
        return resolver.getUnifiedIdFromAddress(addr, chainId);
    }

    /**
     * @notice Get primary address for unified ID via resolver
     * @param unifiedId Unified ID to lookup
     * @return Primary address on current chain
     */
    function resolvePrimaryAddress(string calldata unifiedId) external view returns (address) {
        return resolver.getPrimaryAddress(unifiedId, chainId);
    }

    /**
     * @notice Get all addresses for unified ID via resolver
     * @param unifiedId Unified ID to lookup
     * @return primary Primary address
     * @return secondaries Array of secondary addresses
     */
    function resolveAllAddresses(string calldata unifiedId)
    external view returns (address primary, address[] memory secondaries) {
        return resolver.getAddresses(unifiedId, chainId);
    }

    /**
     * @notice Check if address is associated with unified ID via resolver
     * @param unifiedId Unified ID to check
     * @param addr Address to verify
     * @return isPrimary True if address is primary
     * @return isSecondary True if address is secondary
     */
    function resolveAddressAssociation(string calldata unifiedId, address addr)
    external view returns (bool isPrimary, bool isSecondary) {
        return resolver.isAddressAssociated(unifiedId, chainId, addr);
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
     * @notice Enable/disable registrar registration
     * @param _enabled True to enable public registration, false to restrict to admin only
     */
    function setRegistrarRegistrationPermission(bool _enabled) external onlyOwner {
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
     * @notice Set unified ID length limits
     * @param _minLength Minimum length for unified IDs
     * @param _maxLength Maximum length for unified IDs
     */
    function setUnifiedIdLengthLimits(uint256 _minLength, uint256 _maxLength) external onlyOwner {
        require(_minLength != 0 && _maxLength > _minLength, "Invalid length limits");
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
        emit EmergencyUnifiedIdMarked(_unifiedId, false, msg.sender);
    }

    /**
     * @notice Emergency function to mark unified ID as available
     * @param _unifiedId Unified ID to mark as available
     */
    function emergencyMarkAvailable(string calldata _unifiedId) external onlyAdmin {
        unavailableUnifiedIds[_unifiedId] = false;
        emit EmergencyUnifiedIdMarked(_unifiedId, true, msg.sender);
    }

    /**
     * @notice Emergency function to remove registrar
     * @param _registrarAddress Address of registrar to remove
     */
    function emergencyRemoveRegistrar(address _registrarAddress) external onlyAdmin {
        require(isRegistrarAlreadyRegistered[_registrarAddress], "Address is not a registrar");
        string memory registrarName = registrarNames[_registrarAddress];

        isRegistrarAlreadyRegistered[_registrarAddress] = false;
        isAddressTaken[_registrarAddress] = false;
        registrarNameToAddress[registrarName] = address(0);
        delete registrarNames[_registrarAddress];

        // Remove from registrarAddresses array
        for (uint i = 0; i < registrarAddresses.length; ++i) {
            if (registrarAddresses[i] == _registrarAddress) {
                registrarAddresses[i] = registrarAddresses[registrarAddresses.length - 1];
                registrarAddresses.pop();
                break;
            }
        }

        emit EmergencyRegistrarRemoved(_registrarAddress, registrarName, msg.sender);
    }



    /**
    * @notice Get contract configuration
 * @return _maxSecondaryAddresses The maximum number of secondary addresses allowed
 * @return _publicRegistrarRegistration Whether public registrar registration is enabled
 * @return _emergencyMode Whether the contract is in emergency mode
 * @return _minUnifiedIdLength The minimum length of a unified ID
 * @return _maxUnifiedIdLength The maximum length of a unified ID
 */
    function getConfiguration() external view returns (
        uint256 _maxSecondaryAddresses,
        bool _publicRegistrarRegistration,
        bool _emergencyMode,
        uint256 _minUnifiedIdLength,
        uint256 _maxUnifiedIdLength
    ) {
        return (
            maxSecondaryAddresses,
            publicRegistrarRegistration,
            emergencyMode,
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

        for (uint i = 0; i < length; ++i) {
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
            isRegistrarAlreadyRegistered[_address],
            registrarNames[_address],
            totalRegistrarUpdates[_address]
        );
    }

    // Receive function to accept ETH
    receive() external payable {}

    // Fallback function to accept ETH
    fallback() external payable {}

    /**
     * @notice Withdraw stuck ETH from the contract
     * @param to Address to send the ETH to
     * @param amount Amount of ETH to withdraw (in wei)
     */
    function withdrawEth(address payable to, uint256 amount) external onlyOwner whenNotPaused {
        require(to != address(0), "Cannot withdraw to zero address");
        require(amount <= address(this).balance, "Insufficient balance");
        
        // Transfer ETH to the specified address
        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH transfer failed");
        
        emit EthWithdrawn(to, amount);
    }

    /**
     * @notice Withdraw stuck ERC20 tokens from the contract
     * @param token Address of the ERC20 token
     * @param to Address to send the tokens to
     * @param amount Amount of tokens to withdraw
     */
    function withdrawERC20(address token, address to, uint256 amount) external onlyOwner whenNotPaused {
        require(token != address(0), "Invalid token address");
        require(to != address(0), "Cannot withdraw to zero address");
        
        // Transfer ERC20 tokens using the standard ERC20 transfer function
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ERC20 transfer failed");
        
        emit ERC20Withdrawn(token, to, amount);
    }
}