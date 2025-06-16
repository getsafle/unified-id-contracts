# Unified ID Management System

A comprehensive smart contract system for managing unified identities across multiple blockchain networks with cross-chain address resolution and secondary address support.

## 📋 Overview

The Unified ID Management System consists of 5 core smart contracts that work together to provide:
- **Cross-chain unified identity management**
- **Primary and secondary address mapping**
- **Signature-based authorization**
- **Event-driven architecture**
- **Resolver pattern for address resolution**

## 🏗️ Contract Architecture

### Core Contracts

1. **IUnifiedIdResolver.sol** - Interface defining resolver functionality
2. **RegistrarStorageUtil.sol** - Utility functions for signature verification and validation
3. **UnifiedIdResolver.sol** - Address resolution engine with multi-chain support
4. **MotherContract.sol** - Cross-chain unified ID management hub
5. **RegistrarStorageChildEvents.sol** - Single-chain operations with event-driven architecture

### Supporting Libraries

6. **MotherContractLib.sol** - Library with common functions to reduce contract size

## 🔧 Dependencies

- **Solidity**: ^0.8.25
- **OpenZeppelin Contracts Upgradeable**: ^4.9.0
- **OpenZeppelin Contracts**: ^4.9.0

## 📦 Step-by-Step Deployment Guide for Remix IDE

### Phase 1: Setup and Preparation

