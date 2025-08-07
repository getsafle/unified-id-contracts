// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

/**
 * @title MotherContractHelpers
 * @author kunalmkv
 * @notice Helper library for RegistrarStorageMother contract
 * @dev Separated to reduce main contract size
 */
library MotherContractHelpers {
    
    // === STORAGE STRUCTURES ===
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

    struct PackedConfig {
        uint128 maxSecondaryAddressesPerChain;
        uint128 maxChainsPerUnifiedId;
        bool emergencyMode;
    }

    // === HELPER FUNCTIONS ===
    
    /**
     * @notice Transfers UnifiedID data from old to new ID
     * @param unifiedIds Mapping of UnifiedIDs
     * @param oldUnifiedId Old UnifiedID
     * @param newUnifiedId New UnifiedID
     * @param config Packed configuration
     */
    function transferUnifiedIdData(
        mapping(string => UnifiedID) storage unifiedIds,
        string memory oldUnifiedId,
        string memory newUnifiedId,
        PackedConfig memory config
    ) internal {
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
            unchecked { ++i; }
        }
    }

    /**
     * @notice Cleans up old UnifiedID data
     * @param unifiedIds Mapping of UnifiedIDs
     * @param oldUnifiedId Old UnifiedID to clean up
     * @param config Packed configuration
     */
    function cleanupOldUnifiedId(
        mapping(string => UnifiedID) storage unifiedIds,
        string memory oldUnifiedId,
        PackedConfig memory config
    ) internal {
        uint256[] memory chainIds = unifiedIds[oldUnifiedId].registeredChainIds;

        uint256 maxIterations = chainIds.length > config.maxChainsPerUnifiedId ?
            uint256(config.maxChainsPerUnifiedId) : chainIds.length;

        for (uint256 i; i < maxIterations;) {
            uint256 cid = chainIds[i];
            delete unifiedIds[oldUnifiedId].chains[cid];
            unchecked { ++i; }
        }

        delete unifiedIds[oldUnifiedId];
    }

    /**
     * @notice Checks if an address exists in an array
     * @param arr Array to search in
     * @param target Address to find
     * @return True if found, false otherwise
     */
    function addressExists(address[] storage arr, address target) internal view returns (bool) {
        for (uint256 i = 0; i < arr.length; ++i) {
            if (arr[i] == target) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Removes an address from an array
     * @param arr Array to remove from
     * @param target Address to remove
     * @return True if removed, false if not found
     */
    function removeAddress(address[] storage arr, address target) internal returns (bool) {
        for (uint256 i = 0; i < arr.length; ++i) {
            if (arr[i] == target) {
                arr[i] = arr[arr.length - 1];
                arr.pop();
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Validates chain data exists
     * @param unifiedIds Mapping of UnifiedIDs
     * @param unifiedId UnifiedID to check
     * @param chainId Chain ID to check
     * @return True if exists, false otherwise
     */
    function chainDataExists(
        mapping(string => UnifiedID) storage unifiedIds,
        string memory unifiedId,
        uint256 chainId
    ) internal view returns (bool) {
        return unifiedIds[unifiedId].exists && unifiedIds[unifiedId].chains[chainId].exists;
    }

    /**
     * @notice Gets chain data safely
     * @param unifiedIds Mapping of UnifiedIDs
     * @param unifiedId UnifiedID
     * @param chainId Chain ID
     * @return ChainData struct
     */
    function getChainData(
        mapping(string => UnifiedID) storage unifiedIds,
        string memory unifiedId,
        uint256 chainId
    ) internal view returns (ChainData storage) {
        require(unifiedIds[unifiedId].exists, "UnifiedID does not exist");
        require(unifiedIds[unifiedId].chains[chainId].exists, "Chain data does not exist");
        return unifiedIds[unifiedId].chains[chainId];
    }
} 