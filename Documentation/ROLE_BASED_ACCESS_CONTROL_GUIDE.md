# Role-Based Access Control Implementation Guide

## Overview

This document outlines the comprehensive role-based access control (RBAC) implementation across all UnifiedID contracts using OpenZeppelin's AccessControl framework. The implementation replaces simple mapping-based authorization with a standardized, secure, and flexible role management system.

## Key Benefits

### 1. **Standardization**
- Uses OpenZeppelin's battle-tested AccessControl implementation
- Consistent role management across all contracts
- Industry-standard patterns and security practices

### 2. **Enhanced Security**
- Granular permission control with specific roles
- Role hierarchy with admin controls
- Automatic role inheritance and delegation
- Built-in protection against unauthorized access

### 3. **Flexibility**
- Multiple roles per address
- Role-specific function access
- Easy role granting and revocation
- Hierarchical role management

### 4. **Gas Efficiency**
- Optimized role checking mechanisms
- Reduced storage overhead compared to multiple mappings
- Efficient role enumeration and management

## Contract-by-Contract Implementation

### 1. MotherContract.sol

#### Roles Defined
```solidity
bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```

#### Role Responsibilities
- **RELAYER_ROLE**: Execute unified ID operations (register, update, add/remove addresses)
- **ADMIN_ROLE**: Administrative functions (pause/unpause, configuration changes)
- **EMERGENCY_ROLE**: Emergency operations (mark unavailable, cleanup)
- **UPGRADER_ROLE**: Contract upgrade authorization

#### Key Functions
```solidity
// Role management
function grantRelayerRole(address relayer) external onlyRole(DEFAULT_ADMIN_ROLE)
function revokeRelayerRole(address relayer) external onlyRole(DEFAULT_ADMIN_ROLE)
function grantAdminRole(address admin) external onlyRole(DEFAULT_ADMIN_ROLE)
function grantEmergencyRole(address emergency) external onlyRole(DEFAULT_ADMIN_ROLE)
function grantUpgraderRole(address upgrader) external onlyRole(DEFAULT_ADMIN_ROLE)

// Role checking
function isRelayer(address account) external view returns (bool)
function isAdmin(address account) external view returns (bool)
function isEmergencyResponder(address account) external view returns (bool)
function isUpgrader(address account) external view returns (bool)
```

### 2. RegistrarStorageChildEvents.sol

#### Roles Defined
```solidity
bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```

#### Role Responsibilities
- **RELAYER_ROLE**: Complete operations initiated by registrars
- **REGISTRAR_ROLE**: Initiate unified ID operations
- **ADMIN_ROLE**: Administrative functions and configuration
- **EMERGENCY_ROLE**: Emergency operations and registrar management
- **UPGRADER_ROLE**: Contract upgrade authorization

#### Automatic Role Assignment
```solidity
function registerRegistrar(string calldata _registrarName, address _registrarAddress) external {
    // ... validation logic ...
    
    // Automatically grant registrar role
    _grantRole(REGISTRAR_ROLE, _registrarAddress);
    
    emit RegistrarRegistered(_registrarAddress, _registrarName);
}
```

### 3. UnifiedIdResolver.sol

#### Roles Defined
```solidity
bytes32 public constant AUTHORIZED_CALLER_ROLE = keccak256("AUTHORIZED_CALLER_ROLE");
bytes32 public constant REGISTRY_ROLE = keccak256("REGISTRY_ROLE");
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```

#### Role Responsibilities
- **AUTHORIZED_CALLER_ROLE**: Modify resolver records
- **REGISTRY_ROLE**: Registry contract permissions with enhanced access
- **ADMIN_ROLE**: Administrative functions
- **UPGRADER_ROLE**: Contract upgrade authorization

#### Enhanced Authorization Logic
```solidity
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
```

### 4. RegistrarStorageUtil.sol

#### Roles Defined
```solidity
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
bytes32 public constant PRICE_FEED_MANAGER_ROLE = keccak256("PRICE_FEED_MANAGER_ROLE");
bytes32 public constant CONFIG_MANAGER_ROLE = keccak256("CONFIG_MANAGER_ROLE");
```

