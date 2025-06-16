# 🚀 Unified ID Management System - Complete Deployment Guide

## 📋 System Overview

The Unified ID Management System has been significantly optimized and enhanced with the following architecture:

### Core Contracts (5 main contracts + 2 libraries)
1. **RegistrarStorageUtil.sol** (29KB) - Utility functions, signature verification, price feeds
2. **UnifiedIdResolver.sol** (38KB) - Multi-chain address resolution engine  
3. **MotherContract.sol** (34KB) - Cross-chain unified ID management hub
4. **RegistrarStorageChildEvents.sol** (36KB) - Single-chain operations with events
5. **IUnifiedIdResolver.sol** (21KB) - Interface definitions

### Supporting Libraries
6. **RegistrarStorageChildEventsLib.sol** (10KB) - View functions and role management
7. **RegistrarOperationsLib.sol** (12KB) - Core business logic operations
8. **SignatureVerifier.sol** (10KB) - EIP-712 signature verification

### Key Features Implemented
- ✅ **Ownable2Step** - Secure two-step ownership transfer
- ✅ **Role-Based Access Control** - OpenZeppelin AccessControl integration
- ✅ **Contract Size Optimization** - Libraries to reduce main contract sizes
- ✅ **Gas Optimizations** - Enum errors, packed structs, optimized storage
- ✅ **EIP-712 Signatures** - Secure signature verification system
- ✅ **Multi-chain Support** - Cross-chain unified ID management
- ✅ **UUPS Upgradeable** - Future-proof upgrade mechanism

## 🔧 Prerequisites

### Development Environment
- **Solidity**: ^0.8.25
- **OpenZeppelin Contracts**: ^4.9.0
- **OpenZeppelin Contracts Upgradeable**: ^4.9.0
- **Chainlink Contracts**: ^0.8.0 (for price feeds)

### Required Addresses (Prepare Before Deployment)
- **Deployer Address**: Your deployment wallet
- **Owner Address**: Final owner (can be same as deployer)
- **Relayer Address**: Authorized relayer for operations
- **Admin Address**: Admin for configuration (optional)
- **ETH/USD Price Feed**: Chainlink price feed address for your network

### Network-Specific Chainlink Price Feeds
```javascript
// Ethereum Mainnet
const ETH_USD_FEED = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";

// Polygon Mainnet  
const ETH_USD_FEED = "0xF9680D99D6C9589e2a93a78A04A279e509205945";

// BSC Mainnet
const ETH_USD_FEED = "0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e";

// Arbitrum One
const ETH_USD_FEED = "0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612";

// For testnets, check Chainlink documentation
```

## 📦 Phase 1: Environment Setup

