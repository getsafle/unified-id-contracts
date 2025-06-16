// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import "./IUnifiedIdResolver.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title UnifiedIdResolver
 * @author kunalmkv
 * @notice Resolver contract for UnifiedId name resolution across multiple blockchains with role-based access control
 * @dev Handles all address<->UnifiedId mappings, secondary addresses, and multi-chain resolution
 * @dev Implements both single-chain backward compatibility and multi-chain functionality
 * @dev Uses UUPS upgradeable pattern with comprehensive authorization controls and OpenZeppelin AccessControl
 */
contract UnifiedIdResolver is IUnifiedIdResolver, Initializable, UUPSUpgradeable, AccessControlUpgradeable {

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ==================== ROLE DEFINITIONS ====================

    /// @notice Role for authorized callers who can modify records
    bytes32 public constant AUTHORIZED_CALLER_ROLE = keccak256("AUTHORIZED_CALLER_ROLE");

    /// @notice Role for registry contracts
    bytes32 public constant REGISTRY_ROLE = keccak256("REGISTRY_ROLE");

    /// @notice Role for admin users with elevated privileges
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role for upgrading the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

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

    // Security constants to prevent DoS attacks from unbounded loops
    uint256 public constant MAX_SECONDARY_ADDRESSES = 50;

    // STORAGE OPTIMIZATION: Removed redundant legacy mappings
    // All operations now use multi-chain mappings with chainId = 0 for backward compatibility
    // This eliminates 4 redundant mappings while maintaining full functionality

    // Multi-chain mappings (handles both legacy and multi-chain functionality)
    mapping(string => mapping(uint256 => address)) private chainUnifiedIdToAddress;
    mapping(address => mapping(uint256 => string)) private chainAddressToUnifiedId;
    mapping(string => mapping(uint256 => address[])) private chainSecondaryAddresses;
    mapping(string => mapping(uint256 => mapping(address => bool))) private chainIsSecondary;

    // OPTIMIZATION: Reverse lookup mapping for secondary addresses
    // This enables O(1) lookup from secondary address to UnifiedId instead of O(n) iteration
    mapping(address => mapping(uint256 => string)) private chainSecondaryToUnifiedId;

    // Registry contract that can authorize calls
    address public registry;

    event AuthorizationUpdated(address indexed addr, bool authorized, address indexed updatedBy);
    event RegistryUpdated(address indexed oldRegistry, address indexed newRegistry, address indexed updatedBy);

    modifier onlyAuthorized() {
        require(
            hasRole(AUTHORIZED_CALLER_ROLE, msg.sender) ||
            hasRole(REGISTRY_ROLE, msg.sender) ||
            msg.sender == registry ||
            msg.sender == owner(),
            "AccessControl: caller is not authorized"
        );
        _;
    }

    modifier onlyOwnerOrRegistry() {
        require(
            msg.sender == owner() ||
            msg.sender == registry ||
            hasRole(REGISTRY_ROLE, msg.sender) ||
            hasRole(ADMIN_ROLE, msg.sender),
            "AccessControl: caller is not owner or registry"
        );
        _;
    }

    function initialize(address _registry) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();

        // Initialize ownership
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);

        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        registry = _registry;
        if (_registry != address(0)) {
            _grantRole(AUTHORIZED_CALLER_ROLE, _registry);
            _grantRole(REGISTRY_ROLE, _registry);
        }
    }

    function _authorizeUpgrade(address ) internal override view {
        require(hasRole(UPGRADER_ROLE, msg.sender) || msg.sender == owner(), "AccessControl: caller is not upgrader");
    }

    // ==================== CORE RESOLUTION FUNCTIONS ====================

    /**
     * @notice Get address for a UnifiedId (backward compatible - uses default chain)
     * @param _unifiedId The UnifiedId to resolve
     * @return The primary address associated with the UnifiedId
     */
    function resolvePrimaryAddressFromUnifiedID(string calldata _unifiedId) external view override returns (address) {
        // Check legacy mapping first, then chain-specific mapping for chainId 0
        address legacyAddr = chainUnifiedIdToAddress[_unifiedId][0];
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
    function resolveUnifiedIDFromAddress(address _addr) external view override returns (string memory) {
        // Check legacy mapping first, then chain-specific mapping for chainId 0
        string memory legacyId = chainAddressToUnifiedId[_addr][0];
        if (bytes(legacyId).length != 0) {
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
        address oldAddr = chainUnifiedIdToAddress[_unifiedId][0];
        if (oldAddr != address(0)) {
            delete chainAddressToUnifiedId[oldAddr][0];
        }

        // Clear old forward mapping if new address has existing mapping
        string memory oldUnifiedId = chainAddressToUnifiedId[_addr][0];
        if (bytes(oldUnifiedId).length != 0) {
            delete chainUnifiedIdToAddress[oldUnifiedId][0];
        }

        // Set new mappings (both legacy and chain-specific for chain 0)
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
        address primaryAddr = chainUnifiedIdToAddress[_unifiedId][0];

        // Clear primary mappings
        delete chainUnifiedIdToAddress[_unifiedId][0];
        if (primaryAddr != address(0)) {
            delete chainAddressToUnifiedId[primaryAddr][0];
        }

        // Clear secondary addresses
        address[] storage secondaries = chainSecondaryAddresses[_unifiedId][0];

        // Prevent unbounded loop DoS by limiting iterations
        uint256 maxIterations = secondaries.length > MAX_SECONDARY_ADDRESSES ? MAX_SECONDARY_ADDRESSES : secondaries.length;

        for (uint256 i = 0; i < maxIterations; ++i) {
            delete chainIsSecondary[_unifiedId][0][secondaries[i]];
            // OPTIMIZATION: Clean up reverse lookup mappings
            delete chainSecondaryToUnifiedId[secondaries[i]][0];
        }
        delete chainSecondaryAddresses[_unifiedId][0];

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
        require(chainUnifiedIdToAddress[_unifiedId][0] != address(0), "UnifiedId not registered");
        require(!chainIsSecondary[_unifiedId][0][_secondary], "Already a secondary address");
        require(chainUnifiedIdToAddress[_unifiedId][0] != _secondary, "Cannot add primary as secondary");

        chainSecondaryAddresses[_unifiedId][0].push(_secondary);
        chainIsSecondary[_unifiedId][0][_secondary] = true;

        // OPTIMIZATION: Maintain reverse lookup mapping
        chainSecondaryToUnifiedId[_secondary][0] = _unifiedId;

        emit SecondaryAddressAdded(_unifiedId, _secondary);
    }

    /**
     * @notice Remove secondary address from UnifiedId
     * @param _unifiedId The UnifiedId
     * @param _secondary The secondary address to remove
     */
    function removeSecondaryAddress(string calldata _unifiedId, address _secondary) external override onlyAuthorized {
        require(chainIsSecondary[_unifiedId][0][_secondary], "Not a secondary address");

        // Remove from array
        address[] storage secondaries = chainSecondaryAddresses[_unifiedId][0];

        // Prevent unbounded loop DoS by limiting iterations
        uint256 maxIterations = secondaries.length > MAX_SECONDARY_ADDRESSES ? MAX_SECONDARY_ADDRESSES : secondaries.length;

        for (uint256 i = 0; i < maxIterations; ++i) {
            if (secondaries[i] == _secondary) {
                secondaries[i] = secondaries[secondaries.length - 1];
                secondaries.pop();
                break;
            }
        }

        delete chainIsSecondary[_unifiedId][0][_secondary];

        // OPTIMIZATION: Clean up reverse lookup mapping
        delete chainSecondaryToUnifiedId[_secondary][0];

        emit SecondaryAddressRemoved(_unifiedId, _secondary);
    }

    /**
     * @notice Check if address is secondary for UnifiedId
     * @param _unifiedId The UnifiedId
     * @param _addr The address to check
     * @return True if address is secondary
     */
    function isSecondaryAddress(string calldata _unifiedId, address _addr) external view override returns (bool) {
        return chainIsSecondary[_unifiedId][0][_addr];
    }

    /**
     * @notice Get all secondary addresses for UnifiedId
     * @param _unifiedId The UnifiedId
     * @return Array of secondary addresses
     */
    function getSecondaryAddresses(string calldata _unifiedId) external view override returns (address[] memory) {
        return chainSecondaryAddresses[_unifiedId][0];
    }

    // ==================== AUTHORIZATION MANAGEMENT ====================

    /**
     * @notice Check if address is authorized to modify records
     * @param _addr The address to check
     * @return True if authorized
     */
    function isAuthorized(address _addr) external view override returns (bool) {
        return hasRole(AUTHORIZED_CALLER_ROLE, _addr) ||
        hasRole(REGISTRY_ROLE, _addr) ||
        _addr == registry ||
            _addr == owner();
    }

    /**
     * @notice Set authorization for an address
     * @param _addr The address
     * @param _authorized True to authorize, false to revoke
     */
    function setAuthorization(address _addr, bool _authorized) external override onlyOwnerOrRegistry {
        if (_authorized) {
            _grantRole(AUTHORIZED_CALLER_ROLE, _addr);
        } else {
            _revokeRole(AUTHORIZED_CALLER_ROLE, _addr);
        }
        emit AuthorizationUpdated(_addr, _authorized, msg.sender);
    }

    /**
     * @notice Set the registry contract address
     * @param _registry New registry address
     */
    function setRegistry(address _registry) external onlyOwner {
        require(_registry != address(0), "Registry: zero address");
        address oldRegistry = registry;

        // Revoke old registry roles
        if (oldRegistry != address(0)) {
            _revokeRole(AUTHORIZED_CALLER_ROLE, oldRegistry);
            _revokeRole(REGISTRY_ROLE, oldRegistry);
        }

        registry = _registry;

        // Grant new registry roles
        _grantRole(AUTHORIZED_CALLER_ROLE, _registry);
        _grantRole(REGISTRY_ROLE, _registry);

        emit RegistryUpdated(oldRegistry, _registry, msg.sender);
    }

    // ==================== ROLE MANAGEMENT FUNCTIONS ====================

    /**
     * @notice Grant authorized caller role to an address
     * @param caller Address to grant authorized caller role
     */
    function grantAuthorizedCallerRole(address caller) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(AUTHORIZED_CALLER_ROLE, caller);
        emit AuthorizationUpdated(caller, true, msg.sender);
    }

    /**
     * @notice Revoke authorized caller role from an address
     * @param caller Address to revoke authorized caller role
     */
    function revokeAuthorizedCallerRole(address caller) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(AUTHORIZED_CALLER_ROLE, caller);
        emit AuthorizationUpdated(caller, false, msg.sender);
    }

    /**
     * @notice Grant registry role to an address
     * @param registryAddr Address to grant registry role
     */
    function grantRegistryRole(address registryAddr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(REGISTRY_ROLE, registryAddr);
        _grantRole(AUTHORIZED_CALLER_ROLE, registryAddr); // Registry also needs authorized caller role
    }

    /**
     * @notice Revoke registry role from an address
     * @param registryAddr Address to revoke registry role
     */
    function revokeRegistryRole(address registryAddr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(REGISTRY_ROLE, registryAddr);
        _revokeRole(AUTHORIZED_CALLER_ROLE, registryAddr);
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
     * @notice Check if address has authorized caller role
     * @param account Address to check
     * @return True if address has authorized caller role
     */
    function isAuthorizedCaller(address account) external view returns (bool) {
        return hasRole(AUTHORIZED_CALLER_ROLE, account);
    }

    /**
     * @notice Check if address has registry role
     * @param account Address to check
     * @return True if address has registry role
     */
    function isRegistryRole(address account) external view returns (bool) {
        return hasRole(REGISTRY_ROLE, account);
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
     * @notice Check if address has upgrader role
     * @param account Address to check
     * @return True if address has upgrader role
     */
    function isUpgrader(address account) external view returns (bool) {
        return hasRole(UPGRADER_ROLE, account);
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
        return caller == owner() ||
        caller == registry ||
        hasRole(REGISTRY_ROLE, caller) ||
            hasRole(ADMIN_ROLE, caller);
    }

    // ==================== UTILITY FUNCTIONS ====================

    /**
     * @notice Check if UnifiedId has any records
     * @param _unifiedId The UnifiedId to check
     * @return True if records exist
     */
    function hasRecords(string calldata _unifiedId) external view returns (bool) {
        return chainUnifiedIdToAddress[_unifiedId][0] != address(0);
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
            chainUnifiedIdToAddress[_unifiedId][0],
            chainSecondaryAddresses[_unifiedId][0]
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
        if (bytes(oldUnifiedId).length != 0) {
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

        // OPTIMIZATION: Maintain reverse lookup mapping
        chainSecondaryToUnifiedId[_secondary][_chainId] = _unifiedId;

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

        // Prevent unbounded loop DoS by limiting iterations
        uint256 maxIterations = secondaries.length > MAX_SECONDARY_ADDRESSES ? MAX_SECONDARY_ADDRESSES : secondaries.length;

        for (uint256 i = 0; i < maxIterations; ++i) {
            if (secondaries[i] == _secondary) {
                secondaries[i] = secondaries[secondaries.length - 1];
                secondaries.pop();
                break;
            }
        }

        delete chainIsSecondary[_unifiedId][_chainId][_secondary];

        // OPTIMIZATION: Clean up reverse lookup mapping
        delete chainSecondaryToUnifiedId[_secondary][_chainId];

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

        // Prevent unbounded loop DoS by limiting iterations
        uint256 maxIterations = secondaries.length > MAX_SECONDARY_ADDRESSES ? MAX_SECONDARY_ADDRESSES : secondaries.length;

        for (uint256 i = 0; i < maxIterations; ++i) {
            delete chainIsSecondary[_unifiedId][_chainId][secondaries[i]];
            // OPTIMIZATION: Clean up reverse lookup mappings
            delete chainSecondaryToUnifiedId[secondaries[i]][_chainId];
        }
        delete chainSecondaryAddresses[_unifiedId][_chainId];

        emit ChainAddressChanged(_unifiedId, _chainId, address(0));
    }

    // ==================== SECONDARY ADDRESS RESOLUTION ====================

    /**
     * @notice Resolves a secondary address to its UnifiedId (single-chain)
     * @dev Finds which UnifiedId a secondary address belongs to on the default chain
     * @param secondaryAddr The secondary address to resolve
     * @return The UnifiedId that the secondary address belongs to, empty string if not found
     * @custom:gas-optimization Uses O(1) lookup instead of iteration
     * @custom:use-cases
     * - Secondary address holders can find their UnifiedId
     * - DApps can resolve any address type to UnifiedId
     * - Wallet integrations for secondary address management
     */
    function resolveSecondaryAddressToUnifiedId(address secondaryAddr) external view returns (string memory) {
        return chainSecondaryToUnifiedId[secondaryAddr][0];
    }

    /**
     * @notice Resolves a secondary address to its UnifiedId on a specific chain
     * @dev Finds which UnifiedId a secondary address belongs to on the specified chain
     * @param secondaryAddr The secondary address to resolve
     * @param chainId The chain ID to query
     * @return The UnifiedId that the secondary address belongs to, empty string if not found
     * @custom:gas-optimization Uses O(1) lookup instead of iteration
     * @custom:multi-chain Supports cross-chain secondary address resolution
     */
    function resolveSecondaryAddressToUnifiedId(address secondaryAddr, uint256 chainId) external view returns (string memory) {
        return chainSecondaryToUnifiedId[secondaryAddr][chainId];
    }

    /**
     * @notice Resolves any address (primary or secondary) to its UnifiedId (single-chain)
     * @dev Universal address resolver that works for both primary and secondary addresses on default chain
     * @param addr The address to resolve (can be primary or secondary)
     * @return unifiedId The UnifiedId associated with the address
     * @return isPrimary True if the address is a primary address
     * @return isSecondary True if the address is a secondary address
     * @custom:gas-optimization Checks primary first (most common case), then secondary
     * @custom:comprehensive Handles all address types in one function call
     */
    function resolveAnyAddressToUnifiedId(address addr) external view returns (
        string memory unifiedId,
        bool isPrimary,
        bool isSecondary
    ) {
        // First check if it's a primary address (most common case)
        unifiedId = chainAddressToUnifiedId[addr][0];
        if (bytes(unifiedId).length != 0) {
            return (unifiedId, true, false);
        }

        // Then check if it's a secondary address
        unifiedId = chainSecondaryToUnifiedId[addr][0];
        if (bytes(unifiedId).length != 0) {
            return (unifiedId, false, true);
        }

        // Address not found
        return ("", false, false);
    }

    /**
     * @notice Resolves any address (primary or secondary) to its UnifiedId on a specific chain
     * @dev Universal address resolver that works for both primary and secondary addresses on specified chain
     * @param addr The address to resolve (can be primary or secondary)
     * @param chainId The chain ID to query
     * @return unifiedId The UnifiedId associated with the address
     * @return isPrimary True if the address is a primary address
     * @return isSecondary True if the address is a secondary address
     * @custom:gas-optimization Checks primary first (most common case), then secondary
     * @custom:multi-chain Supports cross-chain universal address resolution
     */
    function resolveAnyAddressToUnifiedId(address addr, uint256 chainId) external view returns (
        string memory unifiedId,
        bool isPrimary,
        bool isSecondary
    ) {
        // First check if it's a primary address (most common case)
        unifiedId = chainAddressToUnifiedId[addr][chainId];
        if (bytes(unifiedId).length != 0) {
            return (unifiedId, true, false);
        }

        // Then check if it's a secondary address
        unifiedId = chainSecondaryToUnifiedId[addr][chainId];
        if (bytes(unifiedId).length != 0) {
            return (unifiedId, false, true);
        }

        // Address not found
        return ("", false, false);
    }

    // ==================== COMBINED ADDRESS FUNCTIONS ====================

    /**
     * @notice Gets all addresses (primary + secondary) for a UnifiedId in a single array (single-chain)
     * @dev Returns all addresses associated with the UnifiedId on the default chain in one array
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
    function getAllAddresses(string calldata unifiedId) external view override returns (address[] memory allAddresses) {
        return _getAllAddresses(unifiedId, 0);
    }

    /**
     * @notice Gets all addresses (primary + secondary) for a UnifiedId in a single array on specific chain
     * @dev Returns all addresses associated with the UnifiedId on the specified chain in one array
     * @param unifiedId The UnifiedId to get all addresses for
     * @param chainId The chain ID to query
     * @return allAddresses Array containing primary address followed by all secondary addresses
     * @custom:gas-optimization Efficient single-call solution for multi-chain scenarios
     * @custom:multi-chain Supports cross-chain combined address retrieval
     * @custom:array-structure [primary, secondary1, secondary2, ...]
     */
    function getAllAddresses(string calldata unifiedId, uint256 chainId) external view override returns (address[] memory allAddresses) {
        return _getAllAddresses(unifiedId, chainId);
    }

    /**
     * @dev Internal function to get all addresses for a UnifiedId on a specific chain
     * @param unifiedId The UnifiedId to get addresses for
     * @param chainId The chain ID to query
     * @return allAddresses Array containing primary address followed by all secondary addresses
     */
    function _getAllAddresses(string memory unifiedId, uint256 chainId) internal view returns (address[] memory allAddresses) {
        address primary = chainUnifiedIdToAddress[unifiedId][chainId];
        address[] memory secondaries = chainSecondaryAddresses[unifiedId][chainId];

        // If no primary address, return empty array
        if (primary == address(0)) {
            return new address[](0);
        }

        // Create combined array: [primary, secondary1, secondary2, ...]
        uint256 totalAddresses = 1 + secondaries.length;
        allAddresses = new address[](totalAddresses);

        // Set primary address as first element
        allAddresses[0] = primary;

        // Add all secondary addresses
        for (uint256 i = 0; i < secondaries.length; ++i) {
            allAddresses[i + 1] = secondaries[i];
        }

        return allAddresses;
    }

    /**
     * @notice Gets the total count of addresses (primary + secondary) for a UnifiedId (single-chain)
     * @dev Returns the total number of addresses associated with the UnifiedId on default chain
     * @param unifiedId The UnifiedId to count addresses for
     * @return count Total number of addresses (1 primary + N secondary addresses)
     * @custom:gas-optimization Lightweight function for getting address count without array allocation
     * @custom:use-cases
     * - Pre-allocating arrays for address operations
     * - Checking if UnifiedId has multiple addresses
     * - Gas estimation for batch operations
     */
    function getAddressCount(string calldata unifiedId) external view override returns (uint256 count) {
        return _getAddressCount(unifiedId, 0);
    }

    /**
     * @notice Gets the total count of addresses (primary + secondary) for a UnifiedId on specific chain
     * @dev Returns the total number of addresses associated with the UnifiedId on the specified chain
     * @param unifiedId The UnifiedId to count addresses for
     * @param chainId The chain ID to query
     * @return count Total number of addresses (1 primary + N secondary addresses)
     * @custom:gas-optimization Lightweight function for multi-chain address counting
     * @custom:multi-chain Supports cross-chain address counting
     */
    function getAddressCount(string calldata unifiedId, uint256 chainId) external view override returns (uint256 count) {
        return _getAddressCount(unifiedId, chainId);
    }

    /**
     * @dev Internal function to get address count for a UnifiedId on a specific chain
     * @param unifiedId The UnifiedId to count addresses for
     * @param chainId The chain ID to query
     * @return count Total number of addresses
     */
    function _getAddressCount(string memory unifiedId, uint256 chainId) internal view returns (uint256 count) {
        address primary = chainUnifiedIdToAddress[unifiedId][chainId];

        // If no primary address, return 0
        if (primary == address(0)) {
            return 0;
        }

        // Return 1 (primary) + number of secondary addresses
        return 1 + chainSecondaryAddresses[unifiedId][chainId].length;
    }
} 