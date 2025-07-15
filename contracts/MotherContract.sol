// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import "./RegistrarStorageUtil.sol";
import "./IUnifiedIdResolver.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title RegistrarStorageMother
 * @author kunalmkv
 * @notice Core contract for managing unified IDs across multiple blockchains
 * @dev Optimized version with enum errors and gas optimizations
 */
contract RegistrarStorageMother is Initializable, UUPSUpgradeable, PausableUpgradeable, AccessControlUpgradeable,ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    // === ERROR ENUMS FOR GAS OPTIMIZATION ===
    error E1(); // "Ownable: caller is not the owner"
    error E2(); // "Ownable: new owner is the zero address"
    error E3(); // "Ownable2Step: caller is not the new owner"
    error E4(); // "UnifiedID does not exist"
    error E5(); // "Contract is Paused"
    error E6(); // "UnifiedID already exists"
    error E7(); // "UnifiedID not available"
    error E8(); // "Caller not a registrar"
    error E9(); // "Caller not authorized relayer"
    error E10(); // "Caller not admin or owner"
    error E11(); // "Contract in emergency mode"
    error E12(); // "Util implementation: zero address"
    error E13(); // "Resolver: zero address"
    error E14(); // "Chain data does not exist"
    error E15(); // "Chain data already exists"
    error E16(); // "Maximum chains per unified ID reached"
    error E17(); // "Cannot add primary address as secondary"
    error E18(); // "Secondary address already exists"
    error E19(); // "Maximum secondary addresses per chain reached"
    error E20(); // "Old UnifiedID does not exist"
    error E21(); // "New UnifiedID already exists"
    error E22(); // "Too many secondary addresses"
    error E23(); // "Invalid signature"
    error E24(); // "Max chains must be greater than 0"
    error E25(); // "User cannot be zero address"
    error E26(); // "Cannot withdraw to zero address"
    error E27(); // "Insufficient balance"
    error E28(); // "ETH transfer failed"
    error E29(); // "Invalid token address"
    error E30(); // "ERC20 transfer failed"
    error E31(); // "Cannot update to same UnifiedId"
    error E32(); // "Cannot set same primary address"
    error E33(); // "Cannot set zero address as primary"

    // ==================== ROLE DEFINITIONS ====================

    /// @notice Role for authorized relayers who can execute operations
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    /// @notice Role for admin users with elevated privileges
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role for emergency operations
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    /// @notice Role for upgrading the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // === STORAGE VARIABLES ===
    RegistrarStorageUtil public util;
    IUnifiedIdResolver public resolver;

    // Ownable2Step implementation
    address private _owner;
    address private _pendingOwner;

    // Core storage structures
    struct ChainData {
        address primary;
        address[] secondaries;
        bool exists;
    }

    struct UnifiedID {
        address masterAddress;
        mapping(uint256 => ChainData) chains;
        uint256[] registeredChainIds;
        bool exists;
    }

    mapping(string => UnifiedID) private unifiedIds;
    mapping(string => bool) public isUnavailableUnifiedId;
    mapping(string => uint256) public nonces;

    // Packed configuration struct for gas optimization
    struct PackedConfig {
        uint128 maxSecondaryAddressesPerChain;
        uint128 maxChainsPerUnifiedId;
        bool emergencyMode;
    }

    PackedConfig public config;

    // === INDEXER-OPTIMIZED EVENTS ===
    
    // === CORE OPERATION EVENTS ===
    
    /**
     * @notice Emitted when a UnifiedID is successfully registered
     * @dev Optimized for Graph indexer with indexed parameters for efficient filtering
     * @param unifiedId The UnifiedID that was registered (indexed)
     * @param masterAddress The master address for the UnifiedID (indexed)
     * @param chainId The chain ID where registration occurred (indexed)
     * @param primary The primary address for this chain
     * @param timestamp Block timestamp
     */
    event UnifiedIdRegistered(
        string indexed unifiedId,
        address indexed masterAddress,
        uint256 indexed chainId,
        address primary,
        uint256 timestamp
    );

    /**
     * @notice Emitted when a UnifiedID is successfully updated
     * @dev Optimized for Graph indexer
     * @param oldUnifiedId The old UnifiedID (indexed)
     * @param newUnifiedId The new UnifiedID (indexed)
     * @param masterAddress The master address (indexed)
     * @param timestamp Block timestamp
     */
    event UnifiedIdUpdated(
        string indexed oldUnifiedId,
        string indexed newUnifiedId,
        address indexed masterAddress,
        uint256 timestamp
    );

    /**
     * @notice Emitted when master address is updated
     * @dev Optimized for Graph indexer
     * @param unifiedId The UnifiedID (indexed)
     * @param oldMasterAddress The old master address (indexed)
     * @param newMasterAddress The new master address (indexed)
     * @param timestamp Block timestamp
     */
    event MasterAddressUpdated(
        string indexed unifiedId,
        address indexed oldMasterAddress,
        address indexed newMasterAddress,
        uint256 timestamp
    );

    /**
     * @notice Emitted when primary address is updated for a specific chain
     * @dev Optimized for Graph indexer
     * @param unifiedId The UnifiedID (indexed)
     * @param chainId The chain ID (indexed)
     * @param oldPrimary The old primary address (indexed)
     * @param newPrimary The new primary address
     * @param timestamp Block timestamp
     */
    event PrimaryAddressUpdated(
        string indexed unifiedId,
        uint256 indexed chainId,
        address indexed oldPrimary,
        address newPrimary,
        uint256 timestamp
    );

    /**
     * @notice Emitted when a secondary address is added
     * @dev Optimized for Graph indexer
     * @param unifiedId The UnifiedID (indexed)
     * @param chainId The chain ID (indexed)
     * @param secondaryAddress The secondary address added (indexed)
     * @param timestamp Block timestamp
     */
    event SecondaryAddressAdded(
        string indexed unifiedId,
        uint256 indexed chainId,
        address indexed secondaryAddress,
        uint256 timestamp
    );

    /**
     * @notice Emitted when a secondary address is removed
     * @dev Optimized for Graph indexer
     * @param unifiedId The UnifiedID (indexed)
     * @param chainId The chain ID (indexed)
     * @param secondaryAddress The secondary address removed (indexed)
     * @param timestamp Block timestamp
     */
    event SecondaryAddressRemoved(
        string indexed unifiedId,
        uint256 indexed chainId,
        address indexed secondaryAddress,
        uint256 timestamp
    );

    // === ADMIN & CONFIGURATION EVENTS ===
    
    /**
     * @notice Emitted when ownership transfer is initiated
     * @param previousOwner Current owner who initiated the transfer (indexed)
     * @param newOwner Address that will become the new owner (indexed)
     * @param timestamp Block timestamp
     */
    event OwnershipTransferStarted(
        address indexed previousOwner,
        address indexed newOwner,
        uint256 timestamp
    );

    /**
     * @notice Emitted when ownership transfer is completed
     * @param previousOwner Previous owner address (indexed)
     * @param newOwner New owner address (indexed)
     * @param timestamp Block timestamp
     */
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner,
        uint256 timestamp
    );

    /**
     * @notice Emitted when maximum secondary addresses per chain is updated
     * @param oldMax Previous maximum value
     * @param newMax New maximum value
     * @param updatedBy Address that made the update (indexed)
     * @param timestamp Block timestamp
     */
    event MaxSecondaryAddressesPerChainUpdated(
        uint256 oldMax,
        uint256 newMax,
        address indexed updatedBy,
        uint256 timestamp
    );

    /**
     * @notice Emitted when maximum chains per UnifiedID is updated
     * @param oldMax Previous maximum value
     * @param newMax New maximum value
     * @param updatedBy Address that made the update (indexed)
     * @param timestamp Block timestamp
     */
    event MaxChainsPerUnifiedIdUpdated(
        uint256 oldMax,
        uint256 newMax,
        address indexed updatedBy,
        uint256 timestamp
    );

    /**
     * @notice Emitted when emergency mode is toggled
     * @param enabled Whether emergency mode is enabled
     * @param updatedBy Address that made the change (indexed)
     * @param timestamp Block timestamp
     */
    event EmergencyModeToggled(
        bool enabled,
        address indexed updatedBy,
        uint256 timestamp
    );

    /**
     * @notice Emitted when resolver contract is updated
     * @param oldResolver Previous resolver address (indexed)
     * @param newResolver New resolver address (indexed)
     * @param updatedBy Address that made the update (indexed)
     * @param timestamp Block timestamp
     */
    event ResolverUpdated(
        address indexed oldResolver,
        address indexed newResolver,
        address indexed updatedBy,
        uint256 timestamp
    );

    /**
     * @notice Emitted when contract is paused
     * @param pausedBy Address that paused the contract (indexed)
     * @param timestamp Block timestamp
     */
    event ContractPaused(
        address indexed pausedBy,
        uint256 timestamp
    );

    /**
     * @notice Emitted when contract is unpaused
     * @param unpausedBy Address that unpaused the contract (indexed)
     * @param timestamp Block timestamp
     */
    event ContractUnpaused(
        address indexed unpausedBy,
        uint256 timestamp
    );

    /**
     * @notice Emitted when relayer authorization is updated
     * @param relayer The relayer address (indexed)
     * @param authorized Whether the relayer is authorized
     * @param updatedBy Address that made the change (indexed)
     * @param timestamp Block timestamp
     */
    event RelayerAuthorizationUpdated(
        address indexed relayer,
        bool authorized,
        address indexed updatedBy,
        uint256 timestamp
    );

    /**
     * @notice Emitted when contract upgrade is authorized
     * @param newImplementation New implementation address (indexed)
     * @param authorizedBy Address that authorized the upgrade (indexed)
     * @param timestamp Block timestamp
     */
    event UpgradeAuthorized(
        address indexed newImplementation,
        address indexed authorizedBy,
        uint256 timestamp
    );

    // === EMERGENCY EVENTS ===
    
    /**
     * @notice Emitted when a UnifiedID is marked as unavailable/available in emergency
     * @param unifiedId The UnifiedID (indexed)
     * @param available Whether the UnifiedID is available
     * @param updatedBy Address that made the change (indexed)
     * @param timestamp Block timestamp
     */
    event EmergencyUnifiedIdMarked(
        string indexed unifiedId,
        bool available,
        address indexed updatedBy,
        uint256 timestamp
    );

    /**
     * @notice Emitted when chain data is cleared in emergency
     * @param unifiedId The UnifiedID (indexed)
     * @param chainId The chain ID (indexed)
     * @param clearedBy Address that cleared the data (indexed)
     * @param timestamp Block timestamp
     */
    event EmergencyChainDataCleared(
        string indexed unifiedId,
        uint256 indexed chainId,
        address indexed clearedBy,
        uint256 timestamp
    );

    // === WITHDRAWAL EVENTS ===
    
    /**
     * @notice Emitted when ETH is withdrawn from the contract
     * @param to Recipient address (indexed)
     * @param amount Amount withdrawn
     * @param withdrawnBy Address that initiated the withdrawal (indexed)
     * @param timestamp Block timestamp
     */
    event EthWithdrawn(
        address indexed to,
        uint256 amount,
        address indexed withdrawnBy,
        uint256 timestamp
    );

    /**
     * @notice Emitted when ERC20 tokens are withdrawn from the contract
     * @param token Token contract address (indexed)
     * @param to Recipient address (indexed)
     * @param amount Amount withdrawn
     * @param withdrawnBy Address that initiated the withdrawal (indexed)
     * @param timestamp Block timestamp
     */
    event ERC20Withdrawn(
        address indexed token,
        address indexed to,
        uint256 amount,
        address indexed withdrawnBy,
        uint256 timestamp
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // === MODIFIERS ===
    modifier onlyOwner() {
        if (owner() != msg.sender) revert E1();
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender) || msg.sender == owner(), "AccessControl: caller is not admin");
        _;
    }

    modifier notInEmergencyMode() {
        if (config.emergencyMode) revert E11();
        _;
    }

    modifier onlyRelayer() {
        require(hasRole(RELAYER_ROLE, msg.sender), "AccessControl: caller is not relayer");
        _;
    }

    // === SIMPLE SIGNATURE VERIFICATION MODIFIER ===
    modifier verifySignature(bytes memory data, address expectedSigner, bytes memory signature) {
        (string memory unifiedId, ) = abi.decode(data, (string, address));
        uint256 nonce = nonces[unifiedId];
        bytes memory dataWithNonce = abi.encodePacked(data, nonce);
        require(util.verifySignature(dataWithNonce, expectedSigner, signature), "Invalid signature");
        _;
    }

    // === OWNABLE2STEP IMPLEMENTATION ===
    function owner() public view virtual returns (address) {
        return _owner;
    }

    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert E2();
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner, block.timestamp);
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
        emit OwnershipTransferred(oldOwner, newOwner, block.timestamp);
    }

    // === INITIALIZATION ===
    function initialize(address _util, address _resolver) public initializer {
        if (_util == address(0)) revert E12();
        if (_resolver == address(0)) revert E13();

        __UUPSUpgradeable_init();
        __Pausable_init();
        __AccessControl_init();

        // Set util first so we can use its isContract function for validation
        util = RegistrarStorageUtil(_util);
        
        // Validate contract addresses using util.isContract
        require(util.isContract(_util), "Util address is not a contract");
        require(util.isContract(_resolver), "Resolver address is not a contract");

        // Initialize ownership
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender, block.timestamp);

        resolver = IUnifiedIdResolver(_resolver);

        // Initialize packed config
        config = PackedConfig({
            maxSecondaryAddressesPerChain: 10,
            maxChainsPerUnifiedId: 50,
            emergencyMode: false
        });

        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    // === CORE FUNCTIONS ===
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
        emit ContractPaused(msg.sender, block.timestamp);
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
        emit ContractUnpaused(msg.sender, block.timestamp);
    }

    function setResolver(address _resolver) external onlyRole(ADMIN_ROLE) {
        if (_resolver == address(0)) revert E13();
        require(util.isContract(_resolver), "Resolver address is not a contract");
        
        address oldResolver = address(resolver);
        resolver = IUnifiedIdResolver(_resolver);
        emit ResolverUpdated(oldResolver, _resolver, msg.sender, block.timestamp);
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        require(hasRole(UPGRADER_ROLE, msg.sender) || msg.sender == owner(), "AccessControl: caller is not upgrader");
        emit UpgradeAuthorized(newImplementation, msg.sender, block.timestamp);
    }

    function registerUnifiedId(
        string calldata unifiedId,
        uint256 chainId,
        address primary,
        bytes calldata masterSignature,
        bytes calldata primarySignature
    ) external onlyRelayer whenNotPaused notInEmergencyMode {
        if (isUnavailableUnifiedId[unifiedId]) revert E7();

        UnifiedID storage uid = unifiedIds[unifiedId];
        ChainData storage chainData = uid.chains[chainId];

        if (chainData.exists) revert E15();
        if (uid.registeredChainIds.length >= config.maxChainsPerUnifiedId) revert E16();

        // Verify primary signature using simple verification
        bytes memory primaryData = abi.encode(unifiedId, primary);
        if (!util.verifySignature(abi.encodePacked(primaryData, nonces[unifiedId]), primary, primarySignature)) revert E23();

        // Update nonce
        nonces[unifiedId]++;

        if (!uid.exists) {
            // New UnifiedID
            uid.masterAddress = primary;
            uid.exists = true;
        } else {
            // Existing UnifiedID - verify master signature
            if (masterSignature.length > 0) {
                if (!util.verifySignature(abi.encodePacked(primaryData, nonces[unifiedId] - 1), uid.masterAddress, masterSignature)) revert E23();
            }
        }

        chainData.primary = primary;
        chainData.exists = true;
        uid.registeredChainIds.push(chainId);

        // Update resolver
        resolver.setUnifiedIdPrimaryAddress(unifiedId, chainId, primary);

        emit UnifiedIdRegistered(unifiedId, uid.masterAddress, chainId, primary, block.timestamp);
    }

    function updatePrimaryAddress(
        string calldata unifiedId,
        uint256 chainId,
        address newPrimary,
        bytes calldata currentSignature,
        bytes calldata newSignature
    ) external onlyRelayer whenNotPaused {
        if (!unifiedIds[unifiedId].exists) revert E4();
        if (!unifiedIds[unifiedId].chains[chainId].exists) revert E14();

        address currentPrimary = unifiedIds[unifiedId].chains[chainId].primary;

        // EDGE CASE PROTECTION: Prevent setting the same primary address
        if (currentPrimary == newPrimary) revert E32();

        // EDGE CASE PROTECTION: Prevent setting zero address as primary
        if (newPrimary == address(0)) revert E33();

        // Verify both signatures using simple verification
        bytes memory data = abi.encode(unifiedId, newPrimary);
        uint256 currentNonce = nonces[unifiedId];
        
        if (!util.verifySignature(abi.encodePacked(data, currentNonce), currentPrimary, currentSignature)) revert E23();
        if (!util.verifySignature(abi.encodePacked(data, currentNonce), newPrimary, newSignature)) revert E23();

        // Update nonce
        nonces[unifiedId]++;

        unifiedIds[unifiedId].chains[chainId].primary = newPrimary;

        // Update resolver
        resolver.updateUnifiedIdPrimaryAddress(unifiedId, chainId, newPrimary);

        emit PrimaryAddressUpdated(unifiedId, chainId, currentPrimary, newPrimary, block.timestamp);
    }

    function addSecondaryAddress(
        string calldata unifiedId,
        uint256 chainId,
        address secondary,
        bytes calldata primarySignature,
        bytes calldata secondarySignature
    ) external onlyRelayer whenNotPaused {
        if (!unifiedIds[unifiedId].exists) revert E4();
        if (!unifiedIds[unifiedId].chains[chainId].exists) revert E14();

        address primary = unifiedIds[unifiedId].chains[chainId].primary;

        if (primary == secondary) revert E17();

        ChainData storage chainData = unifiedIds[unifiedId].chains[chainId];
        if (chainData.secondaries.length >= config.maxSecondaryAddressesPerChain) revert E19();

        // Check for duplicates
        for (uint256 i = 0; i < chainData.secondaries.length; ++i) {
            if (chainData.secondaries[i] == secondary) revert E18();
        }

        // Verify signatures using simple verification
        bytes memory data = abi.encode(unifiedId, secondary);
        uint256 currentNonce = nonces[unifiedId];
        
        if (!util.verifySignature(abi.encodePacked(data, currentNonce), primary, primarySignature)) revert E23();
        if (!util.verifySignature(abi.encodePacked(data, currentNonce), secondary, secondarySignature)) revert E23();

        // Update nonce
        nonces[unifiedId]++;

        chainData.secondaries.push(secondary);

        // Update resolver
        resolver.addUnifiedIdSecondaryAddress(unifiedId, chainId, secondary);

        emit SecondaryAddressAdded(unifiedId, chainId, secondary, block.timestamp);
    }

    function removeSecondaryAddress(
        string calldata unifiedId,
        uint256 chainId,
        address secondary,
        bytes calldata signature
    ) external onlyRelayer whenNotPaused {
        if (!unifiedIds[unifiedId].exists) revert E4();
        if (!unifiedIds[unifiedId].chains[chainId].exists) revert E14();

        address primary = unifiedIds[unifiedId].chains[chainId].primary;

        // Verify signature using simple verification
        bytes memory data = abi.encode(unifiedId, secondary);
        uint256 currentNonce = nonces[unifiedId];
        
        if (!util.verifySignature(abi.encodePacked(data, currentNonce), primary, signature)) revert E23();

        // Update nonce
        nonces[unifiedId]++;

        ChainData storage chainData = unifiedIds[unifiedId].chains[chainId];

        if (chainData.secondaries.length > config.maxSecondaryAddressesPerChain) revert E22();

        for (uint256 i = 0; i < chainData.secondaries.length; ++i) {
            if (chainData.secondaries[i] == secondary) {
                chainData.secondaries[i] = chainData.secondaries[chainData.secondaries.length - 1];
                chainData.secondaries.pop();

                // Update resolver
                resolver.removeUnifiedIdSecondaryAddress(unifiedId, chainId, secondary);

                emit SecondaryAddressRemoved(unifiedId, chainId, secondary, block.timestamp);
                break;
            }
        }
    }

    function updateUnifiedId(
        string calldata oldUnifiedId,
        string calldata newUnifiedId,
        bytes calldata signature
    ) external onlyRelayer whenNotPaused {
        if (isUnavailableUnifiedId[oldUnifiedId]) revert E7();
        if (isUnavailableUnifiedId[newUnifiedId]) revert E7();
        if (!unifiedIds[oldUnifiedId].exists) revert E20();
        if (unifiedIds[newUnifiedId].exists) revert E21();

        // EDGE CASE PROTECTION: Prevent updating to the same UnifiedId
        if (keccak256(bytes(oldUnifiedId)) == keccak256(bytes(newUnifiedId))) revert E31();

        address masterAddress = unifiedIds[oldUnifiedId].masterAddress;

        // Verify signature using simple verification
        bytes memory data = abi.encode(oldUnifiedId, newUnifiedId);
        uint256 currentNonce = nonces[oldUnifiedId];
        
        if (!util.verifySignature(abi.encodePacked(data, currentNonce), masterAddress, signature)) revert E23();

        // Update nonce
        nonces[newUnifiedId] = nonces[oldUnifiedId] + 1;
        delete nonces[oldUnifiedId];

        _transferUnifiedIdData(oldUnifiedId, newUnifiedId);
        _cleanupOldUnifiedId(oldUnifiedId, newUnifiedId);
    }

    function _transferUnifiedIdData(string memory oldUnifiedId, string memory newUnifiedId) internal {
        UnifiedID storage existing = unifiedIds[oldUnifiedId];
        uint256[] memory chainIds = existing.registeredChainIds;

        UnifiedID storage updated = unifiedIds[newUnifiedId];
        updated.masterAddress = existing.masterAddress;
        updated.exists = true;

        for (uint256 i = 0; i < chainIds.length; ++i) {
            uint256 cid = chainIds[i];
            ChainData storage existingChain = existing.chains[cid];
            ChainData storage newChain = updated.chains[cid];

            newChain.primary = existingChain.primary;
            newChain.exists = existingChain.exists;

            uint256 maxSecondaryIterations = existingChain.secondaries.length > config.maxSecondaryAddressesPerChain ?
                uint256(config.maxSecondaryAddressesPerChain) : existingChain.secondaries.length;

            for (uint256 j = 0; j < maxSecondaryIterations;) {
                newChain.secondaries.push(existingChain.secondaries[j]);
                unchecked { ++j; }
            }

            updated.registeredChainIds.push(cid);

            _updateResolverForNewUnifiedId(newUnifiedId, cid, newChain);

            unchecked { ++i; }
        }
    }

    function _updateResolverForNewUnifiedId(string memory newUnifiedId, uint256 chainId, ChainData storage chainData) internal {
        if (chainData.primary != address(0)) {
            resolver.setUnifiedIdPrimaryAddress(newUnifiedId, chainId, chainData.primary);

            address[] storage secondaries = chainData.secondaries;

            uint256 maxSecondaryIterations = secondaries.length > config.maxSecondaryAddressesPerChain ?
                uint256(config.maxSecondaryAddressesPerChain) : secondaries.length;

            for (uint256 j; j < maxSecondaryIterations;) {
                resolver.addUnifiedIdSecondaryAddress(newUnifiedId, chainId, secondaries[j]);
                unchecked { ++j; }
            }
        }
    }

    function _cleanupOldUnifiedId(string memory oldUnifiedId, string memory newUnifiedId) internal {
        uint256[] memory chainIds = unifiedIds[oldUnifiedId].registeredChainIds;

        uint256 maxIterations = chainIds.length > config.maxChainsPerUnifiedId ?
            uint256(config.maxChainsPerUnifiedId) : chainIds.length;

        for (uint256 i; i < maxIterations;) {
            uint256 cid = chainIds[i];
            resolver.clearUnifiedIdMappings(oldUnifiedId, cid);
            delete unifiedIds[oldUnifiedId].chains[cid];
            unchecked { ++i; }
        }

        delete unifiedIds[oldUnifiedId];
        emit UnifiedIdUpdated(newUnifiedId, oldUnifiedId, unifiedIds[newUnifiedId].masterAddress, block.timestamp);
    }

    function updateMasterAddress(
        string calldata unifiedId,
        address newMasterAddress,
        bytes calldata signature
    ) external onlyRelayer whenNotPaused {
        if (!unifiedIds[unifiedId].exists) revert E4();

        address currentMasterAddress = unifiedIds[unifiedId].masterAddress;

        // Verify signature using simple verification
        bytes memory data = abi.encode(unifiedId, newMasterAddress);
        uint256 currentNonce = nonces[unifiedId];
        
        if (!util.verifySignature(abi.encodePacked(data, currentNonce), currentMasterAddress, signature)) revert E23();

        // Update nonce
        nonces[unifiedId]++;

        unifiedIds[unifiedId].masterAddress = newMasterAddress;

        emit MasterAddressUpdated(unifiedId, currentMasterAddress, newMasterAddress, block.timestamp);
    }

    // === VIEW FUNCTIONS ===
    function getMasterAddress(string calldata unifiedId) external view returns (address) {
        return unifiedIds[unifiedId].masterAddress;
    }

    function getChainData(
        string calldata unifiedId,
        uint256 chainId
    ) external view returns (address primary, address[] memory secondaries) {
        ChainData storage chainData = unifiedIds[unifiedId].chains[chainId];
        return (chainData.primary, chainData.secondaries);
    }

    function getNonce(string calldata unifiedId) external view returns (uint256) {
        return nonces[unifiedId];
    }

    function isChainRegistered(string calldata unifiedId, uint256 chainId) external view returns (bool) {
        uint256[] memory chainIds = unifiedIds[unifiedId].registeredChainIds;

        uint256 maxIterations = chainIds.length > config.maxChainsPerUnifiedId ?
            uint256(config.maxChainsPerUnifiedId) : chainIds.length;

        for (uint256 i; i < maxIterations;) {
            if (chainIds[i] == chainId) {
                return true;
            }
            unchecked { ++i; }
        }
        return false;
    }

    function getRegisteredChainIds(string calldata unifiedId) external view returns (uint256[] memory) {
        return unifiedIds[unifiedId].registeredChainIds;
    }

    function resolveAddressToUnifiedId(address addr, uint256 chainId) external view returns (string memory) {
        return resolver.getUnifiedIdFromAddress(addr, chainId);
    }

    function resolvePrimaryAddress(string calldata unifiedId, uint256 chainId) external view returns (address) {
        return resolver.getPrimaryAddress(unifiedId, chainId);
    }

    function resolveAllAddresses(string calldata unifiedId, uint256 chainId)
    external view returns (address primary, address[] memory secondaries) {
        return resolver.getAddresses(unifiedId, chainId);
    }

    // ==================== COMBINED ADDRESS FUNCTIONS ====================

    /**
     * @notice Gets all addresses (primary + secondary) for a UnifiedId in a single array on specific chain
     * @dev Returns all addresses associated with the UnifiedId on the specified chain in one array
     * @param unifiedId The UnifiedId to get all addresses for
     * @param chainId The chain ID to query
     * @return allAddresses Array containing primary address followed by all secondary addresses
     * @custom:gas-optimization Efficient single-call solution instead of multiple calls + concatenation
     * @custom:use-cases
     * - DApp integration for displaying all addresses
     * - Wallet interfaces showing complete address list
     * - Permission checking across all addresses
     * - Simplified iteration over all addresses
     * @custom:array-structure [primary, secondary1, secondary2, ...]
     */
    function getAllAddresses(string calldata unifiedId, uint256 chainId) external view returns (address[] memory allAddresses) {
        return resolver.getAllAddresses(unifiedId, chainId);
    }

    /**
     * @notice Gets the total count of addresses (primary + secondary) for a UnifiedId on specific chain
     * @dev Returns the total number of addresses associated with the UnifiedId on the specified chain
     * @param unifiedId The UnifiedId to count addresses for
     * @param chainId The chain ID to query
     * @return count Total number of addresses (1 primary + N secondary addresses)
     * @custom:gas-optimization Lightweight function for getting address count without array allocation
     * @custom:use-cases
     * - Pre-allocating arrays for address operations
     * - Checking if UnifiedId has multiple addresses
     * - Gas estimation for batch operations
     */
    function getAddressCount(string calldata unifiedId, uint256 chainId) external view returns (uint256 count) {
        return resolver.getAddressCount(unifiedId, chainId);
    }

    /**
     * @notice Checks if a UnifiedId has multiple addresses on a specific chain
     * @dev Convenience function to check if UnifiedId has secondary addresses on the specified chain
     * @param unifiedId The UnifiedId to check
     * @param chainId The chain ID to query
     * @return hasMultiple True if UnifiedId has secondary addresses in addition to primary
     * @custom:gas-optimization Uses address count instead of fetching full arrays
     */
    function hasMultipleAddresses(string calldata unifiedId, uint256 chainId) external view returns (bool hasMultiple) {
        return resolver.getAddressCount(unifiedId, chainId) > 1;
    }

    /**
     * @notice Gets all addresses across all registered chains for a UnifiedId
     * @dev Returns addresses from all chains where the UnifiedId is registered
     * @param unifiedId The UnifiedId to get addresses for
     * @return chainIds Array of chain IDs where UnifiedId is registered
     * @return allAddressesPerChain Array of address arrays, one per chain
     * @custom:gas-optimization Batches multi-chain queries in single call
     * @custom:multi-chain Comprehensive cross-chain address retrieval
     * @custom:use-cases
     * - Complete UnifiedId address overview
     * - Cross-chain DApp integration
     * - Multi-chain wallet displays
     */
    function getAllAddressesAcrossChains(string calldata unifiedId) external view returns (
        uint256[] memory chainIds,
        address[][] memory allAddressesPerChain
    ) {
        chainIds = unifiedIds[unifiedId].registeredChainIds;
        allAddressesPerChain = new address[][](chainIds.length);

        for (uint256 i = 0; i < chainIds.length; ++i) {
            allAddressesPerChain[i] = resolver.getAllAddresses(unifiedId, chainIds[i]);
        }

        return (chainIds, allAddressesPerChain);
    }

    // === ADMIN FUNCTIONS ===
    function setMaxSecondaryAddressesPerChain(uint256 _maxSecondaryAddresses) external onlyRole(ADMIN_ROLE) {
        uint256 oldMax = config.maxSecondaryAddressesPerChain;
        config.maxSecondaryAddressesPerChain = uint128(_maxSecondaryAddresses);
        emit MaxSecondaryAddressesPerChainUpdated(oldMax, _maxSecondaryAddresses, msg.sender, block.timestamp);
    }

    function setMaxChainsPerUnifiedId(uint256 _maxChains) external onlyRole(ADMIN_ROLE) {
        if (_maxChains == 0) revert E24();
        uint256 oldMax = config.maxChainsPerUnifiedId;
        config.maxChainsPerUnifiedId = uint128(_maxChains);
        emit MaxChainsPerUnifiedIdUpdated(oldMax, _maxChains, msg.sender, block.timestamp);
    }

    function setEmergencyMode(bool _enabled) external onlyRole(EMERGENCY_ROLE) {
        config.emergencyMode = _enabled;
        emit EmergencyModeToggled(_enabled, msg.sender, block.timestamp);
    }

    function emergencyMarkUnavailable(string calldata _unifiedId) external onlyRole(EMERGENCY_ROLE) {
        isUnavailableUnifiedId[_unifiedId] = true;
        emit EmergencyUnifiedIdMarked(_unifiedId, false, msg.sender, block.timestamp);
    }

    function emergencyMarkAvailable(string calldata _unifiedId) external onlyRole(EMERGENCY_ROLE) {
        isUnavailableUnifiedId[_unifiedId] = false;
        emit EmergencyUnifiedIdMarked(_unifiedId, true, msg.sender, block.timestamp);
    }

    function emergencyCleanupChainData(string calldata _unifiedId, uint256 _chainId) external onlyRole(EMERGENCY_ROLE) {
        if (!unifiedIds[_unifiedId].exists) revert E4();
        if (!unifiedIds[_unifiedId].chains[_chainId].exists) revert E14();

        delete unifiedIds[_unifiedId].chains[_chainId];

        uint256[] storage chainIds = unifiedIds[_unifiedId].registeredChainIds;

        uint256 maxIterations = chainIds.length > config.maxChainsPerUnifiedId ?
            uint256(config.maxChainsPerUnifiedId) : chainIds.length;

        for (uint256 i; i < maxIterations;) {
            if (chainIds[i] == _chainId) {
                chainIds[i] = chainIds[chainIds.length - 1];
                chainIds.pop();
                break;
            }
            unchecked { ++i; }
        }

        emit EmergencyChainDataCleared(_unifiedId, _chainId, msg.sender, block.timestamp);
    }

    function getConfiguration() external view returns (
        uint256 _maxSecondaryAddressesPerChain,
        uint256 _maxChainsPerUnifiedId,
        bool _emergencyMode
    ) {
        return (
            config.maxSecondaryAddressesPerChain,
            config.maxChainsPerUnifiedId,
            config.emergencyMode
        );
    }

    receive() external payable {}
    fallback() external payable {}

    /**
  * @notice Withdraws ETH from the contract to a specified address
 * @param to The address to send ETH to
 * @param amount The amount of ETH to withdraw in wei
 */
    function withdrawEth(address payable to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= address(this).balance, "Insufficient contract balance");

        // Emit event before external call (CEI pattern)
        emit EthWithdrawn(to, amount, msg.sender, block.timestamp);

        // Transfer with limited gas to prevent griefing
        (bool success, ) = to.call{value: amount, gas: 50000}("");
        require(success, "ETH transfer failed");
    }
