// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import "./RegistrarStorageUtil.sol";
import "./IUnifiedIdResolver.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title RegistrarStorageMother
 * @author kunalmkv
 * @notice Core contract for managing unified IDs across multiple blockchains
 * @dev Implements cross-chain unified ID registration with secure signature verification
 * @dev Uses UUPS upgradeable pattern with pause functionality and two-step ownership
 */
contract RegistrarStorageMother is Initializable, UUPSUpgradeable, PausableUpgradeable {
    /// @notice Utility contract for signature verification and validation
    RegistrarStorageUtil public util;
    
    /// @notice Resolver contract for address<->UnifiedId mappings
    IUnifiedIdResolver public resolver;
    
    /// @notice Mapping of authorized relayer addresses
    mapping(address => bool) public authorizedRelayers;

    // === OWNABLE2STEP IMPLEMENTATION ===
    /// @dev Address of the current contract owner
    address private _owner;
    
    /// @dev Address of the pending owner during ownership transfer
    address private _pendingOwner;

    /**
     * @notice Emitted when ownership transfer is initiated
     * @param previousOwner Current owner who initiated the transfer
     * @param newOwner Address that will become the new owner
     */
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    
    /**
     * @notice Emitted when ownership transfer is completed
     * @param previousOwner Previous owner address
     * @param newOwner New owner address
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @notice Returns the address of the current owner
     * @return Address of the current contract owner
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @notice Returns the address of the pending owner during ownership transfer
     * @return Address of the pending owner, or zero address if no transfer is pending
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @notice Modifier to restrict access to owner only
     * @dev Reverts if caller is not the current owner
     */
    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @notice Renounces ownership of the contract
     * @dev Leaves the contract without owner, disabling owner-only functions permanently
     * @dev Can only be called by the current owner
     * @dev WARNING: This action is irreversible
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @notice Initiates ownership transfer to a new account (Step 1 of 2)
     * @dev The new owner must call acceptOwnership() to complete the transfer
     * @param newOwner Address of the proposed new owner
     * @custom:requirements Only current owner can call this function
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @notice Accepts ownership transfer (Step 2 of 2)
     * @dev Completes the two-step ownership transfer process
     * @dev Only the pending owner can call this function
     * @custom:requirements
     * - Caller must be the pending owner
     * - A transfer must be pending
     */
    function acceptOwnership() external {
        address sender = msg.sender;
        require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
        _transferOwnership(sender);
    }

    /**
     * @dev Internal function to transfer ownership
     * @param newOwner Address of the new owner
     */
    function _transferOwnership(address newOwner) internal virtual {
        delete _pendingOwner;
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Structure containing chain-specific data for a unified ID
     * @param primary Primary address on this chain
     * @param secondaries Array of secondary addresses on this chain
     * @param exists Whether chain data exists for this unified ID
     */
    struct ChainData {
        address primary;
        address[] secondaries;
        bool exists;
    }

    /**
     * @notice Structure containing all data for a unified ID across all chains
     * @param masterAddress Master address that controls this unified ID
     * @param chains Mapping from chain ID to ChainData
     * @param registeredChainIds Array of chain IDs where this unified ID is registered
     * @param exists Whether this unified ID exists
     */
    struct UnifiedID {
        address masterAddress;
        mapping(uint256 => ChainData) chains;
        uint256[] registeredChainIds;
        bool exists;
    }

    /// @notice Mapping from unified ID string to UnifiedID data
    mapping(string => UnifiedID) private unifiedIds;

    /// @notice Mapping of unified IDs that are permanently unavailable
    mapping(string => bool) public isUnavailableUnifiedId;

    /// @notice Mapping to track nonces for each unified ID to prevent replay attacks
    mapping(string => uint256) public nonces;

    // === ADMIN CONFIGURATION VARIABLES ===
    /// @notice Maximum number of secondary addresses allowed per chain
    uint256 public maxSecondaryAddressesPerChain;
    
    /// @notice Maximum number of chains allowed per unified ID
    uint256 public maxChainsPerUnifiedId;
    
    /// @notice Emergency mode flag - stops all operations except admin functions
    bool public emergencyMode;
    
    /// @notice Mapping of admin user addresses
    mapping(address => bool) public adminUsers;

    // === ADMIN EVENTS ===
    
    /**
     * @notice Emitted when maximum secondary addresses per chain is updated
     * @param oldMax Previous maximum value
     * @param newMax New maximum value
     */
    event MaxSecondaryAddressesPerChainUpdated(uint256 oldMax, uint256 newMax);
    
    /**
     * @notice Emitted when maximum chains per unified ID is updated
     * @param oldMax Previous maximum value
     * @param newMax New maximum value
     */
    event MaxChainsPerUnifiedIdUpdated(uint256 oldMax, uint256 newMax);
    
    /**
     * @notice Emitted when emergency mode is toggled
     * @param enabled True if emergency mode enabled, false if disabled
     */
    event EmergencyModeToggled(bool enabled);
    
    /**
     * @notice Emitted when admin user status is updated
     * @param user Address whose admin status was modified
     * @param isAdmin True if granted admin rights, false if revoked
     */
    event AdminUserUpdated(address user, bool isAdmin);

    // === MISSING CRITICAL EVENTS ===
    
    /**
     * @notice Emitted when resolver contract address is updated
     * @param oldResolver Previous resolver address
     * @param newResolver New resolver address
     * @param updatedBy Address that performed the update
     */
    event ResolverUpdated(address indexed oldResolver, address indexed newResolver, address indexed updatedBy);
    
    /**
     * @notice Emitted when contract is paused
     * @param pausedBy Address that paused the contract
     * @param timestamp Block timestamp when paused
     */
    event ContractPaused(address indexed pausedBy, uint256 timestamp);
    
    /**
     * @notice Emitted when contract is unpaused
     * @param unpausedBy Address that unpaused the contract
     * @param timestamp Block timestamp when unpaused
     */
    event ContractUnpaused(address indexed unpausedBy, uint256 timestamp);
    
    /**
     * @notice Emitted when upgrade is authorized
     * @param implementation New implementation address
     * @param authorizedBy Address that authorized the upgrade
     * @param timestamp Block timestamp when authorized
     */
    event UpgradeAuthorized(address indexed implementation, address indexed authorizedBy, uint256 timestamp);
    
    /**
     * @notice Emitted when unified ID availability is marked in emergency
     * @param unifiedId The unified ID being marked
     * @param available Whether ID is marked as available or unavailable
     * @param updatedBy Address that performed the marking
     */
    event EmergencyUnifiedIdMarked(string indexed unifiedId, bool available, address indexed updatedBy);
    
    /**
     * @notice Emitted when chain data is cleared in emergency
     * @param unifiedId The unified ID whose chain data was cleared
     * @param chainId The chain ID that was cleared
     * @param clearedBy Address that performed the clearing
     */
    event EmergencyChainDataCleared(string indexed unifiedId, uint256 indexed chainId, address indexed clearedBy);

    // === CORE EVENTS ===
    
    /**
     * @notice Emitted when a new unified ID is registered
     * @param unifiedId The newly registered unified ID
     * @param masterAddress Master address controlling the unified ID
     * @param chainId Chain ID where registration occurred
     * @param primary Primary address on the chain
     */
    event UnifiedIdRegistered(string indexed unifiedId, address indexed masterAddress, uint256 indexed chainId, address primary);
    
    /**
     * @notice Emitted when a unified ID is updated/renamed
     * @param newUnifiedId The new unified ID
     * @param oldUnifiedId The previous unified ID
     */
    event UnifiedIdUpdated(string indexed newUnifiedId, string indexed oldUnifiedId);
    
    /**
     * @notice Emitted when master address is updated
     * @param unifiedId The unified ID whose master address was updated
     * @param newMasterAddress The new master address
     */
    event MasterAddressUpdated(string indexed unifiedId, address indexed newMasterAddress);
    
    /**
     * @notice Emitted when primary address is updated on a chain
     * @param unifiedId The unified ID whose primary address was updated
     * @param chainId The chain ID where update occurred
     * @param newPrimary The new primary address
     */
    event PrimaryAddressUpdated(string indexed unifiedId, uint256 indexed chainId, address indexed newPrimary);
    
    /**
     * @notice Emitted when secondary address is added to a chain
     * @param unifiedId The unified ID to which secondary address was added
     * @param chainId The chain ID where address was added
     * @param secondary The secondary address that was added
     */
    event SecondaryAddressAdded(string indexed unifiedId, uint256 indexed chainId, address indexed secondary);
    
    /**
     * @notice Emitted when secondary address is removed from a chain
     * @param unifiedId The unified ID from which secondary address was removed
     * @param chainId The chain ID where address was removed
     * @param secondary The secondary address that was removed
     */
    event SecondaryAddressRemoved(string indexed unifiedId, uint256 indexed chainId, address indexed secondary);
    
    /**
     * @notice Emitted when relayer authorization is updated
     * @param relayer The relayer address whose authorization was updated
     * @param authorized True if authorized, false if revoked
     */
    event RelayerAuthorizationUpdated(address indexed relayer, bool authorized);

    // Events for withdrawal
    
    /**
     * @notice Emitted when ETH is withdrawn from the contract
     * @param to Address that received the ETH
     * @param amount Amount of ETH withdrawn (in wei)
     */
    event EthWithdrawn(address indexed to, uint256 amount);
    
    /**
     * @notice Emitted when ERC20 tokens are withdrawn from the contract
     * @param token Address of the ERC20 token contract
     * @param to Address that received the tokens
     * @param amount Amount of tokens withdrawn
     */
    event ERC20Withdrawn(address indexed token, address indexed to, uint256 amount);

    // === ADMIN MODIFIERS ===
    
    /**
     * @notice Modifier to restrict access to admin users or owner
     * @dev Reverts if caller is neither admin nor owner
     */
    modifier onlyAdmin() {
        require(adminUsers[msg.sender] || msg.sender == owner(), "Caller not admin or owner");
        _;
    }

    /**
     * @notice Modifier to prevent operations during emergency mode
     * @dev Reverts if contract is in emergency mode
     */
    modifier notInEmergencyMode() {
        require(!emergencyMode, "Contract in emergency mode");
        _;
    }

    // Standardize on EIP-712 structured data
    bytes32 public constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 public constant REGISTER_TYPEHASH = keccak256(
        "RegisterUnifiedId(string unifiedId,address primary,uint256 chainId,uint256 nonce)"
    );

    bytes32 public immutable DOMAIN_SEPARATOR;

    constructor() {
        // Disable initializers on implementation contract (OpenZeppelin best practice)
        _disableInitializers();

        DOMAIN_SEPARATOR = keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            keccak256("UnifiedID"),
            keccak256("1"),
            block.chainid,
            address(this)
        ));
    }

    function verifySignature(
        string memory unifiedId,
        address primary,
        uint256 chainId,
        uint256 nonce,
        uint256 deadline,
        address signer,
        bytes memory signature
    ) internal view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            REGISTER_TYPEHASH,
            keccak256(bytes(unifiedId)),
            primary,
            chainId,
            nonce,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            structHash
        ));

        // Direct keccak256 call as shown in audit remediation
        return util.verifySignature(abi.encode(digest), signer, signature);
    }

    function initialize(address _util, address _resolver) public initializer {
        require(_util != address(0), "Util: zero address");
        require(_resolver != address(0), "Resolver: zero address");
        __UUPSUpgradeable_init();
        __Pausable_init();
        
        // Initialize ownership
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        
        util = RegistrarStorageUtil(_util);
        resolver = IUnifiedIdResolver(_resolver);

        // === ADMIN DEFAULTS ===
        maxSecondaryAddressesPerChain = 10;
        maxChainsPerUnifiedId = 50;
        emergencyMode = false;
        adminUsers[msg.sender] = true;
    }

    modifier onlyRelayer() {
        require(authorizedRelayers[msg.sender], "Caller not authorized relayer");
        _;
    }
    /**
     * @notice Pauses all contract operations
     * @dev Triggers the pause state, stopping all functions marked with whenNotPaused
     * @custom:requirements Only owner can call this function
     * @custom:events Emits ContractPaused
     */
    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(msg.sender, block.timestamp);
    }
    
    /**
     * @notice Unpauses all contract operations
     * @dev Returns to normal state, allowing all functions to operate normally
     * @custom:requirements Only owner can call this function
     * @custom:events Emits ContractUnpaused
     */
    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender, block.timestamp);
    }

    /**
     * @notice Sets authorization status for a relayer address
     * @dev Grants or revokes permission for an address to act as a relayer
     * @param relayer Address to set authorization for
     * @param authorized True to authorize, false to revoke authorization
     * @custom:requirements 
     * - Only owner can call this function
     * - relayer cannot be zero address
     * @custom:events Emits RelayerAuthorizationUpdated
     */
    function setAuthorizedRelayer(address relayer, bool authorized) external onlyOwner {
        require(relayer != address(0), "Relayer: zero address");
        authorizedRelayers[relayer] = authorized;
        emit RelayerAuthorizationUpdated(relayer, authorized);
    }

    function setResolver(address _resolver) external onlyOwner {
        require(_resolver != address(0), "Resolver: zero address");
        address oldResolver = address(resolver);
        resolver = IUnifiedIdResolver(_resolver);
        emit ResolverUpdated(oldResolver, _resolver, msg.sender);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        require(newImplementation != address(0), "Implementation: zero address");
        emit UpgradeAuthorized(newImplementation, msg.sender, block.timestamp);
    }

    function registerUnifiedId(
        string calldata unifiedId,
        uint256 chainId,
        address primary,
        bytes memory data,
        bytes memory masterSignature,
        bytes memory primarySignature
    ) external onlyRelayer whenNotPaused notInEmergencyMode {
        require(!isUnavailableUnifiedId[unifiedId], "UnifiedID is unavailable");
        UnifiedID storage uid = unifiedIds[unifiedId];

        ChainData storage chainData = uid.chains[chainId];
        require(!chainData.exists, "Chain data already exists");
        require(uid.registeredChainIds.length < maxChainsPerUnifiedId, "Maximum chains per unified ID reached");

        // Create comprehensive data for signature validation
        bytes memory fullData = abi.encode(unifiedId, chainId, primary);
        string memory operationType = "REGISTER_UNIFIED_ID";

        if (!uid.exists) {
            requireSignature(operationType, fullData, unifiedId, primary, primarySignature);
            uid.masterAddress = primary;
            uid.exists = true;
        } else {
            requireSignature(operationType, fullData, unifiedId, uid.masterAddress, masterSignature);
            requireSignature(operationType, fullData, unifiedId, primary, primarySignature);
        }

        chainData.primary = primary;
        chainData.exists = true;
        uid.registeredChainIds.push(chainId);

        // Update resolver with primary address mapping
        resolver.setUnifiedIdPrimaryAddress(unifiedId, chainId, primary);

        emit UnifiedIdRegistered(unifiedId, uid.masterAddress, chainId, primary);
        nonces[unifiedId]++;
    }

    function updatePrimaryAddress(
        string calldata unifiedId,
        uint256 chainId,
        address newPrimary,
        bytes memory data,
        bytes memory currentPrimarySignature,
        bytes memory newPrimarySignature
    ) external onlyRelayer whenNotPaused {
        require(unifiedIds[unifiedId].exists, "UnifiedID does not exist");
        require(unifiedIds[unifiedId].chains[chainId].exists, "Chain data does not exist");

        address currentPrimary = unifiedIds[unifiedId].chains[chainId].primary;

        // Create comprehensive data for signature validation
        bytes memory fullData = abi.encode(unifiedId, chainId, currentPrimary, newPrimary);
        string memory operationType = "UPDATE_PRIMARY_ADDRESS";

        requireSignature(operationType, fullData, unifiedId, currentPrimary, currentPrimarySignature);
        requireSignature(operationType, fullData, unifiedId, newPrimary, newPrimarySignature);

        unifiedIds[unifiedId].chains[chainId].primary = newPrimary;

        // Update resolver with new primary address mapping
        resolver.updateUnifiedIdPrimaryAddress(unifiedId, chainId, newPrimary);

        emit PrimaryAddressUpdated(unifiedId, chainId, newPrimary);
        nonces[unifiedId]++;
    }

    function addSecondaryAddress(
        string calldata unifiedId,
        uint256 chainId,
        address secondary,
        bytes memory data,
        bytes memory primarySignature,
        bytes memory secondarySignature
    ) external onlyRelayer whenNotPaused {
        require(unifiedIds[unifiedId].exists, "UnifiedID does not exist");
        require(unifiedIds[unifiedId].chains[chainId].exists, "Chain data does not exist");

        address primary = unifiedIds[unifiedId].chains[chainId].primary;

        // Prevent adding primary address as secondary
        require(primary != secondary, "Cannot add primary address as secondary");

        // Create comprehensive data for signature validation
        bytes memory fullData = abi.encode(unifiedId, chainId, primary, secondary);
        string memory operationType = "ADD_SECONDARY_ADDRESS";

        requireSignature(operationType, fullData, unifiedId, primary, primarySignature);
        requireSignature(operationType, fullData, unifiedId, secondary, secondarySignature);

        ChainData storage chainData = unifiedIds[unifiedId].chains[chainId];
        require(chainData.secondaries.length < maxSecondaryAddressesPerChain, "Maximum secondary addresses per chain reached");

        // Check for duplicate secondary addresses
        address[] storage secondaries = chainData.secondaries;
        for (uint i = 0; i < secondaries.length; ++i) {
            require(secondaries[i] != secondary, "Secondary address already exists");
        }

        chainData.secondaries.push(secondary);

        // Update resolver with secondary address mapping
        resolver.addUnifiedIdSecondaryAddress(unifiedId, chainId, secondary);

        emit SecondaryAddressAdded(unifiedId, chainId, secondary);
        nonces[unifiedId]++;
    }

    function removeSecondaryAddress(
        string calldata unifiedId,
        uint256 chainId,
        address secondary,
        bytes memory data,
        bytes memory signature
    ) external onlyRelayer whenNotPaused {
        require(unifiedIds[unifiedId].exists, "UnifiedID does not exist");
        require(unifiedIds[unifiedId].chains[chainId].exists, "Chain data does not exist");

        address primary = unifiedIds[unifiedId].chains[chainId].primary;

        // Create comprehensive data for signature validation
        bytes memory fullData = abi.encode(unifiedId, chainId, primary, secondary);
        string memory operationType = "REMOVE_SECONDARY_ADDRESS";

        requireSignature(operationType, fullData, unifiedId, primary, signature);

        ChainData storage chainData = unifiedIds[unifiedId].chains[chainId];

        // Fix unbounded loop vulnerability by adding bounds check
        require(chainData.secondaries.length <= maxSecondaryAddressesPerChain, "Too many secondary addresses");

        for (uint256 i = 0; i < chainData.secondaries.length; ++i) {
            if (chainData.secondaries[i] == secondary) {
                chainData.secondaries[i] = chainData.secondaries[chainData.secondaries.length - 1];
                chainData.secondaries.pop();

                // Update resolver to remove secondary address mapping
                resolver.removeUnifiedIdSecondaryAddress(unifiedId, chainId, secondary);

                emit SecondaryAddressRemoved(unifiedId, chainId, secondary);
                nonces[unifiedId]++;
                break;
            }
        }
    }

    function updateUnifiedId(
        string calldata oldUnifiedId,
        string calldata newUnifiedId,
        bytes memory data,
        bytes memory signature
    ) external onlyRelayer whenNotPaused {
        require(!isUnavailableUnifiedId[oldUnifiedId], "Old UnifiedID is unavailable");
        require(!isUnavailableUnifiedId[newUnifiedId], "New UnifiedID is unavailable");
        require(unifiedIds[oldUnifiedId].exists, "Old UnifiedID does not exist");
        require(!unifiedIds[newUnifiedId].exists, "New UnifiedID already exists");

        address masterAddress = unifiedIds[oldUnifiedId].masterAddress;

        // Create comprehensive data for signature validation
        bytes memory fullData = abi.encode(oldUnifiedId, newUnifiedId);
        string memory operationType = "UPDATE_UNIFIED_ID";

        requireSignature(operationType, fullData, oldUnifiedId, masterAddress, signature);

        _transferUnifiedIdData(oldUnifiedId, newUnifiedId);
        _cleanupOldUnifiedId(oldUnifiedId, newUnifiedId);
    }

    /**
     * @dev Internal function to transfer unified ID data to avoid stack too deep
     */
    function _transferUnifiedIdData(string memory oldUnifiedId, string memory newUnifiedId) internal {
        UnifiedID storage existing = unifiedIds[oldUnifiedId];
        uint256[] memory chainIds = existing.registeredChainIds;

        UnifiedID storage updated = unifiedIds[newUnifiedId];
        updated.masterAddress = existing.masterAddress;
        updated.exists = true;

        // Copy chain data properly (fix storage corruption bug)
        for (uint i = 0; i < chainIds.length; ++i) {
            uint256 cid = chainIds[i];
            ChainData storage existingChain = existing.chains[cid];
            ChainData storage newChain = updated.chains[cid];

            // Copy basic fields
            newChain.primary = existingChain.primary;
            newChain.exists = existingChain.exists;

            // Properly copy secondary addresses array (fix storage corruption)
            // Add bounds checking to prevent DoS
            uint256 maxSecondaryIterations = existingChain.secondaries.length > maxSecondaryAddressesPerChain
                ? maxSecondaryAddressesPerChain
                : existingChain.secondaries.length;

            for (uint j = 0; j < maxSecondaryIterations; ++j) {
                newChain.secondaries.push(existingChain.secondaries[j]);
            }

            updated.registeredChainIds.push(cid);

            _updateResolverForNewUnifiedId(newUnifiedId, cid, newChain);
        }
    }

    /**
     * @dev Internal function to update resolver mappings for new unified ID
     */
    function _updateResolverForNewUnifiedId(string memory newUnifiedId, uint256 chainId, ChainData storage chainData) internal {
        if (chainData.primary != address(0)) {
            resolver.setUnifiedIdPrimaryAddress(newUnifiedId, chainId, chainData.primary);

            // Add secondary addresses to resolver
            address[] storage secondaries = chainData.secondaries;

            // Prevent unbounded loop DoS by limiting iterations
            uint256 maxSecondaryIterations = secondaries.length > maxSecondaryAddressesPerChain ? maxSecondaryAddressesPerChain : secondaries.length;

            for (uint j = 0; j < maxSecondaryIterations; ++j) {
                resolver.addUnifiedIdSecondaryAddress(newUnifiedId, chainId, secondaries[j]);
            }
        }
    }

    /**
     * @dev Internal function to cleanup old unified ID data
     */
    function _cleanupOldUnifiedId(string memory oldUnifiedId, string memory newUnifiedId) internal {
        UnifiedID storage existing = unifiedIds[oldUnifiedId];
        uint256[] memory chainIds = existing.registeredChainIds;

        // Prevent unbounded loop DoS by limiting iterations
        uint256 maxIterations = chainIds.length > maxChainsPerUnifiedId ? maxChainsPerUnifiedId : chainIds.length;

        // Clean up resolver mappings for old unified ID
        for (uint i = 0; i < maxIterations; ++i) {
            uint256 cid = chainIds[i];
            resolver.clearUnifiedIdMappings(oldUnifiedId, cid);
            delete existing.chains[cid];
        }

        delete existing.registeredChainIds;
        existing.masterAddress = address(0);
        existing.exists = false;

        isUnavailableUnifiedId[oldUnifiedId] = true;

        emit UnifiedIdUpdated(newUnifiedId, oldUnifiedId);
        nonces[newUnifiedId] = nonces[oldUnifiedId] + 1;
        delete nonces[oldUnifiedId];
    }

    function updateMasterAddress(
        string calldata unifiedId,
        address newMasterAddress,
        bytes memory data,
        bytes memory signature
    ) external onlyRelayer whenNotPaused {
        require(unifiedIds[unifiedId].exists, "UnifiedID does not exist");

        address currentMasterAddress = unifiedIds[unifiedId].masterAddress;

        // Create comprehensive data for signature validation
        bytes memory fullData = abi.encode(unifiedId, currentMasterAddress, newMasterAddress);
        string memory operationType = "UPDATE_MASTER_ADDRESS";

        requireSignature(operationType, fullData, unifiedId, currentMasterAddress, signature);

        unifiedIds[unifiedId].masterAddress = newMasterAddress;

        emit MasterAddressUpdated(unifiedId, newMasterAddress);
        nonces[unifiedId]++;
    }

    /**
     * @notice Gets the master address for a unified ID
     * @dev Returns the address that has control over the unified ID across all chains
     * @param unifiedId The unified ID to query
     * @return The master address controlling the unified ID
     */
    function getMasterAddress(string calldata unifiedId) external view returns (address) {
        return unifiedIds[unifiedId].masterAddress;
    }

    /**
     * @notice Gets chain-specific data for a unified ID
     * @dev Returns both primary and all secondary addresses for the unified ID on the specified chain
     * @param unifiedId The unified ID to query
     * @param chainId The chain ID to get data for
     * @return primary The primary address on the specified chain
     * @return secondaries Array of secondary addresses on the specified chain
     */
    function getChainData(
        string calldata unifiedId,
        uint256 chainId
    ) external view returns (address primary, address[] memory secondaries) {
        ChainData storage chainData = unifiedIds[unifiedId].chains[chainId];
        return (chainData.primary, chainData.secondaries);
    }

    /**
     * @notice Gets the current nonce for a unified ID
     * @dev Returns the nonce used for signature verification to prevent replay attacks
     * @param unifiedId The unified ID to get nonce for
     * @return Current nonce value for the unified ID
     */
    function getNonce(string calldata unifiedId) external view returns (uint256) {
        return nonces[unifiedId];
    }

    // Check if a chain is registered for a unified ID
    function isChainRegistered(string calldata unifiedId, uint256 chainId) external view returns (bool) {
        uint256[] memory chainIds = unifiedIds[unifiedId].registeredChainIds;

        // Prevent unbounded loop DoS by limiting iterations
        uint256 maxIterations = chainIds.length > maxChainsPerUnifiedId ? maxChainsPerUnifiedId : chainIds.length;

        for (uint i = 0; i < maxIterations; ++i) {
            if (chainIds[i] == chainId) {
                return true;
            }
        }
        return false;
    }

    // Get all registered chain IDs for a unified ID
    function getRegisteredChainIds(string calldata unifiedId) external view returns (uint256[] memory) {
        return unifiedIds[unifiedId].registeredChainIds;
    }

    // === RESOLVER INTEGRATION FUNCTIONS ===

    /**
     * @notice Get unified ID from address via resolver
     * @param addr Address to lookup
     * @param chainId Chain ID where the address is registered
     * @return Unified ID associated with the address
     */
    function resolveAddressToUnifiedId(address addr, uint256 chainId) external view returns (string memory) {
        return resolver.getUnifiedIdFromAddress(addr, chainId);
    }

    /**
     * @notice Get primary address for unified ID on specific chain via resolver
     * @param unifiedId Unified ID to lookup
     * @param chainId Chain ID to query
     * @return Primary address on the specified chain
     */
    function resolvePrimaryAddress(string calldata unifiedId, uint256 chainId) external view returns (address) {
        return resolver.getPrimaryAddress(unifiedId, chainId);
    }

    /**
     * @notice Get all addresses for unified ID on specific chain via resolver
     * @param unifiedId Unified ID to lookup
     * @param chainId Chain ID to query
     * @return primary Primary address
     * @return secondaries Array of secondary addresses
     */
    function resolveAllAddresses(string calldata unifiedId, uint256 chainId)
    external view returns (address primary, address[] memory secondaries) {
        return resolver.getAddresses(unifiedId, chainId);
    }

    function requireSignature(
        string memory operationType,
        bytes memory fullData,
        string memory unifiedId,
        address expectedSigner,
        bytes memory signature
    ) internal view {
        // Create comprehensive message hash using consistent abi.encode (not encodePacked)
        bytes32 messageHash = keccak256(abi.encode(
            keccak256("UNIFIED_ID_OPERATION"),
            operationType,
            fullData,
            nonces[unifiedId],
            block.chainid,
            address(this)
        ));

        // Use consistent abi.encode for signature verification (not encodePacked)
        require(util.verifySignature(abi.encode(messageHash), expectedSigner, signature), "Invalid signature");
    }

    // === ADMIN FUNCTIONS ===

    /**
     * @notice Set maximum number of secondary addresses per chain
     * @param _maxSecondaryAddresses New maximum limit
     */
    function setMaxSecondaryAddressesPerChain(uint256 _maxSecondaryAddresses) external onlyOwner {
        uint256 oldMax = maxSecondaryAddressesPerChain;
        maxSecondaryAddressesPerChain = _maxSecondaryAddresses;
        emit MaxSecondaryAddressesPerChainUpdated(oldMax, _maxSecondaryAddresses);
    }

    /**
     * @notice Set maximum number of chains per unified ID
     * @param _maxChains New maximum limit
     */
    function setMaxChainsPerUnifiedId(uint256 _maxChains) external onlyOwner {
        require(_maxChains != 0, "Max chains must be greater than 0");
        uint256 oldMax = maxChainsPerUnifiedId;
        maxChainsPerUnifiedId = _maxChains;
        emit MaxChainsPerUnifiedIdUpdated(oldMax, _maxChains);
    }

    /**
     * @notice Toggle emergency mode
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
     * @notice Emergency function to mark unified ID as unavailable
     * @param _unifiedId Unified ID to mark as unavailable
     */
    function emergencyMarkUnavailable(string calldata _unifiedId) external onlyAdmin {
        isUnavailableUnifiedId[_unifiedId] = true;
        emit EmergencyUnifiedIdMarked(_unifiedId, false, msg.sender);
    }

    /**
     * @notice Emergency function to mark unified ID as available
     * @param _unifiedId Unified ID to mark as available
     */
    function emergencyMarkAvailable(string calldata _unifiedId) external onlyAdmin {
        isUnavailableUnifiedId[_unifiedId] = false;
        emit EmergencyUnifiedIdMarked(_unifiedId, true, msg.sender);
    }

    /**
     * @notice Emergency function to clean up chain data
     * @param _unifiedId Unified ID to clean up
     * @param _chainId Chain ID to remove
     */
    function emergencyCleanupChainData(string calldata _unifiedId, uint256 _chainId) external onlyAdmin {
        require(unifiedIds[_unifiedId].exists, "UnifiedID does not exist");
        require(unifiedIds[_unifiedId].chains[_chainId].exists, "Chain data does not exist");

        delete unifiedIds[_unifiedId].chains[_chainId];

        // Remove from registeredChainIds array
        uint256[] storage chainIds = unifiedIds[_unifiedId].registeredChainIds;

        // Prevent unbounded loop DoS by limiting iterations
        uint256 maxIterations = chainIds.length > maxChainsPerUnifiedId ? maxChainsPerUnifiedId : chainIds.length;

        for (uint i = 0; i < maxIterations; ++i) {
            if (chainIds[i] == _chainId) {
                chainIds[i] = chainIds[chainIds.length - 1];
                chainIds.pop();
                break;
            }
        }

        emit EmergencyChainDataCleared(_unifiedId, _chainId, msg.sender);
    }

    /**
     * @notice Get contract configuration
     * @return _maxSecondaryAddressesPerChain Maximum secondary addresses per chain
     * @return _maxChainsPerUnifiedId Maximum chains per unified ID
     * @return _emergencyMode Emergency mode status
     */
    function getConfiguration() external view returns (
        uint256 _maxSecondaryAddressesPerChain,
        uint256 _maxChainsPerUnifiedId,
        bool _emergencyMode
    ) {
        return (
            maxSecondaryAddressesPerChain,
            maxChainsPerUnifiedId,
            emergencyMode
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
    function withdrawEth(address payable to, uint256 amount) external onlyOwner {
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
    function withdrawERC20(address token, address to, uint256 amount) external onlyOwner {
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