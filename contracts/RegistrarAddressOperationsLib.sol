// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import "./RegistrarStorageUtil.sol";
import "./IUnifiedIdResolver.sol";

/**
 * @title RegistrarAddressOperationsLib
 * @author kunalmkv
 * @notice Library for primary and secondary address operations
 * @dev Extracted from main contract to reduce bytecode size
 */
library RegistrarAddressOperationsLib {
    
    // === CUSTOM ERRORS ===
    error E23(); // "Operation expired"
    error E24(); // "Nonce already used"
    error E25(); // "Invalid primary signature"
    error E30(); // "Invalid signature"
    error E32(); // "Invalid current primary signature"
    error E33(); // "Invalid new primary signature"
    error E34(); // "Cannot add primary address as secondary"
    error E35(); // "Secondary address already added"
    error E36(); // "Maximum secondary addresses limit reached"
    error E37(); // "Invalid secondary signature"
    error E47(); // "Cannot set same primary address"
    error E48(); // "Cannot set zero address as primary"

    // === EVENTS ===
    event UnifiedIDUpdated(string indexed unifiedId, address indexed oldPrimary, address indexed newPrimary);
    event SecondaryAddressAdded(string unifiedId, address secondary);
    event SecondaryAddressRemoved(string unifiedId, address secondary);
    event UpdateUnifiedIdPrimaryAddressInitiated(string unifiedId, address newPrimaryAddress, bytes currentPrimarySignature, bytes newPrimarySignature, bytes options);
    event AddSecondaryAddressInitiated(string unifiedId, address secondaryAddress, bytes primarySignature, bytes secondarySignature, bytes options);
    event RemoveSecondaryAddressInitiated(string unifiedId, address secondaryAddress, bytes signature, bytes options);

    // === STRUCT DEFINITIONS ===
    struct UserData {
        address primary;
        mapping(address => bool) isSecondary;
        address[] secondaries;
        bool exists;
    }

    struct PackedConfig {
        uint128 maxSecondaryAddresses;
        uint64 minUnifiedIdLength;
        uint64 maxUnifiedIdLength;
        bool isPaused;
        bool publicRegistrarRegistration;
        bool emergencyMode;
    }

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
        if (!userAddresses[_unifiedId].exists) revert();
        
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
     * @param _unifiedId The UnifiedId to add secondary address to
     * @param _secondaryAddress The secondary address to add
     * @param _primarySignature Primary address signature
     * @param _secondarySignature Secondary address signature
     * @param _nonce Nonce for replay protection
     * @param _timestamp Timestamp for expiration check
     * @param chainId The chain ID
     * @param util The utility contract instance
     * @param resolver The resolver contract instance
     * @param userAddresses User data mapping
     * @param usedNonces Used nonces mapping
     * @return True if addition successful
     */
    function completeAddSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress,
        bytes calldata _primarySignature,
        bytes calldata _secondarySignature,
        uint256 _nonce,
        uint256 _timestamp,
        uint256 chainId,
        RegistrarStorageUtil util,
        IUnifiedIdResolver resolver,
        mapping(string => UserData) storage userAddresses,
        mapping(string => mapping(uint256 => bool)) storage usedNonces
    ) external returns (bool) {
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
        if (!userAddresses[_unifiedId].exists) revert();
        
        emit RemoveSecondaryAddressInitiated(_unifiedId, _secondaryAddress, _signature, _options);
        return true;
    }

    /**
     * @notice Completes removing a secondary address
     * @param _unifiedId The UnifiedId to remove secondary address from
     * @param _secondaryAddress The secondary address to remove
     * @param _signature Signature for verification
     * @param _nonce Nonce for replay protection
     * @param _timestamp Timestamp for expiration check
     * @param chainId The chain ID
     * @param util The utility contract instance
     * @param resolver The resolver contract instance
     * @param userAddresses User data mapping
     * @param usedNonces Used nonces mapping
     * @return True if removal successful
     */
    function completeRemoveSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress,
        bytes calldata _signature,
        uint256 _nonce,
        uint256 _timestamp,
        uint256 chainId,
        RegistrarStorageUtil util,
        IUnifiedIdResolver resolver,
        mapping(string => UserData) storage userAddresses,
        mapping(string => mapping(uint256 => bool)) storage usedNonces
    ) external returns (bool) {
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
} 