#### Role Responsibilities
- **ADMIN_ROLE**: General administrative functions
- **PRICE_FEED_MANAGER_ROLE**: Manage Chainlink price feeds
- **CONFIG_MANAGER_ROLE**: Manage configuration parameters

#### Specialized Role Functions
```solidity
function setTokenPriceFeed(address token, address priceFeed, uint256 decimal) 
    external onlyRole(PRICE_FEED_MANAGER_ROLE)

function setUnifiedIdLengthLimits(uint8 _minLength, uint8 _maxLength) 
    external onlyRole(CONFIG_MANAGER_ROLE)
```

## Role Hierarchy and Permissions

### Default Admin Role
- **DEFAULT_ADMIN_ROLE**: Can grant and revoke all other roles
- Automatically assigned to contract deployer
- Can delegate admin responsibilities

### Role Inheritance
```
DEFAULT_ADMIN_ROLE (Super Admin)
├── ADMIN_ROLE (General Admin)
├── EMERGENCY_ROLE (Emergency Responder)
├── UPGRADER_ROLE (Contract Upgrader)
├── RELAYER_ROLE (Operation Executor)
├── REGISTRAR_ROLE (Operation Initiator)
├── AUTHORIZED_CALLER_ROLE (Resolver Access)
├── REGISTRY_ROLE (Registry Contract)
├── PRICE_FEED_MANAGER_ROLE (Price Feed Manager)
└── CONFIG_MANAGER_ROLE (Configuration Manager)
```

## Migration from Mapping-Based Access Control

### Before (Mapping-Based)
```solidity
mapping(address => bool) public authorizedRelayers;
mapping(address => bool) public adminUsers;

modifier onlyAuthorizedRelayer() {
    require(authorizedRelayers[msg.sender], "Not authorized relayer");
    _;
}

function setAuthorizedRelayer(address relayer, bool authorized) external onlyOwner {
    authorizedRelayers[relayer] = authorized;
}
```

### After (Role-Based)
```solidity
bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

modifier onlyAuthorizedRelayer() {
    require(hasRole(RELAYER_ROLE, msg.sender), "AccessControl: caller is not relayer");
    _;
}

function grantRelayerRole(address relayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _grantRole(RELAYER_ROLE, relayer);
}
```

## Usage Examples

### 1. Granting Roles
```solidity
// Grant relayer role to an address
motherContract.grantRelayerRole(relayerAddress);

// Grant admin role to multiple addresses
motherContract.grantAdminRole(admin1);
motherContract.grantAdminRole(admin2);

// Grant emergency role for incident response
motherContract.grantEmergencyRole(emergencyResponder);
```

### 2. Checking Roles
```solidity
// Check if address has specific role
bool isRelayer = motherContract.isRelayer(someAddress);
bool isAdmin = motherContract.isAdmin(someAddress);

// Check using OpenZeppelin's hasRole function
bool hasRelayerRole = motherContract.hasRole(RELAYER_ROLE, someAddress);
```

### 3. Revoking Roles
```solidity
// Revoke roles when no longer needed
motherContract.revokeRelayerRole(formerRelayer);
motherContract.revokeAdminRole(formerAdmin);
```

### 4. Role Enumeration
```solidity
// Get role member count
uint256 relayerCount = motherContract.getRoleMemberCount(RELAYER_ROLE);

// Get role member by index
address firstRelayer = motherContract.getRoleMember(RELAYER_ROLE, 0);
```

## Security Considerations

### 1. **Role Assignment**
- Only DEFAULT_ADMIN_ROLE can grant/revoke roles
- Careful consideration when assigning admin roles
- Regular audit of role assignments

### 2. **Role Separation**
- Different roles for different responsibilities
- Principle of least privilege
- No unnecessary role accumulation

### 3. **Emergency Procedures**
- EMERGENCY_ROLE for critical situations
- Separate from regular admin functions
- Limited scope of emergency powers

### 4. **Upgrade Security**
- UPGRADER_ROLE separate from admin roles
- Multi-signature recommended for upgrades
- Thorough testing before role assignment

## Best Practices

