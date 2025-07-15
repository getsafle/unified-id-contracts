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
        string indexed unifiedId,
        address indexed masterAddress,
        uint256 indexed chainId,
        address primary,
        uint256 timestamp
    );

    event UnifiedIdUpdated(
        string indexed oldUnifiedId,
        string indexed newUnifiedId,
        address indexed masterAddress,
        uint256 timestamp
    );

    event MasterAddressUpdated(
        string indexed unifiedId,
        address indexed oldMasterAddress,
        address indexed newMasterAddress,
        uint256 timestamp
    );

    event PrimaryAddressUpdated(
        string indexed unifiedId,
        uint256 indexed chainId,
        address indexed oldPrimary,
        address newPrimary,
        uint256 timestamp
    );

    event SecondaryAddressAdded(
        string indexed unifiedId,
        uint256 indexed chainId,
        address indexed secondaryAddress,
        uint256 timestamp
    );

    event SecondaryAddressRemoved(
        string indexed unifiedId,
        uint256 indexed chainId,
        address indexed secondaryAddress,
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
        string indexed unifiedId,
        bool available,
        address indexed updatedBy,
        uint256 timestamp
    );

    event EmergencyChainDataCleared(
        string indexed unifiedId,
        uint256 indexed chainId,
        address indexed clearedBy,
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