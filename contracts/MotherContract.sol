// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import "./RegistrarStorageUtil.sol";
import "./IUnifiedIdResolver.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract RegistrarStorageMother is OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    RegistrarStorageUtil public util;
    IUnifiedIdResolver public resolver;
    mapping(address => bool) public authorizedRelayers;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

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

    // === ADMIN CONFIGURATION VARIABLES ===
    uint256 public maxSecondaryAddressesPerChain;
    uint256 public maxChainsPerUnifiedId;
    bool public emergencyMode;
    mapping(address => bool) public adminUsers;

    // === ADMIN EVENTS ===
    event MaxSecondaryAddressesPerChainUpdated(uint256 oldMax, uint256 newMax);
    event MaxChainsPerUnifiedIdUpdated(uint256 oldMax, uint256 newMax);
    event EmergencyModeToggled(bool enabled);
    event AdminUserUpdated(address user, bool isAdmin);

    event UnifiedIdRegistered(string indexed unifiedId, address indexed masterAddress, uint256 indexed chainId, address primary);
    event UnifiedIdUpdated(string indexed newUnifiedId, string indexed oldUnifiedId);
    event MasterAddressUpdated(string indexed unifiedId, address indexed newMasterAddress);
    event PrimaryAddressUpdated(string indexed unifiedId, uint256 indexed chainId, address indexed newPrimary);
    event SecondaryAddressAdded(string indexed unifiedId, uint256 indexed chainId, address indexed secondary);
    event SecondaryAddressRemoved(string indexed unifiedId, uint256 indexed chainId, address indexed secondary);
    event RelayerAuthorizationUpdated(address indexed relayer, bool authorized);



    // === ADMIN MODIFIERS ===
    modifier onlyAdmin() {
        require(adminUsers[msg.sender] || msg.sender == owner(), "Caller not admin or owner");
        _;
    }

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
            keccak256("SafleID"),
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
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
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
    function pause() external onlyOwner {
        _pause();
    }
    function unpause() external onlyOwner {
        _unpause();
    }

    function setAuthorizedRelayer(address relayer, bool authorized) external onlyOwner {
        authorizedRelayers[relayer] = authorized;
        emit RelayerAuthorizationUpdated(relayer, authorized);
    }

    function setResolver(address _resolver) external onlyOwner {
        resolver = IUnifiedIdResolver(_resolver);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

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
        for (uint i = 0; i < secondaries.length; i++) {
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

        for (uint256 i = 0; i < chainData.secondaries.length; i++) {
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
        for (uint i = 0; i < chainIds.length; i++) {
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

            for (uint j = 0; j < maxSecondaryIterations; j++) {
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

            for (uint j = 0; j < maxSecondaryIterations; j++) {
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
        for (uint i = 0; i < maxIterations; i++) {
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

    // Check if a chain is registered for a unified ID
    function isChainRegistered(string calldata unifiedId, uint256 chainId) external view returns (bool) {
        uint256[] memory chainIds = unifiedIds[unifiedId].registeredChainIds;

        // Prevent unbounded loop DoS by limiting iterations
        uint256 maxIterations = chainIds.length > maxChainsPerUnifiedId ? maxChainsPerUnifiedId : chainIds.length;

        for (uint i = 0; i < maxIterations; i++) {
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
            keccak256("SAFLE_ID_OPERATION"),
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
        require(_maxChains > 0, "Max chains must be greater than 0");
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
    }

    /**
     * @notice Emergency function to mark unified ID as available
     * @param _unifiedId Unified ID to mark as available
     */
    function emergencyMarkAvailable(string calldata _unifiedId) external onlyAdmin {
        isUnavailableUnifiedId[_unifiedId] = false;
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

        for (uint i = 0; i < maxIterations; i++) {
            if (chainIds[i] == _chainId) {
                chainIds[i] = chainIds[chainIds.length - 1];
                chainIds.pop();
                break;
            }
        }
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
}