### 1.1 Remix IDE Setup
1. Open [Remix IDE](https://remix.ethereum.org)
2. Create new workspace: `unified-id-contracts`
3. Create folder structure:
   ```
   contracts/
   ├── interfaces/
   │   └── IUnifiedIdResolver.sol
   ├── libraries/
   │   ├── RegistrarStorageChildEventsLib.sol
   │   ├── RegistrarOperationsLib.sol
   │   └── SignatureVerifier.sol
   ├── utils/
   │   └── RegistrarStorageUtil.sol
   └── core/
       ├── UnifiedIdResolver.sol
       ├── MotherContract.sol
       └── RegistrarStorageChildEvents.sol
   ```

### 1.2 Install Dependencies
1. Go to File Explorer → `.deps` folder
2. Install required packages:
   - `@openzeppelin/contracts@4.9.0`
   - `@openzeppelin/contracts-upgradeable@4.9.0`
   - `@chainlink/contracts@0.8.0`

### 1.3 Compiler Configuration
1. Go to `Solidity Compiler` tab
2. Set compiler version: `0.8.25`
3. **Enable optimization**: `runs: 200` (CRITICAL for contract size)
4. Advanced configurations:
   ```json
   {
     "optimizer": {
       "enabled": true,
       "runs": 200
     },
     "viaIR": false
   }
   ```

## 📋 Phase 2: Pre-Deployment Checklist

### 2.1 Contract Size Verification
After compilation, verify contract sizes are under 24KB:
- ✅ RegistrarStorageUtil: ~15KB (after optimization)
- ✅ UnifiedIdResolver: ~20KB (after optimization)  
- ✅ MotherContract: ~18KB (after optimization)
- ✅ RegistrarStorageChildEvents: ~22KB (after optimization)

### 2.2 Compilation Check
Ensure all contracts compile without errors:
```bash
# All contracts should show green checkmarks
✅ IUnifiedIdResolver.sol
✅ SignatureVerifier.sol
✅ RegistrarStorageUtil.sol
✅ UnifiedIdResolver.sol
✅ MotherContract.sol
✅ RegistrarStorageChildEvents.sol
```

## 🚀 Phase 3: Deployment Sequence

> ⚠️ **CRITICAL**: Deploy in this exact order due to dependencies

### 3.1 Deploy RegistrarStorageUtil (First)

**Why First**: No dependencies, provides utility functions for other contracts

**Deploy Steps**:
1. Select `RegistrarStorageUtil` contract
2. Deploy with **no constructor parameters**
3. **Record address**: `UTIL_ADDRESS = 0x...`

**Post-Deployment Verification**:
```javascript
// Verify deployment
util.owner(); // Should return your address
util.getConfiguration(); // Should return default config
```

**Initial Configuration**:
```javascript
// Set ETH price feed (REQUIRED for price calculations)
util.setEthPriceFeed("ETH_USD_PRICE_FEED_ADDRESS");

// Optional: Set token price feeds if needed
util.setTokenPriceFeed("TOKEN_ADDRESS", "TOKEN_USD_FEED", TOKEN_DECIMALS);
```

### 3.2 Deploy UnifiedIdResolver (Second)

**Why Second**: No dependencies on other custom contracts

**Deploy Steps**:
1. Select `UnifiedIdResolver` contract
2. Deploy with **no constructor parameters** (uses initializer)
3. **Record address**: `RESOLVER_ADDRESS = 0x...`

**Initialize**:
```javascript
// Initialize with zero address (will be updated later)
resolver.initialize("0x0000000000000000000000000000000000000000");
```

**Post-Deployment Verification**:
```javascript
// Verify initialization
resolver.owner(); // Should return your address
resolver.getRegistry(); // Should return zero address initially
```

### 3.3 Deploy MotherContract (Third)

**Why Third**: Depends on RegistrarStorageUtil and UnifiedIdResolver

**Deploy Steps**:
1. Select `RegistrarStorageMother` contract
2. Deploy with **no constructor parameters** (uses initializer)
3. **Record address**: `MOTHER_ADDRESS = 0x...`

**Initialize**:
```javascript
// Initialize with required addresses
mother.initialize(
    "UTIL_ADDRESS",     // RegistrarStorageUtil address
    "RESOLVER_ADDRESS"  // UnifiedIdResolver address
);
```

**Post-Deployment Verification**:
```javascript
// Verify initialization
mother.owner(); // Should return your address
mother.util(); // Should return UTIL_ADDRESS
mother.resolver(); // Should return RESOLVER_ADDRESS
```

### 3.4 Deploy RegistrarStorageChildEvents (Fourth)

**Why Fourth**: Depends on RegistrarStorageUtil and UnifiedIdResolver

**Deploy Steps**:
1. Select `RegistrarStorageChildEvents` contract
2. Deploy with **no constructor parameters** (uses initializer)
3. **Record address**: `CHILD_ADDRESS = 0x...`

**Initialize**:
```javascript
// Initialize with required addresses and chain ID
child.initialize(
    "UTIL_ADDRESS",     // RegistrarStorageUtil address
    "RESOLVER_ADDRESS", // UnifiedIdResolver address
    CHAIN_ID           // Current chain ID (e.g., 1 for Ethereum mainnet)
);
```

**Post-Deployment Verification**:
```javascript
// Verify initialization
child.owner(); // Should return your address
child.util(); // Should return UTIL_ADDRESS
child.resolver(); // Should return RESOLVER_ADDRESS
child.chainId(); // Should return correct chain ID
```

## 🔗 Phase 4: Contract Relationship Configuration

### 4.1 Configure UnifiedIdResolver Authorizations

**Set Registry** (Allows MotherContract to manage authorizations):
```javascript
resolver.setRegistry("MOTHER_ADDRESS");
```

**Authorize Contracts** (Allow them to modify resolver records):
```javascript
// Authorize MotherContract
resolver.setAuthorization("MOTHER_ADDRESS", true);

// Authorize ChildContract  
resolver.setAuthorization("CHILD_ADDRESS", true);
```

**Verification**:
```javascript
resolver.getRegistry(); // Should return MOTHER_ADDRESS
resolver.isAuthorized("MOTHER_ADDRESS"); // Should return true
resolver.isAuthorized("CHILD_ADDRESS"); // Should return true
```

### 4.2 Configure Role-Based Access Control

**MotherContract Roles**:
```javascript
// Grant relayer role (for executing operations)
mother.grantRelayerRole("RELAYER_ADDRESS");

// Optional: Grant admin role to additional addresses
mother.grantAdminRole("ADMIN_ADDRESS");

// Verification
mother.isRelayer("RELAYER_ADDRESS"); // Should return true
mother.isAdmin("ADMIN_ADDRESS"); // Should return true
```

**ChildContract Roles**:
```javascript
// Grant relayer role
child.grantRelayerRole("RELAYER_ADDRESS");

// Grant registrar role (for initiating operations)
child.grantRegistrarRole("REGISTRAR_ADDRESS");

// Verification
child.isRelayer("RELAYER_ADDRESS"); // Should return true
child.isRegistrar("REGISTRAR_ADDRESS"); // Should return true
```

**UnifiedIdResolver Roles**:
```javascript
// Grant registry role to MotherContract (if not done automatically)
resolver.grantRegistryRole("MOTHER_ADDRESS");

// Verification
resolver.isRegistryRole("MOTHER_ADDRESS"); // Should return true
```

## 🧪 Phase 5: System Testing

### 5.1 Basic Functionality Test

**Test 1: Register Unified ID via MotherContract**
```javascript
// Using SignatureHelper.js for signature generation
const signatureHelper = new SignatureHelper("MOTHER_ADDRESS", CHAIN_ID);

// Test data
const testData = {
    unifiedId: "test.unified",
    chainId: 1,
    primaryAddress: "0x1234567890123456789012345678901234567890",
    masterAddress: "0x1234567890123456789012345678901234567890"
};

// Get current nonce
const nonce = await mother.getNonce(testData.unifiedId);

// Create deadline (1 hour from now)
const deadline = Math.floor(Date.now() / 1000) + 3600;

// Generate signatures (requires private keys)
const masterSigData = await signatureHelper.signRegisterUnifiedId(
    testData.unifiedId,
    testData.primaryAddress,
    nonce,
    deadline,
    masterSigner
);

const primarySigData = await signatureHelper.signRegisterUnifiedId(
    testData.unifiedId,
    testData.primaryAddress,
    nonce,
    deadline,
    primarySigner
);

// Register unified ID
await mother.registerUnifiedId(
    testData.unifiedId,
    testData.chainId,
    testData.primaryAddress,
    masterSigData,
    primarySigData
);
```

**Test 2: Verify Resolution**
```javascript
// Test resolution via resolver
const resolvedAddress = await resolver.getPrimaryAddress(testData.unifiedId, testData.chainId);
console.log("Resolved address:", resolvedAddress); // Should match primaryAddress

const resolvedUnifiedId = await resolver.getUnifiedIdFromAddress(testData.primaryAddress, testData.chainId);
console.log("Resolved UnifiedId:", resolvedUnifiedId); // Should match unifiedId
```

**Test 3: Add Secondary Address**
```javascript
const secondaryAddress = "0x9876543210987654321098765432109876543210";

// Generate signatures for adding secondary address
const addSecondarySigData = await signatureHelper.signAddSecondaryAddress(
    testData.unifiedId,
    secondaryAddress,
    nonce + 1,
    deadline,
    primarySigner
);

const secondarySigData = await signatureHelper.signAddSecondaryAddress(
    testData.unifiedId,
    secondaryAddress,
    nonce + 1,
    deadline,
    secondarySigner
);

// Add secondary address
await mother.addSecondaryAddress(
    testData.unifiedId,
    testData.chainId,
    secondaryAddress,
    addSecondarySigData,
    secondarySigData
);

// Verify
const addresses = await resolver.getAddresses(testData.unifiedId, testData.chainId);
console.log("Primary:", addresses.primary);
console.log("Secondaries:", addresses.secondaries);
```

### 5.2 Child Contract Testing

**Test 1: Register via Child Contract**
```javascript
// First register a registrar
await child.registerRegistrar("test.registrar", "REGISTRAR_ADDRESS");

// Initiate registration
await child.initiateRegisterUnifiedId(
    "child.test",
    "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdef",
    masterSignature,
    primarySignature,
    "0x" // options
);

// Complete registration (as relayer)
await child.completeRegisterUnifiedId(
    "child.test",
    "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdef",
    masterSignature,
    primarySignature,
    nonce,
    timestamp
);
```

### 5.3 Error Handling Tests

**Test Invalid Signatures**:
```javascript
// Should revert with "Invalid signature"
try {
    await mother.registerUnifiedId(
        "invalid.test",
        1,
        "0x1234567890123456789012345678901234567890",
        { nonce: 0, deadline: deadline, signature: "0x00" }, // Invalid signature
        { nonce: 0, deadline: deadline, signature: "0x00" }
    );
} catch (error) {
    console.log("Expected error:", error.message);
}
```

**Test Access Control**:
```javascript
// Should revert with access control error
try {
    await mother.connect(unauthorizedSigner).grantRelayerRole("0x1234567890123456789012345678901234567890");
} catch (error) {
    console.log("Expected access control error:", error.message);
}
```

## 🔐 Phase 6: Security Configuration

### 6.1 Ownership Transfer (Two-Step Process)

**Step 1: Initiate Transfer**
```javascript
// From current owner
await mother.transferOwnership("NEW_OWNER_ADDRESS");
await child.transferOwnership("NEW_OWNER_ADDRESS");
await resolver.transferOwnership("NEW_OWNER_ADDRESS");
await util.transferOwnership("NEW_OWNER_ADDRESS");

// Events emitted: OwnershipTransferStarted
```

**Step 2: Accept Ownership**
```javascript
// From new owner address
await mother.connect(newOwner).acceptOwnership();
await child.connect(newOwner).acceptOwnership();
await resolver.connect(newOwner).acceptOwnership();
await util.connect(newOwner).acceptOwnership();

// Events emitted: OwnershipTransferred
```

### 6.2 Emergency Procedures

**Pause Contracts**:
```javascript
// Pause operations (admin only)
await mother.pause();
await child.pauseRegistration();
```

**Emergency Mode**:
```javascript
// Enable emergency mode (emergency role only)
await mother.setEmergencyMode(true);
await child.setEmergencyMode(true);
```

**Emergency Functions**:
```javascript
// Mark UnifiedId as unavailable
await child.emergencyMarkUnavailable("problematic.id");

// Remove problematic registrar
await child.emergencyRemoveRegistrar("PROBLEMATIC_REGISTRAR_ADDRESS");
```

## 📊 Phase 7: Monitoring and Maintenance

### 7.1 Key Events to Monitor

**Registration Events**:
- `UnifiedIdRegistered` - New unified ID registered
- `UnifiedIdUpdated` - Unified ID updated
- `PrimaryAddressUpdated` - Primary address changed
- `SecondaryAddressAdded/Removed` - Secondary address changes

**Administrative Events**:
- `OwnershipTransferred` - Ownership changes
- `RelayerAuthorizationUpdated` - Relayer permissions
- `EmergencyModeToggled` - Emergency mode changes
- `ContractPaused/Unpaused` - Contract state changes

### 7.2 Regular Maintenance Tasks

**Weekly**:
- Monitor contract balances
- Check for failed transactions
- Verify relayer operations

**Monthly**:
- Review access control roles
- Update price feeds if needed
- Check contract upgrade needs

**Quarterly**:
- Security audit of operations
- Performance optimization review
- Backup critical data

## 🚨 Troubleshooting Guide

### Common Issues

**Issue 1: "Contract code size exceeds 24576 bytes"**
```
Solution:
- Ensure optimizer is enabled with runs: 200
- Verify libraries are properly linked
- Check if all optimizations are applied
```

**Issue 2: "Only owner or registry" Error**
```
Solution:
- Verify resolver.setRegistry() was called
- Check authorization with resolver.isAuthorized()
- Ensure proper role assignments
```

**Issue 3: "Invalid signature" Error**
```
Solution:
- Verify EIP-712 domain separator matches
- Check nonce is current
- Ensure deadline hasn't expired
- Verify signer has correct private key
```

**Issue 4: "AccessControl: caller is not admin"**
```
Solution:
- Check role assignments with hasRole()
- Verify DEFAULT_ADMIN_ROLE is properly set
- Use correct signer for admin functions
```

### Emergency Recovery

**Lost Owner Access**:
1. If pending owner exists, use `acceptOwnership()`
2. If no pending owner, ownership is permanently lost
3. Use emergency roles for critical operations

**Contract Upgrade Issues**:
1. Verify UPGRADER_ROLE is assigned
2. Check upgrade authorization
3. Use emergency pause if needed

## 📋 Final Deployment Checklist

### Pre-Production
- [ ] All contracts compiled successfully
- [ ] Contract sizes under 24KB limit
- [ ] All dependencies installed
- [ ] Network-specific addresses prepared

### Deployment
- [ ] RegistrarStorageUtil deployed and configured
- [ ] UnifiedIdResolver deployed and initialized
- [ ] MotherContract deployed and initialized
- [ ] RegistrarStorageChildEvents deployed and initialized

### Configuration
- [ ] Resolver authorizations configured
- [ ] Role-based access control set up
- [ ] Price feeds configured (if using payments)
- [ ] Chain ID properly set

### Testing
- [ ] Basic registration test passed
- [ ] Resolution test passed
- [ ] Secondary address test passed
- [ ] Access control test passed
- [ ] Error handling test passed

### Security
- [ ] Ownership transferred (if needed)
- [ ] Emergency procedures tested
- [ ] Monitoring set up
- [ ] Backup procedures established

### Production Ready
- [ ] All tests passed
- [ ] Documentation updated
- [ ] Team trained on operations
- [ ] Monitoring dashboard active

## 🎯 Network-Specific Deployment Addresses

### Ethereum Mainnet
```javascript
const config = {
    chainId: 1,
    ethUsdFeed: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
    gasPrice: "20000000000", // 20 gwei
    gasLimit: "8000000"
};
```

### Polygon Mainnet
```javascript
const config = {
    chainId: 137,
    ethUsdFeed: "0xF9680D99D6C9589e2a93a78A04A279e509205945",
    gasPrice: "30000000000", // 30 gwei
    gasLimit: "8000000"
};
```

### BSC Mainnet
```javascript
const config = {
    chainId: 56,
    ethUsdFeed: "0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e",
    gasPrice: "5000000000", // 5 gwei
    gasLimit: "8000000"
};
```

---

## 🎉 Congratulations!

Your Unified ID Management System is now deployed and ready for production use. The system provides:

- ✅ **Secure Multi-chain Identity Management**
- ✅ **Role-based Access Control**
- ✅ **Two-step Ownership Transfer**
- ✅ **EIP-712 Signature Security**
- ✅ **Gas-optimized Operations**
- ✅ **Emergency Response Capabilities**
- ✅ **Upgradeable Architecture**

For ongoing support and updates, monitor the contract events and maintain regular security practices.

**Happy Deploying! 🚀** 