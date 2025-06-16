// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

/**
 * @title IUnifiedIdResolver
 * @author kunalmkv
 * @notice Interface for UnifiedId resolver contracts that handle address<->UnifiedId mappings
 * @dev Similar to ENS resolver interface but designed for UnifiedIds with comprehensive multi-chain support
 * @dev Provides both single-chain backward compatibility and multi-chain functionality
 */
interface IUnifiedIdResolver {
    // Events
    
    /**
     * @notice Emitted when an address is changed for a UnifiedId (single-chain)
     * @param unifiedId The UnifiedId whose address was changed
     * @param newAddress The new address associated with the UnifiedId
     */
    event AddressChanged(string indexed unifiedId, address newAddress);
    
    /**
     * @notice Emitted when a UnifiedId is changed for an address (single-chain)
     * @param addr The address whose UnifiedId was changed
     * @param newUnifiedId The new UnifiedId associated with the address
     */
    event UnifiedIdChanged(address indexed addr, string newUnifiedId);
    
    /**
     * @notice Emitted when a secondary address is added to a UnifiedId (single-chain)
     * @param unifiedId The UnifiedId to which secondary address was added
     * @param secondary The secondary address that was added
     */
    event SecondaryAddressAdded(string indexed unifiedId, address secondary);
    
    /**
     * @notice Emitted when a secondary address is removed from a UnifiedId (single-chain)
     * @param unifiedId The UnifiedId from which secondary address was removed
     * @param secondary The secondary address that was removed
     */
    event SecondaryAddressRemoved(string indexed unifiedId, address secondary);

    // Multi-chain events
    
    /**
     * @notice Emitted when an address is changed for a UnifiedId on a specific chain
     * @param unifiedId The UnifiedId whose address was changed
     * @param chainId The chain ID where the address was changed
     * @param newAddress The new address associated with the UnifiedId on the specified chain
     */
    event ChainAddressChanged(string indexed unifiedId, uint256 indexed chainId, address newAddress);
    
    /**
     * @notice Emitted when a secondary address is added to a UnifiedId on a specific chain
     * @param unifiedId The UnifiedId to which secondary address was added
     * @param chainId The chain ID where the secondary address was added
     * @param secondary The secondary address that was added
     */
    event ChainSecondaryAddressAdded(string indexed unifiedId, uint256 indexed chainId, address secondary);
    
    /**
     * @notice Emitted when a secondary address is removed from a UnifiedId on a specific chain
     * @param unifiedId The UnifiedId from which secondary address was removed
     * @param chainId The chain ID where the secondary address was removed
     * @param secondary The secondary address that was removed
     */
    event ChainSecondaryAddressRemoved(string indexed unifiedId, uint256 indexed chainId, address secondary);

    // Core resolution functions (single-chain, backward compatible)
    
    /**
     * @notice Resolves a UnifiedId to its primary address (backward compatible - default chain)
     * @dev Returns the primary address associated with the UnifiedId on the default chain
     * @param unifiedId The UnifiedId to resolve
     * @return The primary address associated with the UnifiedId
     */
    function resolvePrimaryAddressFromUnifiedID(string calldata unifiedId) external view returns (address);
    
    /**
     * @notice Reverse resolves an address to its UnifiedId (backward compatible - default chain)
     * @dev Returns the UnifiedId associated with the address on the default chain
     * @param addr The address to reverse resolve
     * @return The UnifiedId associated with the address
     */
    function unifiedId(address addr) external view returns (string memory);

    // Secondary address management (single-chain)
    
    /**
     * @notice Adds a secondary address to a UnifiedId (single-chain)
     * @dev Associates an additional address with the UnifiedId on the default chain
     * @param unifiedId The UnifiedId to add secondary address to
     * @param secondary The secondary address to add
     * @custom:requirements
     * - Caller must be authorized
     * - Secondary address must not already be associated with another UnifiedId
     * @custom:events Emits SecondaryAddressAdded
     */
    function addSecondaryAddress(string calldata unifiedId, address secondary) external;
    