/**
 * @notice Withdraws ERC20 tokens from the contract to a specified address
 * @param token The ERC20 token contract address
 * @param to The address to send tokens to
 * @param amount The amount of tokens to withdraw (in token's smallest unit)
 */
    function withdrawERC20(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        // Validations
        require(token != address(0), "Invalid token address");
        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than 0");

        // Verify token is a contract using RegistrarStorageUtil
        require(util.isContract(token), "Token address is not a contract");

        // Check current balance
        uint256 contractBalance = IERC20(token).balanceOf(address(this));
        require(contractBalance >= amount, "Insufficient token balance");

        // Get balance before transfer (for fee-on-transfer tokens)
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));

        // Use SafeERC20 for safe transfer
        IERC20(token).safeTransfer(to, amount);

        // Calculate actual transferred amount (handles fee-on-transfer tokens)
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        uint256 actualTransferred = balanceBefore - balanceAfter;

        // Emit event with actual transferred amount
        emit ERC20Withdrawn(token, to, actualTransferred, msg.sender, block.timestamp);
    }

    // ==================== ROLE MANAGEMENT FUNCTIONS ====================

    /**
     * @notice Grant relayer role to an address
     * @param relayer Address to grant relayer role
     */
    function grantRelayerRole(address relayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(RELAYER_ROLE, relayer);
        emit RelayerAuthorizationUpdated(relayer, true, msg.sender, block.timestamp);
    }

    /**
     * @notice Revoke relayer role from an address
     * @param relayer Address to revoke relayer role
     */
    function revokeRelayerRole(address relayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(RELAYER_ROLE, relayer);
        emit RelayerAuthorizationUpdated(relayer, false, msg.sender, block.timestamp);
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

}