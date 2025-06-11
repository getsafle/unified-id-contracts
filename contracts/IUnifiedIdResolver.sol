// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

/**
 * @title IUnifiedIdResolver
 * @notice Interface for UnifiedId resolver contracts
 * @dev Similar to ENS resolver interface but for UnifiedIds with multi-chain support
 */
interface IUnifiedIdResolver {
    // Events
    event AddressChanged(string indexed unifiedId, address newAddress);
    event UnifiedIdChanged(address indexed addr, string newUnifiedId);
    event SecondaryAddressAdded(string indexed unifiedId, address secondary);
    event SecondaryAddressRemoved(string indexed unifiedId, address secondary);

    // Multi-chain events
    event ChainAddressChanged(string indexed unifiedId, uint256 indexed chainId, address newAddress);
    event ChainSecondaryAddressAdded(string indexed unifiedId, uint256 indexed chainId, address secondary);
    event ChainSecondaryAddressRemoved(string indexed unifiedId, uint256 indexed chainId, address secondary);

    // Core resolution functions (single-chain, backward compatible)
    function addr(string calldata unifiedId) external view returns (address);
    function unifiedId(address addr) external view returns (string memory);

    // Secondary address management (single-chain)
    function addSecondaryAddress(string calldata unifiedId, address secondary) external;
    function removeSecondaryAddress(string calldata unifiedId, address secondary) external;
    function isSecondaryAddress(string calldata unifiedId, address addr) external view returns (bool);
    function getSecondaryAddresses(string calldata unifiedId) external view returns (address[] memory);

    // Admin functions (single-chain)
    function setAddress(string calldata unifiedId, address addr) external;
    function setUnifiedId(address addr, string calldata unifiedId) external;
    function clearRecords(string calldata unifiedId) external;

    // Multi-chain resolution functions
    function getPrimaryAddress(string calldata unifiedId, uint256 chainId) external view returns (address);
    function getUnifiedIdFromAddress(address addr, uint256 chainId) external view returns (string memory);
    function getAddresses(string calldata unifiedId, uint256 chainId) external view returns (address primary, address[] memory secondaries);
    function isAddressAssociated(string calldata unifiedId, uint256 chainId, address addr) external view returns (bool isPrimary, bool isSecondary);

    // Multi-chain management functions
    function setUnifiedIdPrimaryAddress(string calldata unifiedId, uint256 chainId, address primary) external;
    function updateUnifiedIdPrimaryAddress(string calldata unifiedId, uint256 chainId, address newPrimary) external;
    function addUnifiedIdSecondaryAddress(string calldata unifiedId, uint256 chainId, address secondary) external;
    function removeUnifiedIdSecondaryAddress(string calldata unifiedId, uint256 chainId, address secondary) external;
    function clearUnifiedIdMappings(string calldata unifiedId, uint256 chainId) external;

    // Authorization
    function isAuthorized(address addr) external view returns (bool);
    function setAuthorization(address addr, bool authorized) external;
} 