### 1. **Role Management**
```solidity
// Good: Specific role for specific function
function emergencyPause() external onlyRole(EMERGENCY_ROLE) {
    _pause();
}

// Avoid: Using admin for everything
function emergencyPause() external onlyRole(ADMIN_ROLE) {
    _pause();
}
```

### 2. **Role Checking**
```solidity
// Good: Use role-specific functions
function isAuthorizedRelayer(address account) external view returns (bool) {
    return hasRole(RELAYER_ROLE, account);
}

// Good: Combine roles when appropriate
modifier onlyAdminOrOwner() {
    require(hasRole(ADMIN_ROLE, msg.sender) || msg.sender == owner(), "Not authorized");
    _;
}
```

### 3. **Event Emission**
```solidity
// Emit events for role changes
function grantRelayerRole(address relayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _grantRole(RELAYER_ROLE, relayer);
    emit RelayerAuthorizationUpdated(relayer, true);
}
```

## Integration with Frontend

### 1. **Role Detection**
```javascript
// Check user roles
const isRelayer = await motherContract.isRelayer(userAddress);
const isAdmin = await motherContract.isAdmin(userAddress);

// Enable/disable UI elements based on roles
if (isAdmin) {
    showAdminPanel();
}
if (isRelayer) {
    showRelayerFunctions();
}
```

### 2. **Role-Based UI**
```javascript
// Dynamic UI based on user roles
const userRoles = await Promise.all([
    motherContract.isRelayer(userAddress),
    motherContract.isAdmin(userAddress),
    motherContract.isEmergencyResponder(userAddress)
]);

const [isRelayer, isAdmin, isEmergency] = userRoles;

// Show appropriate interface
renderUserInterface({ isRelayer, isAdmin, isEmergency });
```

## Testing Role-Based Access Control

### 1. **Role Assignment Tests**
```javascript
describe("Role Management", () => {
    it("should grant relayer role", async () => {
        await motherContract.grantRelayerRole(relayerAddress);
        expect(await motherContract.isRelayer(relayerAddress)).to.be.true;
    });

    it("should revoke admin role", async () => {
        await motherContract.grantAdminRole(adminAddress);
        await motherContract.revokeAdminRole(adminAddress);
        expect(await motherContract.isAdmin(adminAddress)).to.be.false;
    });
});
```

### 2. **Access Control Tests**
```javascript
describe("Access Control", () => {
    it("should allow only relayers to execute operations", async () => {
        await expect(
            motherContract.connect(nonRelayer).registerUnifiedId(...)
        ).to.be.revertedWith("AccessControl: caller is not relayer");
    });

    it("should allow admins to pause contract", async () => {
        await motherContract.grantAdminRole(adminAddress);
        await expect(
            motherContract.connect(admin).pause()
        ).to.not.be.reverted;
    });
});
```

## Deployment and Initialization

### 1. **Contract Deployment**
```javascript
// Deploy with role setup
const motherContract = await MotherContract.deploy();
await motherContract.initialize(utilAddress, resolverAddress);

// Initial role assignments
await motherContract.grantRelayerRole(relayerAddress);
await motherContract.grantAdminRole(adminAddress);
```

### 2. **Role Configuration**
```javascript
// Configure roles for production
const roles = {
    relayers: [relayer1, relayer2, relayer3],
    admins: [admin1, admin2],
    emergency: [emergencyResponder],
    upgraders: [upgraderAddress]
};

// Grant roles
for (const relayer of roles.relayers) {
    await motherContract.grantRelayerRole(relayer);
}

for (const admin of roles.admins) {
    await motherContract.grantAdminRole(admin);
}
```

## Conclusion

The role-based access control implementation provides:

1. **Enhanced Security**: Granular permissions and standardized access control
2. **Better Organization**: Clear separation of responsibilities
3. **Improved Maintainability**: Standardized role management across contracts
4. **Future-Proof Design**: Flexible role system for evolving requirements
5. **Industry Standards**: OpenZeppelin's battle-tested implementation

This implementation significantly improves the security posture and maintainability of the UnifiedID system while providing a foundation for future enhancements and integrations. 