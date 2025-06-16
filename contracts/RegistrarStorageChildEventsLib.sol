// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import "./IUnifiedIdResolver.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title RegistrarStorageChildEventsLib
 * @author kunalmkv
 * @notice Library to reduce contract size by extracting view functions and role management
 * @dev Contains view functions and role management logic extracted from RegistrarStorageChildEvents
 */
library RegistrarStorageChildEventsLib {
    
    // ==================== ROLE MANAGEMENT FUNCTIONS ====================
    
    /**
     * @notice Grant relayer role to an address
     * @param self The AccessControl contract instance
     * @param relayer Address to grant relayer role
     * @param RELAYER_ROLE The relayer role constant
     */
    function grantRelayerRole(
        AccessControlUpgradeable self,
        address relayer,
        bytes32 RELAYER_ROLE
    ) external {
        self.grantRole(RELAYER_ROLE, relayer);
    }

    /**
     * @notice Revoke relayer role from an address
     * @param self The AccessControl contract instance
     * @param relayer Address to revoke relayer role
     * @param RELAYER_ROLE The relayer role constant
     */
    function revokeRelayerRole(
        AccessControlUpgradeable self,
        address relayer,
        bytes32 RELAYER_ROLE
    ) external {
        self.revokeRole(RELAYER_ROLE, relayer);
    }

    /**
     * @notice Grant registrar role to an address
     * @param self The AccessControl contract instance
     * @param registrar Address to grant registrar role
     * @param REGISTRAR_ROLE The registrar role constant
     */
    function grantRegistrarRole(
        AccessControlUpgradeable self,
        address registrar,
        bytes32 REGISTRAR_ROLE
    ) external {
        self.grantRole(REGISTRAR_ROLE, registrar);
    }

    /**
     * @notice Revoke registrar role from an address
     * @param self The AccessControl contract instance
     * @param registrar Address to revoke registrar role
     * @param REGISTRAR_ROLE The registrar role constant
     */
    function revokeRegistrarRole(
        AccessControlUpgradeable self,
        address registrar,
        bytes32 REGISTRAR_ROLE
    ) external {
        self.revokeRole(REGISTRAR_ROLE, registrar);
    }

    /**
     * @notice Grant admin role to an address
     * @param self The AccessControl contract instance
     * @param admin Address to grant admin role
     * @param ADMIN_ROLE The admin role constant
     */
    function grantAdminRole(
        AccessControlUpgradeable self,
        address admin,
        bytes32 ADMIN_ROLE
    ) external {
        self.grantRole(ADMIN_ROLE, admin);
    }

    /**
     * @notice Revoke admin role from an address
     * @param self The AccessControl contract instance
     * @param admin Address to revoke admin role
     * @param ADMIN_ROLE The admin role constant
     */
    function revokeAdminRole(
        AccessControlUpgradeable self,
        address admin,
        bytes32 ADMIN_ROLE
    ) external {
        self.revokeRole(ADMIN_ROLE, admin);
    }

    /**
     * @notice Grant emergency role to an address
     * @param self The AccessControl contract instance
     * @param emergency Address to grant emergency role
     * @param EMERGENCY_ROLE The emergency role constant
     */
    function grantEmergencyRole(
        AccessControlUpgradeable self,
        address emergency,
        bytes32 EMERGENCY_ROLE
    ) external {
        self.grantRole(EMERGENCY_ROLE, emergency);
    }

    /**
     * @notice Revoke emergency role from an address
     * @param self The AccessControl contract instance
     * @param emergency Address to revoke emergency role
     * @param EMERGENCY_ROLE The emergency role constant
     */
    function revokeEmergencyRole(
        AccessControlUpgradeable self,
        address emergency,
        bytes32 EMERGENCY_ROLE
    ) external {
        self.revokeRole(EMERGENCY_ROLE, emergency);
    }

    /**
     * @notice Grant upgrader role to an address
     * @param self The AccessControl contract instance
     * @param upgrader Address to grant upgrader role
     * @param UPGRADER_ROLE The upgrader role constant
     */
    function grantUpgraderRole(
        AccessControlUpgradeable self,
        address upgrader,
        bytes32 UPGRADER_ROLE
    ) external {
        self.grantRole(UPGRADER_ROLE, upgrader);
    }

    /**
     * @notice Revoke upgrader role from an address
     * @param self The AccessControl contract instance
     * @param upgrader Address to revoke upgrader role
     * @param UPGRADER_ROLE The upgrader role constant
     */
    function revokeUpgraderRole(
        AccessControlUpgradeable self,
        address upgrader,
        bytes32 UPGRADER_ROLE
    ) external {
        self.revokeRole(UPGRADER_ROLE, upgrader);
    }

    // ==================== VIEW FUNCTIONS ====================

    /**
     * @notice Get registrar name for an address (optimized with parallel arrays)
     * @param registrarAddresses Array of registrar addresses
     * @param registrarNames Array of registrar names
     * @param _address The registrar address
     * @return The registrar name, empty string if not found
     */
    function getRegistrarName(
        address[] storage registrarAddresses,
        string[] storage registrarNames,
        address _address
    ) internal view returns (string memory) {
        for (uint256 i = 0; i < registrarAddresses.length; i++) {
            if (registrarAddresses[i] == _address) {
                return registrarNames[i];
            }
        }
        return "";
    }

    /**
     * @notice Check if an address is taken by a registrar
     * @param registrarAddresses Array of registrar addresses
     * @param _address The address to check
     * @return True if address is taken by a registrar
     */
    function isAddressTaken(
        address[] storage registrarAddresses,
        address _address
    ) internal view returns (bool) {
        for (uint256 i = 0; i < registrarAddresses.length; i++) {
            if (registrarAddresses[i] == _address) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Get registrar info for an address
     * @param self The AccessControl contract instance
     * @param registrarAddresses Array of registrar addresses
     * @param registrarNames Array of registrar names
     * @param totalRegistrarUpdates Mapping of update counts
     * @param _address The address to get info for
     * @param REGISTRAR_ROLE The registrar role constant
     * @return isRegistrar True if address is a registrar
     * @return registrarName The registrar name
     * @return updateCount Number of updates
     */
    function getRegistrarInfo(
        AccessControlUpgradeable self,
        address[] storage registrarAddresses,
        string[] storage registrarNames,
        mapping(address => uint8) storage totalRegistrarUpdates,
        address _address,
        bytes32 REGISTRAR_ROLE
    ) external view returns (
        bool isRegistrar,
        string memory registrarName,
        uint8 updateCount
    ) {
        return (
            self.hasRole(REGISTRAR_ROLE, _address),
            getRegistrarName(registrarAddresses, registrarNames, _address),
            totalRegistrarUpdates[_address]
        );
    }

    // ==================== RESOLVER DELEGATION FUNCTIONS ====================

    /**
     * @notice Resolves a secondary address to its UnifiedId
     * @param resolver The resolver contract
     * @param secondaryAddr The secondary address to resolve
     * @param chainId The chain ID
     * @return The UnifiedId that the secondary address belongs to
     */
    function resolveSecondaryAddressToUnifiedId(
        IUnifiedIdResolver resolver,
        address secondaryAddr,
        uint256 chainId
    ) external view returns (string memory) {
        return resolver.resolveSecondaryAddressToUnifiedId(secondaryAddr, chainId);
    }

    /**
     * @notice Resolves any address (primary or secondary) to its UnifiedId
     * @param resolver The resolver contract
     * @param addr The address to resolve
     * @param chainId The chain ID
     * @return unifiedId The UnifiedId associated with the address
     * @return isPrimary True if the address is a primary address
     * @return isSecondary True if the address is a secondary address
     */
    function resolveAnyAddressToUnifiedId(
        IUnifiedIdResolver resolver,
        address addr,
        uint256 chainId
    ) external view returns (
        string memory unifiedId,
        bool isPrimary,
        bool isSecondary
    ) {
        return resolver.resolveAnyAddressToUnifiedId(addr, chainId);
    }

    /**
     * @notice Gets all addresses for a UnifiedId
     * @param resolver The resolver contract
     * @param unifiedId The UnifiedId to get addresses for
     * @param chainId The chain ID
     * @return allAddresses Array containing all addresses
     */
    function getAllAddresses(
        IUnifiedIdResolver resolver,
        string calldata unifiedId,
        uint256 chainId
    ) external view returns (address[] memory allAddresses) {
        return resolver.getAllAddresses(unifiedId, chainId);
    }

    /**
     * @notice Gets the total count of addresses for a UnifiedId
     * @param resolver The resolver contract
     * @param unifiedId The UnifiedId to count addresses for
     * @param chainId The chain ID
     * @return count Total number of addresses
     */
    function getAddressCount(
        IUnifiedIdResolver resolver,
        string calldata unifiedId,
        uint256 chainId
    ) external view returns (uint256 count) {
        return resolver.getAddressCount(unifiedId, chainId);
    }
} 