    /**
     * @notice Removes a secondary address from a UnifiedId (single-chain)
     * @dev Disassociates a secondary address from the UnifiedId on the default chain
     * @param unifiedId The UnifiedId to remove secondary address from
     * @param secondary The secondary address to remove
     * @custom:requirements
     * - Caller must be authorized
     * - Secondary address must be currently associated with the UnifiedId
     * @custom:events Emits SecondaryAddressRemoved
     */
    function removeSecondaryAddress(string calldata unifiedId, address secondary) external;
    
    /**
     * @notice Checks if an address is a secondary address for a UnifiedId (single-chain)
     * @dev Returns whether the address is registered as secondary for the UnifiedId on default chain
     * @param unifiedId The UnifiedId to check
     * @param addr The address to check
     * @return True if the address is a secondary address for the UnifiedId
     */
    function isSecondaryAddress(string calldata unifiedId, address addr) external view returns (bool);
    
    /**
     * @notice Gets all secondary addresses for a UnifiedId (single-chain)
     * @dev Returns array of all secondary addresses associated with UnifiedId on default chain
     * @param unifiedId The UnifiedId to get secondary addresses for
     * @return Array of secondary addresses
     */
    function getSecondaryAddresses(string calldata unifiedId) external view returns (address[] memory);

    // Admin functions (single-chain)
    
    /**
     * @notice Sets the primary address for a UnifiedId (single-chain admin function)
     * @dev Associates a primary address with the UnifiedId on the default chain
     * @param unifiedId The UnifiedId to set address for
     * @param addr The address to associate with the UnifiedId
     * @custom:requirements
     * - Caller must be authorized
     * - Address must not already be associated with another UnifiedId
     * @custom:events Emits AddressChanged and UnifiedIdChanged
     */
    function setAddress(string calldata unifiedId, address addr) external;
    
    /**
     * @notice Sets a UnifiedId for an address (single-chain admin function)
     * @dev Associates a UnifiedId with the address on the default chain (reverse mapping)
     * @param addr The address to set UnifiedId for
     * @param unifiedId The UnifiedId to associate with the address
     * @custom:requirements
     * - Caller must be authorized
     * - UnifiedId must not already be associated with another address
     * @custom:events Emits AddressChanged and UnifiedIdChanged
     */
    function setUnifiedId(address addr, string calldata unifiedId) external;
    
    /**
     * @notice Clears all records for a UnifiedId (single-chain admin function)
     * @dev Removes all address associations for the UnifiedId on the default chain
     * @param unifiedId The UnifiedId to clear records for
     * @custom:requirements
     * - Caller must be authorized
     * @custom:events Emits AddressChanged and UnifiedIdChanged
     * @custom:state-changes
     * - Removes primary address mapping
     * - Removes all secondary address mappings
     * - Removes reverse address mappings
     */
    function clearRecords(string calldata unifiedId) external;

    // Multi-chain resolution functions
    
    /**
     * @notice Gets the primary address for a UnifiedId on a specific chain
     * @dev Returns the primary address associated with the UnifiedId on the specified chain
     * @param unifiedId The UnifiedId to resolve
     * @param chainId The chain ID to query
     * @return The primary address on the specified chain
     */
    function getPrimaryAddress(string calldata unifiedId, uint256 chainId) external view returns (address);
    
    /**
     * @notice Gets the UnifiedId associated with an address on a specific chain
     * @dev Reverse resolves an address to its UnifiedId on the specified chain
     * @param addr The address to reverse resolve
     * @param chainId The chain ID to query
     * @return The UnifiedId associated with the address on the specified chain
     */
    function getUnifiedIdFromAddress(address addr, uint256 chainId) external view returns (string memory);
    
    /**
     * @notice Gets all addresses (primary and secondary) for a UnifiedId on a specific chain
     * @dev Returns both primary and secondary addresses for the UnifiedId on the specified chain
     * @param unifiedId The UnifiedId to get addresses for
     * @param chainId The chain ID to query
     * @return primary The primary address on the specified chain
     * @return secondaries Array of secondary addresses on the specified chain
     */
    function getAddresses(string calldata unifiedId, uint256 chainId) external view returns (address primary, address[] memory secondaries);
    
