// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./RegistrarStorageUtil.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract RegistrarStorageMother is OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    RegistrarStorageUtil public util;
    mapping(address => bool) public authorizedRelayers;

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

    modifier whenNotPaused() {
        require(!paused(), "Contract is paused");
        _;
    }

    // === ADMIN MODIFIERS ===
    modifier onlyAdmin() {
        require(adminUsers[msg.sender] || msg.sender == owner(), "Caller not admin or owner");
        _;
    }
    
    modifier notInEmergencyMode() {
        require(!emergencyMode, "Contract in emergency mode");
        _;
    }
    


    modifier verifySignature(bytes memory data, address expectedSigner, bytes memory signature) {
        (string memory unifiedId, ) = abi.decode(data, (string, address));
        uint256 nonce = nonces[unifiedId];
        bytes memory dataWithNonce = abi.encodePacked(data, nonce);
        require(util.verifySignature(dataWithNonce, expectedSigner, signature), "Invalid signature");
        _;
    }

    function initialize(address _util) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
        util = RegistrarStorageUtil(_util);
        
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

        if (!uid.exists) {
            requireSignature(data, primary, primarySignature);
            uid.masterAddress = primary;
            uid.exists = true;
        } else {
            requireSignature(data, uid.masterAddress, masterSignature);
            requireSignature(data, primary, primarySignature);
        }

        chainData.primary = primary;
        chainData.exists = true;
        uid.registeredChainIds.push(chainId);

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

        requireSignature(data, currentPrimary, currentPrimarySignature);
        requireSignature(data, newPrimary, newPrimarySignature);

        unifiedIds[unifiedId].chains[chainId].primary = newPrimary;

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

        requireSignature(data, primary, primarySignature);
        requireSignature(data, secondary, secondarySignature);

        ChainData storage chainData = unifiedIds[unifiedId].chains[chainId];
        require(chainData.secondaries.length < maxSecondaryAddressesPerChain, "Maximum secondary addresses per chain reached");
        
        chainData.secondaries.push(secondary);

        emit SecondaryAddressAdded(unifiedId, chainId, secondary);
        nonces[unifiedId]++;
    }

    function removeSecondaryAddress(
        string calldata unifiedId,
        uint256 chainId,
        address secondary,
        bytes memory data,
        bytes memory signature
    )
        external
        onlyRelayer
        whenNotPaused
        verifySignature(data, unifiedIds[unifiedId].chains[chainId].primary, signature)
    {
        require(unifiedIds[unifiedId].exists, "UnifiedID does not exist");
        require(unifiedIds[unifiedId].chains[chainId].exists, "Chain data does not exist");

        ChainData storage chainData = unifiedIds[unifiedId].chains[chainId];

        for (uint256 i = 0; i < chainData.secondaries.length; i++) {
            if (chainData.secondaries[i] == secondary) {
                chainData.secondaries[i] = chainData.secondaries[chainData.secondaries.length - 1];
                chainData.secondaries.pop();
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
    ) external onlyRelayer whenNotPaused verifySignature(data, unifiedIds[oldUnifiedId].masterAddress, signature) {
        require(!isUnavailableUnifiedId[oldUnifiedId], "Old UnifiedID is unavailable");
        require(!isUnavailableUnifiedId[newUnifiedId], "New UnifiedID is unavailable");
        require(unifiedIds[oldUnifiedId].exists, "Old UnifiedID does not exist");
        require(!unifiedIds[newUnifiedId].exists, "New UnifiedID already exists");

        UnifiedID storage existing = unifiedIds[oldUnifiedId];
        uint256[] memory chainIds = existing.registeredChainIds;

        UnifiedID storage updated = unifiedIds[newUnifiedId];
        updated.masterAddress = existing.masterAddress;
        updated.exists = true;

        // Copy chain data efficiently
        for (uint i = 0; i < chainIds.length; i++) {
            uint256 cid = chainIds[i];
            updated.chains[cid] = existing.chains[cid];
            updated.registeredChainIds.push(cid);
        }

        // Clean up existing data
        for (uint i = 0; i < chainIds.length; i++) {
            uint256 cid = chainIds[i];
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
    ) external onlyRelayer whenNotPaused verifySignature(data, unifiedIds[unifiedId].masterAddress, signature) {
        require(unifiedIds[unifiedId].exists, "UnifiedID does not exist");

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
        for (uint i = 0; i < chainIds.length; i++) {
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

    function requireSignature(bytes memory data, address expectedSigner, bytes memory signature) internal view {
        (string memory unifiedId, address addressdec) = abi.decode(data, (string, address));
        uint256 nonce = nonces[unifiedId];
        bytes memory dataWithNonce = abi.encode(unifiedId, addressdec, nonce);
        require(util.verifySignature(dataWithNonce, expectedSigner, signature), "Invalid signature");
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
        for (uint i = 0; i < chainIds.length; i++) {
            if (chainIds[i] == _chainId) {
                chainIds[i] = chainIds[chainIds.length - 1];
                chainIds.pop();
                break;
            }
        }
    }
    

    
    /**
     * @notice Get contract configuration
     * @return Configuration parameters
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
