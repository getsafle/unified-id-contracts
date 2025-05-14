// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

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

    string[] public unavailableUnifiedIds;
    mapping(string => bool) public isUnavailableUnifiedId;

    mapping(string => uint256) public nonces;

    // Events
    event UnifiedIdRegistered(string unifiedId, address masterAddress, uint256 chainId, address primary);
    event UnifiedIdUpdated(string newUnifiedId, string oldUnifiedId);
    event MasterAddressUpdated(string unifiedId, address newMasterAddress);
    event PrimaryAddressUpdated(string unifiedId, uint256 chainId, address newPrimary);
    event SecondaryAddressAdded(string unifiedId, uint256 chainId, address secondary);
    event SecondaryAddressRemoved(string unifiedId, uint256 chainId, address secondary);
    event RelayerAuthorizationUpdated(address relayer, bool authorized);

    function initialize(address _util) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
        util = RegistrarStorageUtil(_util);
    }

    modifier onlyRelayer() {
        require(authorizedRelayers[msg.sender], "Caller not authorized relayer");
        _;
    }

    modifier verifySignature(bytes memory data, address expectedSigner, bytes memory signature) {
        (string memory unifiedId, ) = abi.decode(data, (string, address));
        uint256 nonce = nonces[unifiedId];
        bytes memory dataWithNonce = abi.encodePacked(data, nonce);
        require(util.verifySignature(dataWithNonce, expectedSigner, signature), "Invalid signature");
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
    ) external onlyRelayer whenNotPaused {
        require(!isUnavailableUnifiedId[unifiedId], "UnifiedID is unavailable");
        UnifiedID storage uid = unifiedIds[unifiedId];

        ChainData storage chainData = uid.chains[chainId];
        require(!chainData.exists, "Chain data already exists");

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

        unifiedIds[unifiedId].chains[chainId].secondaries.push(secondary);

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

        for (uint i = 0; i < chainIds.length; i++) {
            uint256 cid = chainIds[i];
            updated.chains[cid] = existing.chains[cid];
            updated.registeredChainIds.push(cid);
        }

        for (uint i = 0; i < chainIds.length; i++) {
            delete existing.chains[chainIds[i]];
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

    // Internal wrapper for utility
    function requireSignature(bytes memory data, address expectedSigner, bytes memory signature) internal view {
        (string memory unifiedId, address addressdec) = abi.decode(data, (string, address));
        uint256 nonce = nonces[unifiedId];
        bytes memory dataWithNonce = abi.encode(unifiedId, addressdec, nonce);
        require(util.verifySignature(dataWithNonce, expectedSigner, signature), "Invalid signature");
    }
}