#### 1.1 Setup Remix Environment
1. Open [Remix IDE](https://remix.ethereum.org)
2. Create a new workspace: `File → New Workspace → Blank`
3. Name it: `unified-id-contracts`

#### 1.2 Upload Contract Files
1. In the file explorer, create a `contracts` folder
2. Upload all contract files in this order:
   - `IUnifiedIdResolver.sol`
   - `RegistrarStorageUtil.sol`
   - `UnifiedIdResolver.sol`
   - `MotherContract.sol`
   - `RegistrarStorageChildEvents.sol`

#### 1.3 Install Dependencies
1. Go to `File Explorer → .deps folder`
2. Install OpenZeppelin contracts:
   - Go to `Settings → Libraries`
   - Add: `@openzeppelin/contracts@4.9.0`
   - Add: `@openzeppelin/contracts-upgradeable@4.9.0`

### Phase 2: Compilation

#### 2.1 Set Compiler Version
1. Go to `Solidity Compiler` tab
2. Set compiler version to `0.8.25`
3. Enable optimization: `runs: 200` (to reduce contract size)
4. Click `Compile All`

#### 2.2 Verify Compilation
- All contracts should compile without errors
- Check for any warnings and resolve if necessary
- Pay attention to contract sizes (should be under 24KB)

### Phase 3: Deployment Sequence

> ⚠️ **Important**: Deploy in this exact order as contracts depend on each other

#### 3.1 Deploy RegistrarStorageUtil (First)

**Deploy:**
1. Go to `Deploy & Run` tab
2. Select `RegistrarStorageUtil` contract
3. Click `Deploy` (no constructor parameters needed)

**Record the address:** `UTIL_ADDRESS = 0x...`

#### 3.2 Deploy UnifiedIdResolver (Second)

**Deploy:**
1. Select `UnifiedIdResolver` contract
2. **Constructor parameters:**
   - `_registry`: Use `0x0000000000000000000000000000000000000000` (will be set later)
3. Click `Deploy`

**Record the address:** `RESOLVER_ADDRESS = 0x...`

**Post-deployment setup:**
```javascript
// Call these functions on the deployed UnifiedIdResolver
// 1. Check owner (should be your deployment address)
getOwner() // Returns: 0x... (your address)

// 2. Get registry (should be zero address initially)
getRegistry() // Returns: 0x0000000000000000000000000000000000000000
```

#### 3.3 Deploy MotherContract (Third) 

**Deploy:**
1. Select `RegistrarStorageMother` contract (MotherContract)
2. Click `Deploy` (no constructor - uses initializer)

**Record the address:** `MOTHER_ADDRESS = 0x...`

**Post-deployment setup:**
```javascript
// Initialize the MotherContract
initialize(
    "UTIL_ADDRESS",      // _util: RegistrarStorageUtil address
    "PROXY_RESOLVER_ADDRESS"   // _resolver: UnifiedIdResolver address
)

// Set up relayer authorization
setAuthorizedRelayer("YOUR_RELAYER_ADDRESS", true)
```

#### 3.4 Deploy RegistrarStorageChildEvents (Fourth)

**Deploy:**
1. Select `RegistrarStorageChildEvents` contract
2. Click `Deploy` (no constructor - uses initializer)

**Record the address:** `CHILD_ADDRESS = 0x...`

**Post-deployment setup:**
```javascript
// Initialize the ChildContract
initialize(
    "UTIL_ADDRESS",      // _util: RegistrarStorageUtil address
    "PROXY_RESOLVER_ADDRESS"   // _resolver: UnifiedIdResolver address
)

// Set up relayer authorization
setAuthorizedRelayer("YOUR_RELAYER_ADDRESS", true)
```

### Phase 4: Configure Contract Relationships

#### 4.1 Configure UnifiedIdResolver Authorization

**From UnifiedIdResolver contract:**
```javascript
// 1. Set MotherContract as registry (allows it to set authorizations)
setRegistry("MOTHER_ADDRESS")

// 2. Authorize MotherContract to manage records
setAuthorization("MOTHER_ADDRESS", true)

// 3. Authorize ChildContract to manage records
setAuthorization("CHILD_ADDRESS", true)

// 4. Verify authorizations
isAuthorized("MOTHER_ADDRESS")  // Should return: true
isAuthorized("CHILD_ADDRESS")   // Should return: true
```

#### 4.2 Verify Configuration

**Debug functions to verify setup:**
```javascript
// From UnifiedIdResolver
getOwner()       // Your deployment address
getRegistry()    // Should be MOTHER_ADDRESS
canSetAuthorization("YOUR_ADDRESS")  // Should be true (as owner)

// From MotherContract
authorizedRelayers("YOUR_RELAYER_ADDRESS")  // Should be true

// From ChildContract  
authorizedRelayers("YOUR_RELAYER_ADDRESS")  // Should be true
```

## 🧪 Testing Scenarios

### Test Case 1: Register Unified ID via MotherContract

```javascript
// Prepare test data
const testData = {
    unifiedId: "test.unified",
    chainId: 1,
    primaryAddress: "0x1234567890123456789012345678901234567890",
    masterAddress: "0x1234567890123456789012345678901234567890"
}

// Create signature data (for testing, use dummy signatures)
const data = web3.eth.abi.encodeParameters(
    ['string', 'address'], 
    [testData.unifiedId, testData.primaryAddress]
)

// Call registerUnifiedId
registerUnifiedId(
    testData.unifiedId,
    testData.chainId, 
    testData.primaryAddress,
    data,
    "0x00", // masterSignature (dummy for testing)
    "0x00"  // primarySignature (dummy for testing)
)
```

### Test Case 2: Resolve Address via UnifiedIdResolver

```javascript
// Test resolution
getPrimaryAddress("test.unified", 1)  // Should return: primaryAddress
getUnifiedIdFromAddress("0x1234...", 1)  // Should return: "test.unified"
```

### Test Case 3: Add Secondary Address

```javascript
// Add secondary address via MotherContract
addSecondaryAddress(
    "test.unified",
    1,
    "0x9876543210987654321098765432109876543210",
    data,
    "0x00", // primarySignature
    "0x00"  // secondarySignature
)

// Verify via resolver
getAddresses("test.unified", 1)  // Returns: [primary, [secondary1, secondary2...]]
```

## 🔍 Common Issues and Troubleshooting

### Issue 1: "Only owner or registry" Error
**Problem:** Calling setAuthorization from wrong account
**Solution:** 
- Call from contract owner OR
- Set registry first: `setRegistry(authorized_address)`

### Issue 2: "Contract code size exceeds 24576 bytes"
**Problem:** Contract too large for deployment
**Solution:**
- Enable optimizer with runs: 200
- Use MotherContractLib.sol library (already implemented)

### Issue 3: "Invalid signature" Error
**Problem:** Signature verification failing
**Solution:**
- Use proper signature format
- Ensure nonce is correct
- For testing, you can temporarily modify verification logic

### Issue 4: "Stack too deep" Compilation Error
**Problem:** Too many local variables
**Solution:** 
- Already fixed with internal helper functions
- If it reoccurs, break down functions further

## 📊 Contract Sizes

After optimization (runs: 200):
- RegistrarStorageUtil: ~10KB
- UnifiedIdResolver: ~17KB  
- MotherContract: ~18KB (reduced from 26KB with library)
- RegistrarStorageChildEvents: ~24KB
- MotherContractLib: ~4.5KB

## 🔐 Security Considerations

1. **Signature Verification**: All state changes require valid signatures
2. **Access Control**: Owner/registry pattern for authorization
3. **Pausable**: Contracts can be paused in emergencies
4. **Upgradeable**: UUPS proxy pattern for future updates
5. **Reentrancy Protection**: Built-in via OpenZeppelin patterns

## 📚 API Reference

### MotherContract Key Functions
- `registerUnifiedId()` - Register new unified ID with cross-chain support
- `updatePrimaryAddress()` - Update primary address for a chain
- `addSecondaryAddress()` - Add secondary address
- `updateUnifiedId()` - Transfer unified ID to new identifier

### UnifiedIdResolver Key Functions
- `addr()` - Get address for unified ID (backward compatible)
- `getPrimaryAddress()` - Get primary address for specific chain
- `getAddresses()` - Get all addresses for unified ID on chain
- `setAuthorization()` - Authorize contracts to manage records

### ChildContract Key Functions
- `registerUnifiedIdOnChain()` - Register unified ID on single chain
- `updatePrimaryAddressOnChain()` - Update primary for single chain
- `addSecondaryAddressOnChain()` - Add secondary on single chain

## 🚀 Deployment Checklist

- [ ] All contracts compiled successfully
- [ ] RegistrarStorageUtil deployed
- [ ] UnifiedIdResolver deployed and initialized
- [ ] MotherContract deployed and initialized
- [ ] ChildContract deployed and initialized  
- [ ] UnifiedIdResolver authorizations configured
- [ ] Relayer addresses authorized
- [ ] Test registration completed
- [ ] Address resolution verified
- [ ] Secondary addresses working

## 📝 License

MIT License - see LICENSE file for details

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

---

**Happy Deploying! 🎉**

For issues or questions, please create an issue in the repository. 