// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import "./IUnifiedIdResolver.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UnifiedIdResolver
 * @notice Resolver contract for UnifiedId name resolution
 * @dev Handles all address<->UnifiedId mappings and secondary addresses
 */
contract UnifiedIdResolver is IUnifiedIdResolver, UUPSUpgradeable, OwnableUpgradeable {

    // Core mappings for resolution (single-chain, default chainId = 0)
    mapping(string => address) private unifiedIdToAddress;
    mapping(address => string) private addressToUnifiedId;

    // Secondary address management (single-chain)
    mapping(string => address[]) private secondaryAddresses;
    mapping(string => mapping(address => bool)) private isSecondary;

    // Multi-chain mappings
    mapping(string => mapping(uint256 => address)) private chainUnifiedIdToAddress;
    mapping(address => mapping(uint256 => string)) private chainAddressToUnifiedId;
    mapping(string => mapping(uint256 => address[])) private chainSecondaryAddresses;
    mapping(string => mapping(uint256 => mapping(address => bool))) private chainIsSecondary;

    // Authorization - who can modify records
    mapping(address => bool) public authorizedCallers;

    // Registry contract that can authorize calls
    address public registry;

    modifier onlyAuthorized() {
        require(
            authorizedCallers[msg.sender] ||
            msg.sender == registry ||
            msg.sender == owner(),
            "Not authorized"
        );
        _;
    }

    modifier onlyOwnerOrRegistry() {
        require(msg.sender == owner() || msg.sender == registry, "Only owner or registry");
        _;
    }

    function initialize(address _registry) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        registry = _registry;
        authorizedCallers[_registry] = true;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ==================== CORE RESOLUTION FUNCTIONS ====================

    /**
     * @notice Get address for a UnifiedId (backward compatible - uses default chain)
     * @param _unifiedId The UnifiedId to resolve
     * @return The primary address associated with the UnifiedId
     */
    function addr(string calldata _unifiedId) external view override returns (address) {
        // Check legacy mapping first, then chain-specific mapping for chainId 0
        address legacyAddr = unifiedIdToAddress[_unifiedId];
        if (legacyAddr != address(0)) {
            return legacyAddr;
        }
        return chainUnifiedIdToAddress[_unifiedId][0];
    }

    /**
     * @notice Get UnifiedId for an address (backward compatible - uses default chain)
     * @param _addr The address to reverse resolve
     * @return The UnifiedId associated with the address
     */
    function unifiedId(address _addr) external view override returns (string memory) {
        // Check legacy mapping first, then chain-specific mapping for chainId 0
        string memory legacyId = addressToUnifiedId[_addr];
        if (bytes(legacyId).length > 0) {
            return legacyId;
        }
        return chainAddressToUnifiedId[_addr][0];
    }

    // ==================== RECORD MANAGEMENT ====================

    /**
     * @notice Set address for a UnifiedId (backward compatible - updates both legacy and chain 0)
     * @param _unifiedId The UnifiedId
     * @param _addr The address to associate
     */
    function setAddress(string calldata _unifiedId, address _addr) external override onlyAuthorized {
        _setAddress(_unifiedId, _addr);
    }

    /**
     * @dev Internal function to set address for a UnifiedId
     */
    function _setAddress(string memory _unifiedId, address _addr) internal {
        // Clear old reverse mapping if exists
        address oldAddr = unifiedIdToAddress[_unifiedId];
        if (oldAddr != address(0)) {
            delete addressToUnifiedId[oldAddr];
        }

        // Clear old forward mapping if new address has existing mapping
        string memory oldUnifiedId = addressToUnifiedId[_addr];
        if (bytes(oldUnifiedId).length > 0) {
            delete unifiedIdToAddress[oldUnifiedId];
        }

        // Set new mappings (both legacy and chain-specific for chain 0)
        unifiedIdToAddress[_unifiedId] = _addr;
        addressToUnifiedId[_addr] = _unifiedId;

        // Also set chain-specific mapping for chain 0 for consistency
        chainUnifiedIdToAddress[_unifiedId][0] = _addr;
        chainAddressToUnifiedId[_addr][0] = _unifiedId;

        emit AddressChanged(_unifiedId, _addr);
        emit UnifiedIdChanged(_addr, _unifiedId);
        emit ChainAddressChanged(_unifiedId, 0, _addr);
    }

    /**
     * @notice Set UnifiedId for an address (reverse mapping)
     * @param _addr The address
     * @param _unifiedId The UnifiedId to associate
     */
    function setUnifiedId(address _addr, string calldata _unifiedId) external override onlyAuthorized {
        _setAddress(_unifiedId, _addr);
    }

    /**
     * @notice Clear all records for a UnifiedId
     * @param _unifiedId The UnifiedId to clear
     */
    function clearRecords(string calldata _unifiedId) external override onlyAuthorized {
        address primaryAddr = unifiedIdToAddress[_unifiedId];

        // Clear primary mappings
        delete unifiedIdToAddress[_unifiedId];
        if (primaryAddr != address(0)) {
            delete addressToUnifiedId[primaryAddr];
        }

        // Clear secondary addresses
        address[] storage secondaries = secondaryAddresses[_unifiedId];
        for (uint i = 0; i < secondaries.length; i++) {
            delete isSecondary[_unifiedId][secondaries[i]];
        }
        delete secondaryAddresses[_unifiedId];

        emit AddressChanged(_unifiedId, address(0));
        if (primaryAddr != address(0)) {
            emit UnifiedIdChanged(primaryAddr, "");
        }
    }

    // ==================== SECONDARY ADDRESS MANAGEMENT ====================

    /**
     * @notice Add secondary address to UnifiedId
     * @param _unifiedId The UnifiedId
     * @param _secondary The secondary address to add
     */
    function addSecondaryAddress(string calldata _unifiedId, address _secondary) external override onlyAuthorized {
        require(unifiedIdToAddress[_unifiedId] != address(0), "UnifiedId not registered");
        require(!isSecondary[_unifiedId][_secondary], "Already a secondary address");
        require(unifiedIdToAddress[_unifiedId] != _secondary, "Cannot add primary as secondary");

        secondaryAddresses[_unifiedId].push(_secondary);
        isSecondary[_unifiedId][_secondary] = true;

        emit SecondaryAddressAdded(_unifiedId, _secondary);
    }

    /**
     * @notice Remove secondary address from UnifiedId
     * @param _unifiedId The UnifiedId
     * @param _secondary The secondary address to remove
     */
    function removeSecondaryAddress(string calldata _unifiedId, address _secondary) external override onlyAuthorized {
        require(isSecondary[_unifiedId][_secondary], "Not a secondary address");

        // Remove from array
        address[] storage secondaries = secondaryAddresses[_unifiedId];
        for (uint i = 0; i < secondaries.length; i++) {
            if (secondaries[i] == _secondary) {
                secondaries[i] = secondaries[secondaries.length - 1];
                secondaries.pop();
                break;
            }
        }

        delete isSecondary[_unifiedId][_secondary];

        emit SecondaryAddressRemoved(_unifiedId, _secondary);
    }

    /**
     * @notice Check if address is secondary for UnifiedId
     * @param _unifiedId The UnifiedId
     * @param _addr The address to check
     * @return True if address is secondary
     */
    function isSecondaryAddress(string calldata _unifiedId, address _addr) external view override returns (bool) {
        return isSecondary[_unifiedId][_addr];
    }

    /**
     * @notice Get all secondary addresses for UnifiedId
     * @param _unifiedId The UnifiedId
     * @return Array of secondary addresses
     */
    function getSecondaryAddresses(string calldata _unifiedId) external view override returns (address[] memory) {
        return secondaryAddresses[_unifiedId];
    }

    // ==================== AUTHORIZATION MANAGEMENT ====================

    /**
     * @notice Check if address is authorized to modify records
     * @param _addr The address to check
     * @return True if authorized
     */
    function isAuthorized(address _addr) external view override returns (bool) {
        return authorizedCallers[_addr] || _addr == registry || _addr == owner();
    }

    /**
     * @notice Set authorization for an address
     * @param _addr The address
     * @param _authorized True to authorize, false to revoke
     */
    function setAuthorization(address _addr, bool _authorized) external override onlyOwnerOrRegistry {
        authorizedCallers[_addr] = _authorized;
    }

    /**
     * @notice Set the registry contract address
     * @param _registry New registry address
     */
    function setRegistry(address _registry) external onlyOwner {
        registry = _registry;
        authorizedCallers[_registry] = true;
    }

    // ==================== DEBUG FUNCTIONS ====================

    /**
     * @notice Get current owner address (for debugging)
     */
    function getOwner() external view returns (address) {
        return owner();
    }

    /**
     * @notice Get current registry address (for debugging)
     */
    function getRegistry() external view returns (address) {
        return registry;
    }

    /**
     * @notice Check if caller can set authorization (for debugging)
     */
    function canSetAuthorization(address caller) external view returns (bool) {
        return caller == owner() || caller == registry;
    }

    // ==================== UTILITY FUNCTIONS ====================

    /**
     * @notice Check if UnifiedId has any records
     * @param _unifiedId The UnifiedId to check
     * @return True if records exist
     */
    function hasRecords(string calldata _unifiedId) external view returns (bool) {
        return unifiedIdToAddress[_unifiedId] != address(0);
    }

    /**
     * @notice Get complete record information for UnifiedId
     * @param _unifiedId The UnifiedId
     * @return primary Primary address
     * @return secondaries Array of secondary addresses
     */
    function getRecords(string calldata _unifiedId) external view returns (
        address primary,
        address[] memory secondaries
    ) {
        return (
            unifiedIdToAddress[_unifiedId],
            secondaryAddresses[_unifiedId]
        );
    }

    // ==================== MULTI-CHAIN FUNCTIONS ====================

    /**
     * @notice Get primary address for UnifiedId on specific chain
     * @param _unifiedId The UnifiedId
     * @param _chainId The chain ID
     * @return Primary address on the specified chain
     */
    function getPrimaryAddress(string calldata _unifiedId, uint256 _chainId) external view override returns (address) {
        return chainUnifiedIdToAddress[_unifiedId][_chainId];
    }

    /**
     * @notice Get UnifiedId from address on specific chain
     * @param _addr The address
     * @param _chainId The chain ID
     * @return UnifiedId associated with the address on the specified chain
     */
    function getUnifiedIdFromAddress(address _addr, uint256 _chainId) external view override returns (string memory) {
        return chainAddressToUnifiedId[_addr][_chainId];
    }

    /**
     * @notice Get all addresses for UnifiedId on specific chain
     * @param _unifiedId The UnifiedId
     * @param _chainId The chain ID
     * @return primary Primary address
     * @return secondaries Array of secondary addresses
     */
    function getAddresses(string calldata _unifiedId, uint256 _chainId)
    external view override returns (address primary, address[] memory secondaries) {
        return (
            chainUnifiedIdToAddress[_unifiedId][_chainId],
            chainSecondaryAddresses[_unifiedId][_chainId]
        );
    }

    /**
     * @notice Check if address is associated with UnifiedId on specific chain
     * @param _unifiedId The UnifiedId
     * @param _chainId The chain ID
     * @param _addr The address to check
     * @return isPrimary True if address is primary
     * @return isSecondaryAddr True if address is secondary
     */
    function isAddressAssociated(string calldata _unifiedId, uint256 _chainId, address _addr)
    external view override returns (bool isPrimary, bool isSecondaryAddr) {
        isPrimary = chainUnifiedIdToAddress[_unifiedId][_chainId] == _addr;
        isSecondaryAddr = chainIsSecondary[_unifiedId][_chainId][_addr];
        return (isPrimary, isSecondaryAddr);
    }

    /**
     * @notice Set primary address for UnifiedId on specific chain
     * @param _unifiedId The UnifiedId
     * @param _chainId The chain ID
     * @param _primary The primary address
     */
    function setUnifiedIdPrimaryAddress(string calldata _unifiedId, uint256 _chainId, address _primary)
    external override onlyAuthorized {
        _setUnifiedIdPrimaryAddress(_unifiedId, _chainId, _primary);
    }

    /**
     * @dev Internal function to set primary address for UnifiedId on specific chain
     */
    function _setUnifiedIdPrimaryAddress(string memory _unifiedId, uint256 _chainId, address _primary) internal {
        // Clear old reverse mapping if exists
        address oldAddr = chainUnifiedIdToAddress[_unifiedId][_chainId];
        if (oldAddr != address(0)) {
            delete chainAddressToUnifiedId[oldAddr][_chainId];
        }

        // Clear old forward mapping if new address has existing mapping
        string memory oldUnifiedId = chainAddressToUnifiedId[_primary][_chainId];
        if (bytes(oldUnifiedId).length > 0) {
            delete chainUnifiedIdToAddress[oldUnifiedId][_chainId];
        }

        // Set new mappings
        chainUnifiedIdToAddress[_unifiedId][_chainId] = _primary;
        chainAddressToUnifiedId[_primary][_chainId] = _unifiedId;

        emit ChainAddressChanged(_unifiedId, _chainId, _primary);
    }

    /**
     * @notice Update primary address for UnifiedId on specific chain
     * @param _unifiedId The UnifiedId
     * @param _chainId The chain ID
     * @param _newPrimary The new primary address
     */
    function updateUnifiedIdPrimaryAddress(string calldata _unifiedId, uint256 _chainId, address _newPrimary)
    external override onlyAuthorized {
        _setUnifiedIdPrimaryAddress(_unifiedId, _chainId, _newPrimary);
    }

    /**
     * @notice Add secondary address for UnifiedId on specific chain
     * @param _unifiedId The UnifiedId
     * @param _chainId The chain ID
     * @param _secondary The secondary address
     */
    function addUnifiedIdSecondaryAddress(string calldata _unifiedId, uint256 _chainId, address _secondary)
    external override onlyAuthorized {
        require(chainUnifiedIdToAddress[_unifiedId][_chainId] != address(0), "UnifiedId not registered on chain");
        require(!chainIsSecondary[_unifiedId][_chainId][_secondary], "Already a secondary address");
        require(chainUnifiedIdToAddress[_unifiedId][_chainId] != _secondary, "Cannot add primary as secondary");

        chainSecondaryAddresses[_unifiedId][_chainId].push(_secondary);
        chainIsSecondary[_unifiedId][_chainId][_secondary] = true;

        emit ChainSecondaryAddressAdded(_unifiedId, _chainId, _secondary);
    }

    /**
     * @notice Remove secondary address for UnifiedId on specific chain
     * @param _unifiedId The UnifiedId
     * @param _chainId The chain ID
     * @param _secondary The secondary address to remove
     */
    function removeUnifiedIdSecondaryAddress(string calldata _unifiedId, uint256 _chainId, address _secondary)
    external override onlyAuthorized {
        require(chainIsSecondary[_unifiedId][_chainId][_secondary], "Not a secondary address");

        // Remove from array
        address[] storage secondaries = chainSecondaryAddresses[_unifiedId][_chainId];
        for (uint i = 0; i < secondaries.length; i++) {
            if (secondaries[i] == _secondary) {
                secondaries[i] = secondaries[secondaries.length - 1];
                secondaries.pop();
                break;
            }
        }

        delete chainIsSecondary[_unifiedId][_chainId][_secondary];

        emit ChainSecondaryAddressRemoved(_unifiedId, _chainId, _secondary);
    }

    /**
     * @notice Clear all mappings for UnifiedId on specific chain
     * @param _unifiedId The UnifiedId
     * @param _chainId The chain ID
     */
    function clearUnifiedIdMappings(string calldata _unifiedId, uint256 _chainId)
    external override onlyAuthorized {
        address primaryAddr = chainUnifiedIdToAddress[_unifiedId][_chainId];

        // Clear primary mappings
        delete chainUnifiedIdToAddress[_unifiedId][_chainId];
        if (primaryAddr != address(0)) {
            delete chainAddressToUnifiedId[primaryAddr][_chainId];
        }

        // Clear secondary addresses
        address[] storage secondaries = chainSecondaryAddresses[_unifiedId][_chainId];
        for (uint i = 0; i < secondaries.length; i++) {
            delete chainIsSecondary[_unifiedId][_chainId][secondaries[i]];
        }
        delete chainSecondaryAddresses[_unifiedId][_chainId];

        emit ChainAddressChanged(_unifiedId, _chainId, address(0));
    }
} 