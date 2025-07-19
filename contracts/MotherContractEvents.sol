// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

/**
 * @title MotherContractEvents
 * @author kunalmkv
 * @notice Event library for RegistrarStorageMother contract
 * @dev Separated to reduce main contract size
 */
library MotherContractEvents {
    
    // === CORE OPERATION EVENTS ===
    
    event UnifiedIdRegistered(
        address indexed masterAddress,
        address indexed primary,
        uint256 indexed chainId,
        string unifiedId,
        uint256 timestamp
    );

    event UnifiedIdUpdated(
        address indexed masterAddress,
        string oldUnifiedId,
        string newUnifiedId,
        uint256 timestamp
    );

    event MasterAddressUpdated(
        address indexed oldMasterAddress,
        address indexed newMasterAddress,
        string unifiedId,
        uint256 timestamp
    );

    event PrimaryAddressUpdated(
        uint256 indexed chainId,
        address indexed oldPrimary,
        address indexed newPrimary,
        string unifiedId,
        uint256 timestamp
    );

    event SecondaryAddressAdded(
        uint256 indexed chainId,
        address indexed secondaryAddress,
        string unifiedId,
        uint256 timestamp
    );

    event SecondaryAddressRemoved(
        uint256 indexed chainId,
        address indexed secondaryAddress,
        string unifiedId,
        uint256 timestamp
    );

    // === ADMIN & CONFIGURATION EVENTS ===
    
    event OwnershipTransferStarted(
        address indexed previousOwner,
        address indexed newOwner,
        uint256 timestamp
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner,
        uint256 timestamp
    );

    event MaxSecondaryAddressesPerChainUpdated(
        uint256 oldMax,
        uint256 newMax,
        address indexed updatedBy,
        uint256 timestamp
    );

    event MaxChainsPerUnifiedIdUpdated(
        uint256 oldMax,
        uint256 newMax,
        address indexed updatedBy,
        uint256 timestamp
    );

    event EmergencyModeToggled(
        bool enabled,
        address indexed updatedBy,
        uint256 timestamp
    );

    event ResolverUpdated(
        address indexed oldResolver,
        address indexed newResolver,
        address indexed updatedBy,
        uint256 timestamp
    );

    event ContractPaused(
        address indexed pausedBy,
        uint256 timestamp
    );

    event ContractUnpaused(
        address indexed unpausedBy,
        uint256 timestamp
    );

    event RelayerAuthorizationUpdated(
        address indexed relayer,
        bool authorized,
        address indexed updatedBy,
        uint256 timestamp
    );

    event UpgradeAuthorized(
        address indexed newImplementation,
        address indexed authorizedBy,
        uint256 timestamp
    );

    // === EMERGENCY EVENTS ===
    
    event EmergencyUnifiedIdMarked(
        address indexed updatedBy,
        bool available,
        string  unifiedId,
        uint256 timestamp
    );

    event EmergencyChainDataCleared(
        uint256 indexed chainId,
        address indexed clearedBy,
        string unifiedId,
        uint256 timestamp
    );

    // === WITHDRAWAL EVENTS ===
    
    event EthWithdrawn(
        address indexed to,
        uint256 amount,
        address indexed withdrawnBy,
        uint256 timestamp
    );

    event ERC20Withdrawn(
        address indexed token,
        address indexed to,
        uint256 amount,
        address indexed withdrawnBy,
        uint256 timestamp
    );
} 