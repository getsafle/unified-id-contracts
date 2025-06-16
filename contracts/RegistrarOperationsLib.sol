// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import "./RegistrarStorageUtil.sol";
import "./IUnifiedIdResolver.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title RegistrarOperationsLib
 * @author kunalmkv
 * @notice Comprehensive library combining all registrar operations for unified ID management
 * @dev Combines UnifiedId operations, address operations, and utility functions in a single library
 * @dev Optimized for gas efficiency and maintainability while reducing contract bytecode size
 */
library RegistrarOperationsLib {
    
    // ==================== COMPREHENSIVE ERROR DEFINITIONS ====================
    
    // UnifiedId and General Errors
    error E4(); // "UnifiedID does not exist"
    error E6(); // "UnifiedID already exists"
    error E7(); // "UnifiedID not available"
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
    error E46(); // "Cannot update to same UnifiedId"
    
    // Address Operation Errors
    error E32(); // "Invalid current primary signature"
    error E33(); // "Invalid new primary signature"
    error E34(); // "Cannot add primary address as secondary"
    error E35(); // "Secondary address already added"
    error E36(); // "Maximum secondary addresses limit reached"
    error E37(); // "Invalid secondary signature"
    error E47(); // "Cannot set same primary address"
    error E48(); // "Cannot set zero address as primary"

    // ==================== COMPREHENSIVE EVENT DEFINITIONS ====================
    
    // UnifiedId Operation Events
    event UnifiedIDRegistered(string indexed unifiedId, address indexed primary, uint256 timestamp);
    event UnifiedIDChanged(string indexed oldUnifiedId, string indexed newUnifiedId, address indexed primary, uint256 timestamp);
    event RegisterUnifiedIdInitiated(string unifiedId, address primaryAddress, bytes masterSignature, bytes primarySignature, bytes options);
    event UpdateUnifiedIdInitiated(string oldUnifiedId, string newUnifiedId, bytes signature, bytes options);
    
    // Address Operation Events
    event UnifiedIDUpdated(string indexed unifiedId, address indexed oldPrimary, address indexed newPrimary);
    event SecondaryAddressAdded(string unifiedId, address secondary);
    event SecondaryAddressRemoved(string unifiedId, address secondary);
    event UpdateUnifiedIdPrimaryAddressInitiated(string unifiedId, address newPrimaryAddress, bytes currentPrimarySignature, bytes newPrimarySignature, bytes options);
    event AddSecondaryAddressInitiated(string unifiedId, address secondaryAddress, bytes primarySignature, bytes secondarySignature, bytes options);
    event RemoveSecondaryAddressInitiated(string unifiedId, address secondaryAddress, bytes signature, bytes options);

    // ==================== STRUCT DEFINITIONS ====================
    
    /**
     * @notice User data structure for managing UnifiedId associations
     * @param primary Primary address for the UnifiedId
     * @param isSecondary Mapping to check if address is secondary
     * @param secondaries Array of secondary addresses
     * @param exists Flag to indicate if UnifiedId exists
     */
    struct UserData {
        address primary;
        mapping(address => bool) isSecondary;
        address[] secondaries;
        bool exists;
    }

    /**
     * @notice Packed configuration structure for gas optimization
     * @param maxSecondaryAddresses Maximum allowed secondary addresses
     * @param minUnifiedIdLength Minimum UnifiedId length
     * @param maxUnifiedIdLength Maximum UnifiedId length
     * @param isPaused Contract pause status
     * @param publicRegistrarRegistration Public registrar registration status
     * @param emergencyMode Emergency mode status
     */
    struct PackedConfig {
        uint128 maxSecondaryAddresses;
        uint64 minUnifiedIdLength;
        uint64 maxUnifiedIdLength;
        bool isPaused;
        bool publicRegistrarRegistration;
        bool emergencyMode;
    }

    /**
     * @notice Parameters for secondary address operations
     * @param unifiedId The UnifiedId to operate on
     * @param secondaryAddress The secondary address
     * @param primarySignature Primary address signature
     * @param secondarySignature Secondary address signature (for add operations)
     * @param signature General signature (for remove operations)
     * @param nonce Nonce for replay protection
     * @param timestamp Timestamp for expiration check
     * @param chainId The chain ID
     */
    struct SecondaryAddressParams {
        string unifiedId;
        address secondaryAddress;
        bytes primarySignature;
        bytes secondarySignature;
        bytes signature;
        uint256 nonce;
        uint256 timestamp;
        uint256 chainId;
    }

    // ==================== FUNCTION PARAMETER STRUCTS ====================
    
    /**
     * @notice Parameters for registration completion
     * @param _unifiedId The UnifiedId to register
     * @param _primaryAddress The primary address for the UnifiedId
     * @param _masterSignature Master signature for verification
     * @param _primarySignature Primary address signature
     * @param _nonce Nonce for replay protection
     * @param _timestamp Timestamp for expiration check
     * @param chainId The chain ID
     */
    struct RegistrationParams {
        string unifiedId;
        address primaryAddress;
        bytes masterSignature;
        bytes primarySignature;
        uint256 nonce;
        uint256 timestamp;
        uint256 chainId;
    }

    /**
     * @notice Contract references for registration
     * @param util The utility contract instance
     * @param resolver The resolver contract instance
     */
    struct ContractRefs {
        RegistrarStorageUtil util;
        IUnifiedIdResolver resolver;
    }

    // ==================== UNIFIED ID REGISTRATION OPERATIONS ====================

    /**
     * @notice Initiates the UnifiedId registration process
     * @param _unifiedId The UnifiedId to register
     * @param _primaryAddress The primary address for the UnifiedId
     * @param _masterSignature Master signature for verification
     * @param _primarySignature Primary address signature
     * @param _options Additional options data
     * @param util The utility contract instance
     * @param userAddresses User data mapping
     * @param unavailableUnifiedIds Unavailable UnifiedIds mapping
     * @param registrarNameToAddress Registrar name to address mapping
     * @param resolveAddressFromUnifiedId Address resolution mapping
     * @return True if initiation successful
     */
    function initiateRegisterUnifiedId(
        string calldata _unifiedId,
        address _primaryAddress,
        bytes calldata _masterSignature,
        bytes calldata _primarySignature,
        bytes calldata _options,
        RegistrarStorageUtil util,
        mapping(string => UserData) storage userAddresses,
        mapping(string => bool) storage unavailableUnifiedIds,
        mapping(string => address) storage registrarNameToAddress,
        mapping(string => address) storage resolveAddressFromUnifiedId
    ) external returns (bool) {
        if (!util.isUnifiedIdValid(_unifiedId)) revert E20();
        if (userAddresses[_unifiedId].exists) revert E6();
        if (unavailableUnifiedIds[_unifiedId]) revert E7();
        if (registrarNameToAddress[_unifiedId] != address(0)) revert E21();
        if (resolveAddressFromUnifiedId[_unifiedId] != address(0)) revert E22();

        emit RegisterUnifiedIdInitiated(_unifiedId, _primaryAddress, _masterSignature, _primarySignature, _options);
        return true;
    }

    /**
     * @notice Completes the UnifiedId registration process
     * @param params Registration parameters
     * @param contracts Contract references
     * @param userAddresses User data mapping
     * @param usedNonces Used nonces mapping
     * @param resolveAddressFromUnifiedId Address resolution mapping
     * @param resolveUnifiedIdFromAddress Reverse resolution mapping
     * @param registeredUnifiedIds Registered UnifiedIds mapping
     * @param unavailableUnifiedIds Unavailable UnifiedIds mapping
     * @return True if registration successful
     */
    function completeRegisterUnifiedId(
        RegistrationParams calldata params,
        ContractRefs memory contracts,
        mapping(string => UserData) storage userAddresses,
        mapping(string => mapping(uint256 => bool)) storage usedNonces,
        mapping(string => address) storage resolveAddressFromUnifiedId,
        mapping(address => string) storage resolveUnifiedIdFromAddress,
        mapping(string => bool) storage registeredUnifiedIds,
        mapping(string => bool) storage unavailableUnifiedIds
    ) external returns (bool) {
        if (block.timestamp > params.timestamp + 1 hours) revert E23();
        if (usedNonces[params.unifiedId][params.nonce]) revert E24();

        bytes memory message = abi.encode(
            "REGISTER_UNIFIED_ID",
            params.unifiedId,
            params.primaryAddress,
            params.chainId,
            params.nonce,
            params.timestamp
        );

        if (!contracts.util.verifySignature(message, params.primaryAddress, params.primarySignature)) revert E25();

        if (params.masterSignature.length != 0) {
            if (!contracts.util.verifySignature(message, params.primaryAddress, params.masterSignature)) revert E26();
        }

        usedNonces[params.unifiedId][params.nonce] = true;

        UserData storage userData = userAddresses[params.unifiedId];
        userData.primary = params.primaryAddress;
        userData.exists = true;

        resolveAddressFromUnifiedId[params.unifiedId] = params.primaryAddress;
        resolveUnifiedIdFromAddress[params.primaryAddress] = params.unifiedId;
        registeredUnifiedIds[params.unifiedId] = true;
        unavailableUnifiedIds[params.unifiedId] = true;

        contracts.resolver.setUnifiedIdPrimaryAddress(params.unifiedId, params.chainId, params.primaryAddress);

        emit UnifiedIDRegistered(params.unifiedId, params.primaryAddress, block.timestamp);
        return true;
    }

    // ==================== UNIFIED ID UPDATE OPERATIONS ====================

    /**
     * @notice Initiates the UnifiedId update process
     * @param _oldUnifiedId The current UnifiedId
     * @param _newUnifiedId The new UnifiedId
     * @param _signature Signature for verification
     * @param _options Additional options data
     * @param util The utility contract instance
     * @param userAddresses User data mapping
     * @param unavailableUnifiedIds Unavailable UnifiedIds mapping
     * @return True if initiation successful
     */
    function initiateUpdateUnifiedId(
        string calldata _oldUnifiedId,
        string calldata _newUnifiedId,
        bytes calldata _signature,
        bytes calldata _options,
        RegistrarStorageUtil util,
        mapping(string => UserData) storage userAddresses,
        mapping(string => bool) storage unavailableUnifiedIds
    ) external returns (bool) {
        if (!userAddresses[_oldUnifiedId].exists) revert E4();
        if (userAddresses[_newUnifiedId].exists) revert E6();
        if (unavailableUnifiedIds[_newUnifiedId]) revert E7();
        if (!util.isUnifiedIdValid(_newUnifiedId)) revert E27();
        
        emit UpdateUnifiedIdInitiated(_oldUnifiedId, _newUnifiedId, _signature, _options);
        return true;
    }

    /**
     * @notice Completes the UnifiedId update process
     * @param _oldUnifiedId The current UnifiedId
     * @param _newUnifiedId The new UnifiedId
     * @param _signature Signature for verification
     * @param _nonce Nonce for replay protection
     * @param _timestamp Timestamp for expiration check
     * @param chainId The chain ID
     * @param util The utility contract instance
     * @param resolver The resolver contract instance
     * @param userAddresses User data mapping
     * @param usedNonces Used nonces mapping
     * @param resolveAddressFromUnifiedId Address resolution mapping
     * @param resolveUnifiedIdFromAddress Reverse resolution mapping
     * @param registeredUnifiedIds Registered UnifiedIds mapping
     * @param unavailableUnifiedIds Unavailable UnifiedIds mapping
     * @return True if update successful
     */
    function completeUpdateUnifiedId(
        string memory _oldUnifiedId,
        string memory _newUnifiedId,
        bytes calldata _signature,
        uint256 _nonce,
        uint256 _timestamp,
        uint256 chainId,
        RegistrarStorageUtil util,
        IUnifiedIdResolver resolver,
        mapping(string => UserData) storage userAddresses,
        mapping(string => mapping(uint256 => bool)) storage usedNonces,
        mapping(string => address) storage resolveAddressFromUnifiedId,
        mapping(address => string) storage resolveUnifiedIdFromAddress,
        mapping(string => bool) storage registeredUnifiedIds,
        mapping(string => bool) storage unavailableUnifiedIds
    ) external returns (bool) {
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

    // ==================== PRIMARY ADDRESS OPERATIONS ====================

    /**
     * @notice Initiates primary address change process
     * @param _unifiedId The UnifiedId to update
     * @param _newPrimaryAddress The new primary address
     * @param currentPrimarySignature Current primary address signature
     * @param newPrimarySignature New primary address signature
     * @param _options Additional options data
     * @param userAddresses User data mapping
     * @return True if initiation successful
     */
    function initiatePrimaryAddressChange(
        string calldata _unifiedId,
        address _newPrimaryAddress,
        bytes calldata currentPrimarySignature,
        bytes calldata newPrimarySignature,
        bytes calldata _options,
        mapping(string => UserData) storage userAddresses
    ) external returns (bool) {
        if (!userAddresses[_unifiedId].exists) revert E4();
        
        emit UpdateUnifiedIdPrimaryAddressInitiated(
            _unifiedId,
            _newPrimaryAddress,
            currentPrimarySignature,
            newPrimarySignature,
            _options
        );
        return true;
    }

    /**
     * @notice Finalizes primary address change process
     * @param _unifiedId The UnifiedId to update
     * @param _newPrimaryAddress The new primary address
     * @param _currentPrimarySignature Current primary address signature
     * @param _newPrimarySignature New primary address signature
     * @param _nonce Nonce for replay protection
     * @param _timestamp Timestamp for expiration check
     * @param chainId The chain ID
     * @param util The utility contract instance
     * @param resolver The resolver contract instance
     * @param userAddresses User data mapping
     * @param usedNonces Used nonces mapping
     * @param resolveAddressFromUnifiedId Address resolution mapping
     * @param resolveUnifiedIdFromAddress Reverse resolution mapping
     * @return True if update successful
     */
    function finalizePrimaryAddressChange(
        string calldata _unifiedId,
        address _newPrimaryAddress,
        bytes calldata _currentPrimarySignature,
        bytes calldata _newPrimarySignature,
        uint256 _nonce,
        uint256 _timestamp,
        uint256 chainId,
        RegistrarStorageUtil util,
        IUnifiedIdResolver resolver,
        mapping(string => UserData) storage userAddresses,
        mapping(string => mapping(uint256 => bool)) storage usedNonces,
        mapping(string => address) storage resolveAddressFromUnifiedId,
        mapping(address => string) storage resolveUnifiedIdFromAddress
    ) external returns (bool) {
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

    // ==================== SECONDARY ADDRESS OPERATIONS ====================

    /**
     * @notice Initiates adding a secondary address
     * @param _unifiedId The UnifiedId to add secondary address to
     * @param _secondaryAddress The secondary address to add
     * @param _primarySignature Primary address signature
     * @param _secondarySignature Secondary address signature
     * @param _options Additional options data
     * @param userAddresses User data mapping
     * @param config Packed configuration
     * @return True if initiation successful
     */
    function initiateAddSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress,
        bytes calldata _primarySignature,
        bytes calldata _secondarySignature,
        bytes calldata _options,
        mapping(string => UserData) storage userAddresses,
        PackedConfig storage config
    ) external returns (bool) {
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

    /**
     * @notice Completes adding a secondary address
     * @param params Secondary address operation parameters
     * @param contracts Contract references
     * @param userAddresses User data mapping
     * @param usedNonces Used nonces mapping
     * @return True if addition successful
     */
    function completeAddSecondaryAddress(
        SecondaryAddressParams calldata params,
        ContractRefs memory contracts,
        mapping(string => UserData) storage userAddresses,
        mapping(string => mapping(uint256 => bool)) storage usedNonces
    ) external returns (bool) {
        UserData storage userData = userAddresses[params.unifiedId];

        if (userData.primary == params.secondaryAddress) revert E34();
        if (userData.isSecondary[params.secondaryAddress]) revert E35();
        if (block.timestamp > params.timestamp + 1 hours) revert E23();
        if (usedNonces[params.unifiedId][params.nonce]) revert E24();

        bytes memory message = abi.encode(
            "ADD_SECONDARY_ADDRESS",
            params.unifiedId,
            params.secondaryAddress,
            params.chainId,
            params.nonce,
            params.timestamp
        );

        if (!contracts.util.verifySignature(message, userData.primary, params.primarySignature)) revert E25();
        if (!contracts.util.verifySignature(message, params.secondaryAddress, params.secondarySignature)) revert E37();

        usedNonces[params.unifiedId][params.nonce] = true;
        userData.isSecondary[params.secondaryAddress] = true;
        userData.secondaries.push(params.secondaryAddress);

        contracts.resolver.addUnifiedIdSecondaryAddress(params.unifiedId, params.chainId, params.secondaryAddress);

        emit SecondaryAddressAdded(params.unifiedId, params.secondaryAddress);
        return true;
    }

    /**
     * @notice Initiates removing a secondary address
     * @param _unifiedId The UnifiedId to remove secondary address from
     * @param _secondaryAddress The secondary address to remove
     * @param _signature Signature for verification
     * @param _options Additional options data
     * @param userAddresses User data mapping
     * @return True if initiation successful
     */
    function initiateRemoveSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress,
        bytes calldata _signature,
        bytes calldata _options,
        mapping(string => UserData) storage userAddresses
    ) external returns (bool) {
        if (!userAddresses[_unifiedId].exists) revert E4();
        
        emit RemoveSecondaryAddressInitiated(_unifiedId, _secondaryAddress, _signature, _options);
        return true;
    }

    /**
     * @notice Completes removing a secondary address
     * @param params Secondary address operation parameters (uses signature field)
     * @param contracts Contract references
     * @param userAddresses User data mapping
     * @param usedNonces Used nonces mapping
     * @return True if removal successful
     */
    function completeRemoveSecondaryAddress(
        SecondaryAddressParams calldata params,
        ContractRefs memory contracts,
        mapping(string => UserData) storage userAddresses,
        mapping(string => mapping(uint256 => bool)) storage usedNonces
    ) external returns (bool) {
        UserData storage userData = userAddresses[params.unifiedId];

        if (block.timestamp > params.timestamp + 1 hours) revert E23();
        if (usedNonces[params.unifiedId][params.nonce]) revert E24();

        bytes memory message = abi.encode(
            "REMOVE_SECONDARY_ADDRESS",
            params.unifiedId,
            params.secondaryAddress,
            params.chainId,
            params.nonce,
            params.timestamp
        );

        if (!contracts.util.verifySignature(message, userData.primary, params.signature)) revert E30();

        usedNonces[params.unifiedId][params.nonce] = true;
        userData.isSecondary[params.secondaryAddress] = false;

        uint256 length = userData.secondaries.length;
        for (uint256 i; i < length;) {
            if (userData.secondaries[i] == params.secondaryAddress) {
                userData.secondaries[i] = userData.secondaries[length - 1];
                userData.secondaries.pop();
                break;
            }
            unchecked { ++i; }
        }

        contracts.resolver.removeUnifiedIdSecondaryAddress(params.unifiedId, params.chainId, params.secondaryAddress);

        emit SecondaryAddressRemoved(params.unifiedId, params.secondaryAddress);
        return true;
    }

    // ==================== ROLE MANAGEMENT OPERATIONS ====================

    /**
     * @notice Grant relayer role to an address
     * @param self The AccessControl contract instance
     * @param relayer Address to grant relayer role
     * @param RELAYER_ROLE The relayer role constant
     */
    function grantRelayerRole(
        AccessControlUpgradeable self,
        address relayer,
        bytes32 RELAYER_ROLE
    ) external {
        self.grantRole(RELAYER_ROLE, relayer);
    }

    /**
     * @notice Revoke relayer role from an address
     * @param self The AccessControl contract instance
     * @param relayer Address to revoke relayer role
     * @param RELAYER_ROLE The relayer role constant
     */
    function revokeRelayerRole(
        AccessControlUpgradeable self,
        address relayer,
        bytes32 RELAYER_ROLE
    ) external {
        self.revokeRole(RELAYER_ROLE, relayer);
    }

    /**
     * @notice Grant registrar role to an address
     * @param self The AccessControl contract instance
     * @param registrar Address to grant registrar role
     * @param REGISTRAR_ROLE The registrar role constant
     */
    function grantRegistrarRole(
        AccessControlUpgradeable self,
        address registrar,
        bytes32 REGISTRAR_ROLE
    ) external {
        self.grantRole(REGISTRAR_ROLE, registrar);
    }

    /**
     * @notice Revoke registrar role from an address
     * @param self The AccessControl contract instance
     * @param registrar Address to revoke registrar role
     * @param REGISTRAR_ROLE The registrar role constant
     */
    function revokeRegistrarRole(
        AccessControlUpgradeable self,
        address registrar,
        bytes32 REGISTRAR_ROLE
    ) external {
        self.revokeRole(REGISTRAR_ROLE, registrar);
    }

    /**
     * @notice Grant admin role to an address
     * @param self The AccessControl contract instance
     * @param admin Address to grant admin role
     * @param ADMIN_ROLE The admin role constant
     */
    function grantAdminRole(
        AccessControlUpgradeable self,
        address admin,
        bytes32 ADMIN_ROLE
    ) external {
        self.grantRole(ADMIN_ROLE, admin);
    }

    /**
     * @notice Revoke admin role from an address
     * @param self The AccessControl contract instance
     * @param admin Address to revoke admin role
     * @param ADMIN_ROLE The admin role constant
     */
    function revokeAdminRole(
        AccessControlUpgradeable self,
        address admin,
        bytes32 ADMIN_ROLE
    ) external {
        self.revokeRole(ADMIN_ROLE, admin);
    }

    /**
     * @notice Grant emergency role to an address
     * @param self The AccessControl contract instance
     * @param emergency Address to grant emergency role
     * @param EMERGENCY_ROLE The emergency role constant
     */
    function grantEmergencyRole(
        AccessControlUpgradeable self,
        address emergency,
        bytes32 EMERGENCY_ROLE
    ) external {
        self.grantRole(EMERGENCY_ROLE, emergency);
    }

    /**
     * @notice Revoke emergency role from an address
     * @param self The AccessControl contract instance
     * @param emergency Address to revoke emergency role
     * @param EMERGENCY_ROLE The emergency role constant
     */
    function revokeEmergencyRole(
        AccessControlUpgradeable self,
        address emergency,
        bytes32 EMERGENCY_ROLE
    ) external {
        self.revokeRole(EMERGENCY_ROLE, emergency);
    }

    /**
     * @notice Grant upgrader role to an address
     * @param self The AccessControl contract instance
     * @param upgrader Address to grant upgrader role
     * @param UPGRADER_ROLE The upgrader role constant
     */
    function grantUpgraderRole(
        AccessControlUpgradeable self,
        address upgrader,
        bytes32 UPGRADER_ROLE
    ) external {
        self.grantRole(UPGRADER_ROLE, upgrader);
    }

    /**
     * @notice Revoke upgrader role from an address
     * @param self The AccessControl contract instance
     * @param upgrader Address to revoke upgrader role
     * @param UPGRADER_ROLE The upgrader role constant
     */
    function revokeUpgraderRole(
        AccessControlUpgradeable self,
        address upgrader,
        bytes32 UPGRADER_ROLE
    ) external {
        self.revokeRole(UPGRADER_ROLE, upgrader);
    }

    // ==================== UTILITY AND VIEW OPERATIONS ====================

    /**
     * @notice Get registrar name for an address (optimized with parallel arrays)
     * @param registrarAddresses Array of registrar addresses
     * @param registrarNames Array of registrar names
     * @param _address The registrar address
     * @return The registrar name, empty string if not found
     */
    function getRegistrarName(
        address[] storage registrarAddresses,
        string[] storage registrarNames,
        address _address
    ) internal view returns (string memory) {
        for (uint256 i = 0; i < registrarAddresses.length; i++) {
            if (registrarAddresses[i] == _address) {
                return registrarNames[i];
            }
        }
        return "";
    }

    /**
     * @notice Check if an address is taken by a registrar
     * @param registrarAddresses Array of registrar addresses
     * @param _address The address to check
     * @return True if address is taken by a registrar
     */
    function isAddressTaken(
        address[] storage registrarAddresses,
        address _address
    ) internal view returns (bool) {
        for (uint256 i = 0; i < registrarAddresses.length; i++) {
            if (registrarAddresses[i] == _address) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Get registrar info for an address
     * @param self The AccessControl contract instance
     * @param registrarAddresses Array of registrar addresses
     * @param registrarNames Array of registrar names
     * @param totalRegistrarUpdates Mapping of update counts
     * @param _address The address to get info for
     * @param REGISTRAR_ROLE The registrar role constant
     * @return isRegistrar True if address is a registrar
     * @return registrarName The registrar name
     * @return updateCount Number of updates
     */
    function getRegistrarInfo(
        AccessControlUpgradeable self,
        address[] storage registrarAddresses,
        string[] storage registrarNames,
        mapping(address => uint8) storage totalRegistrarUpdates,
        address _address,
        bytes32 REGISTRAR_ROLE
    ) external view returns (
        bool isRegistrar,
        string memory registrarName,
        uint8 updateCount
    ) {
        return (
            self.hasRole(REGISTRAR_ROLE, _address),
            getRegistrarName(registrarAddresses, registrarNames, _address),
            totalRegistrarUpdates[_address]
        );
    }

    // ==================== RESOLVER DELEGATION OPERATIONS ====================

    /**
     * @notice Resolves a secondary address to its UnifiedId
     * @param resolver The resolver contract
     * @param secondaryAddr The secondary address to resolve
     * @param chainId The chain ID
     * @return The UnifiedId that the secondary address belongs to
     */
    function resolveSecondaryAddressToUnifiedId(
        IUnifiedIdResolver resolver,
        address secondaryAddr,
        uint256 chainId
    ) external view returns (string memory) {
        return resolver.resolveSecondaryAddressToUnifiedId(secondaryAddr, chainId);
    }

    /**
     * @notice Resolves any address (primary or secondary) to its UnifiedId
     * @param resolver The resolver contract
     * @param addr The address to resolve
     * @param chainId The chain ID
     * @return unifiedId The UnifiedId associated with the address
     * @return isPrimary True if the address is a primary address
     * @return isSecondary True if the address is a secondary address
     */
    function resolveAnyAddressToUnifiedId(
        IUnifiedIdResolver resolver,
        address addr,
        uint256 chainId
    ) external view returns (
        string memory unifiedId,
        bool isPrimary,
        bool isSecondary
    ) {
        return resolver.resolveAnyAddressToUnifiedId(addr, chainId);
    }

    /**
     * @notice Gets all addresses for a UnifiedId
     * @param resolver The resolver contract
     * @param unifiedId The UnifiedId to get addresses for
     * @param chainId The chain ID
     * @return allAddresses Array containing all addresses
     */
    function getAllAddresses(
        IUnifiedIdResolver resolver,
        string calldata unifiedId,
        uint256 chainId
    ) external view returns (address[] memory allAddresses) {
        return resolver.getAllAddresses(unifiedId, chainId);
    }

    /**
     * @notice Gets the total count of addresses for a UnifiedId
     * @param resolver The resolver contract
     * @param unifiedId The UnifiedId to count addresses for
     * @param chainId The chain ID
     * @return count Total number of addresses
     */
    function getAddressCount(
        IUnifiedIdResolver resolver,
        string calldata unifiedId,
        uint256 chainId
    ) external view returns (uint256 count) {
        return resolver.getAddressCount(unifiedId, chainId);
    }
} 