    /**
     * @notice Checks if an address is associated with a UnifiedId on a specific chain
     * @dev Returns whether the address is primary or secondary for the UnifiedId on the specified chain
     * @param unifiedId The UnifiedId to check
     * @param chainId The chain ID to query
     * @param addr The address to check
     * @return isPrimary True if the address is the primary address
     * @return isSecondary True if the address is a secondary address
     */
    function isAddressAssociated(string calldata unifiedId, uint256 chainId, address addr) external view returns (bool isPrimary, bool isSecondary);

    // Multi-chain management functions
    
    /**
     * @notice Sets the primary address for a UnifiedId on a specific chain
     * @dev Associates a primary address with the UnifiedId on the specified chain
     * @param unifiedId The UnifiedId to set primary address for
     * @param chainId The chain ID to set the address on
     * @param primary The primary address to associate
     * @custom:requirements
     * - Caller must be authorized
     * - Address must not already be associated with another UnifiedId on the same chain
     * @custom:events Emits ChainAddressChanged
     */
    function setUnifiedIdPrimaryAddress(string calldata unifiedId, uint256 chainId, address primary) external;
    
    /**
     * @notice Updates the primary address for a UnifiedId on a specific chain
     * @dev Changes the existing primary address for the UnifiedId on the specified chain
     * @param unifiedId The UnifiedId to update primary address for
     * @param chainId The chain ID to update the address on
     * @param newPrimary The new primary address
     * @custom:requirements
     * - Caller must be authorized
     * - UnifiedId must already exist on the specified chain
     * @custom:events Emits ChainAddressChanged
     */
    function updateUnifiedIdPrimaryAddress(string calldata unifiedId, uint256 chainId, address newPrimary) external;
    
    /**
     * @notice Adds a secondary address to a UnifiedId on a specific chain
     * @dev Associates an additional address with the UnifiedId on the specified chain
     * @param unifiedId The UnifiedId to add secondary address to
     * @param chainId The chain ID to add the address on
     * @param secondary The secondary address to add
     * @custom:requirements
     * - Caller must be authorized
     * - UnifiedId must already exist on the specified chain
     * - Secondary address must not already be associated with another UnifiedId on the same chain
     * @custom:events Emits ChainSecondaryAddressAdded
     */
    function addUnifiedIdSecondaryAddress(string calldata unifiedId, uint256 chainId, address secondary) external;
    
    /**
     * @notice Removes a secondary address from a UnifiedId on a specific chain
     * @dev Disassociates a secondary address from the UnifiedId on the specified chain
     * @param unifiedId The UnifiedId to remove secondary address from
     * @param chainId The chain ID to remove the address from
     * @param secondary The secondary address to remove
     * @custom:requirements
     * - Caller must be authorized
     * - Secondary address must be currently associated with the UnifiedId on the specified chain
     * @custom:events Emits ChainSecondaryAddressRemoved
     */
    function removeUnifiedIdSecondaryAddress(string calldata unifiedId, uint256 chainId, address secondary) external;
    
    /**
     * @notice Clears all address mappings for a UnifiedId on a specific chain
     * @dev Removes all address associations for the UnifiedId on the specified chain
     * @param unifiedId The UnifiedId to clear mappings for
     * @param chainId The chain ID to clear mappings on
     * @custom:requirements
     * - Caller must be authorized
     * @custom:events Emits ChainAddressChanged
     * @custom:state-changes
     * - Removes primary address mapping on the specified chain
     * - Removes all secondary address mappings on the specified chain
     * - Removes reverse address mappings on the specified chain
     */
    function clearUnifiedIdMappings(string calldata unifiedId, uint256 chainId) external;

    // Authorization
    
    /**
     * @notice Checks if an address is authorized to modify resolver records
     * @dev Returns whether the address has permission to call admin functions
     * @param addr The address to check authorization for
     * @return True if the address is authorized
     */
    function isAuthorized(address addr) external view returns (bool);
    
    /**
     * @notice Sets authorization status for an address
     * @dev Grants or revokes permission to modify resolver records
     * @param addr The address to set authorization for
     * @param authorized True to grant authorization, false to revoke
     * @custom:requirements
     * - Caller must be owner or registry
     * @custom:access-control Only owner or authorized registry can call this function
     */
    function setAuthorization(address addr, bool authorized) external;
} 