// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import "./RegistrarStorageUtil.sol";
import "./IUnifiedIdResolver.sol";

/**
 * @title RegistrarUnifiedIdOperationsLib
 * @author kunalmkv
 * @notice Library for UnifiedId registration, update, and management operations
 * @dev Extracted from main contract to reduce bytecode size
 */
library RegistrarUnifiedIdOperationsLib {
    
    // === CUSTOM ERRORS ===
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

    // === EVENTS ===
    event UnifiedIDRegistered(string indexed unifiedId, address indexed primary, uint256 timestamp);
    event UnifiedIDChanged(string indexed oldUnifiedId, string indexed newUnifiedId, address indexed primary, uint256 timestamp);
    event RegisterUnifiedIdInitiated(string unifiedId, address primaryAddress, bytes masterSignature, bytes primarySignature, bytes options);
    event UpdateUnifiedIdInitiated(string oldUnifiedId, string newUnifiedId, bytes signature, bytes options);

    // === STRUCT DEFINITIONS ===
    struct UserData {
        address primary;
        mapping(address => bool) isSecondary;
        address[] secondaries;
        bool exists;
    }

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
     * @param _unifiedId The UnifiedId to register
     * @param _primaryAddress The primary address for the UnifiedId
     * @param _masterSignature Master signature for verification
     * @param _primarySignature Primary address signature
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
     * @param totalRegisteredUnifiedIds Total count storage
     * @param totalUnifiedIdRegistered Total count storage
     * @return True if registration successful
     */
    function completeRegisterUnifiedId(
        string calldata _unifiedId,
        address _primaryAddress,
        bytes calldata _masterSignature,
        bytes calldata _primarySignature,
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
        mapping(string => bool) storage unavailableUnifiedIds,
        uint256 storage totalRegisteredUnifiedIds,
        uint256 storage totalUnifiedIdRegistered
    ) external returns (bool) {
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
} 