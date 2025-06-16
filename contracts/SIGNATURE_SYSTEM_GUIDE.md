# UnifiedID Signature System Guide

## Overview

The UnifiedID contracts now use a **simplified, standardized signature verification system** that follows crypto industry best practices and EIP-712 standards. This guide explains how to generate and use signatures for all UnifiedID operations.

## Key Improvements

### ✅ **Before vs After**

| **Before (Complex)** | **After (Simplified)** |
|---------------------|------------------------|
| Multiple inconsistent verification methods | Single standardized `SignatureVerifier` library |
| Complex message construction with different formats | Clean EIP-712 typed data structures |
| Mixed legacy and secure verification | Pure EIP-712 implementation |
| Inconsistent domain separator usage | Standardized domain separator |
| Overly complex nonce management | Simple per-UnifiedID nonce system |

### ✅ **Benefits**

1. **Industry Standard**: Full EIP-712 compliance
2. **Simplified Integration**: Easy to use with MetaMask, WalletConnect, etc.
3. **Better Security**: Consistent signature verification across all operations
4. **Developer Friendly**: Clear, predictable signature generation
5. **Gas Efficient**: Optimized verification process

## Architecture

### Core Components

1. **`SignatureVerifier.sol`** - Library with all signature verification logic
2. **`MotherContract.sol`** - Updated to use the new signature system
3. **`SignatureHelper.js`** - JavaScript helper for frontend integration

### EIP-712 Domain

```javascript
{
    name: 'UnifiedID',
    version: '1',
    chainId: 1, // Your chain ID
    verifyingContract: '0x...' // Contract address
}
```

## Signature Types

### 1. Register UnifiedID

```javascript
RegisterUnifiedId: [
    { name: 'unifiedId', type: 'string' },
    { name: 'primaryAddress', type: 'address' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' }
]
```

### 2. Update UnifiedID

```javascript
UpdateUnifiedId: [
    { name: 'oldUnifiedId', type: 'string' },
    { name: 'newUnifiedId', type: 'string' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' }
]
```

### 3. Update Primary Address

```javascript
UpdatePrimaryAddress: [
    { name: 'unifiedId', type: 'string' },
    { name: 'newPrimaryAddress', type: 'address' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' }
]
```

### 4. Add Secondary Address

```javascript
AddSecondaryAddress: [
    { name: 'unifiedId', type: 'string' },
    { name: 'secondaryAddress', type: 'address' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' }
]
```

### 5. Remove Secondary Address

```javascript
RemoveSecondaryAddress: [
    { name: 'unifiedId', type: 'string' },
    { name: 'secondaryAddress', type: 'address' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' }
]
```

### 6. Update Master Address

```javascript
UpdateMasterAddress: [
    { name: 'unifiedId', type: 'string' },
    { name: 'newMasterAddress', type: 'address' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' }
]
```

## Usage Examples

### JavaScript/TypeScript Integration

```javascript
const { ethers } = require('ethers');
const SignatureHelper = require('./SignatureHelper');

// Initialize
const contractAddress = '0x...'; // Your deployed contract address
const chainId = 1; // Ethereum mainnet
const helper = new SignatureHelper(contractAddress, chainId);

// Setup provider and signer
const provider = new ethers.providers.JsonRpcProvider('...');
const wallet = new ethers.Wallet('your_private_key', provider);
const contract = new ethers.Contract(contractAddress, abi, wallet);

// Example 1: Register a new UnifiedID
async function registerUnifiedId() {
    try {
        const tx = await helper.registerUnifiedIdComplete(
            'myunifiedid',           // UnifiedID
            wallet.address,          // Primary address
            wallet,                  // Primary signer
            null,                    // No master signer (new UnifiedID)
            contract
        );
        console.log('Registration successful:', tx.hash);
    } catch (error) {
        console.error('Registration failed:', error);
    }
}

// Example 2: Add secondary address
async function addSecondaryAddress() {
    const secondaryWallet = new ethers.Wallet('secondary_private_key', provider);
    
    try {
        const tx = await helper.addSecondaryAddressComplete(
            'myunifiedid',           // UnifiedID
            secondaryWallet.address, // Secondary address
            wallet,                  // Primary signer
            secondaryWallet,         // Secondary signer
            contract
        );
        console.log('Secondary address added:', tx.hash);
    } catch (error) {
        console.error('Failed to add secondary:', error);
    }
}
```

### Manual Signature Generation

```javascript
// Get current nonce
const nonce = await contract.getNonce('myunifiedid');
const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

// Prepare typed data
const domain = {
    name: 'UnifiedID',
    version: '1',
    chainId: 1,
    verifyingContract: contractAddress
};

const types = {
    RegisterUnifiedId: [
        { name: 'unifiedId', type: 'string' },
        { name: 'primaryAddress', type: 'address' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' }
    ]
};

const value = {
    unifiedId: 'myunifiedid',
    primaryAddress: wallet.address,
    nonce: nonce,
    deadline: deadline
};

// Sign
const signature = await wallet._signTypedData(domain, types, value);

// Create signature data object
const sigData = {
    nonce: nonce,
    deadline: deadline,
    signature: signature
};

// Call contract
await contract.registerUnifiedId(
    'myunifiedid',
    1, // chainId
    wallet.address,
    { nonce: 0, deadline: 0, signature: '0x' }, // Empty master signature
    sigData
);
```

### React/Frontend Integration

```jsx
import { ethers } from 'ethers';
import SignatureHelper from './SignatureHelper';

function UnifiedIdManager() {
    const [contract, setContract] = useState(null);
    const [helper, setHelper] = useState(null);

    useEffect(() => {
        async function init() {
            if (window.ethereum) {
                const provider = new ethers.providers.Web3Provider(window.ethereum);
                const signer = provider.getSigner();
                const contractInstance = new ethers.Contract(CONTRACT_ADDRESS, ABI, signer);
                const helperInstance = new SignatureHelper(CONTRACT_ADDRESS, CHAIN_ID);
                
                setContract(contractInstance);
                setHelper(helperInstance);
            }
        }
        init();
    }, []);

    const registerUnifiedId = async (unifiedId) => {
        try {
            const signer = contract.signer;
            const tx = await helper.registerUnifiedIdComplete(
                unifiedId,
                await signer.getAddress(),
                signer,
                null,
                contract
            );
            
            console.log('Transaction sent:', tx.hash);
            await tx.wait();
            console.log('Registration confirmed!');
        } catch (error) {
            console.error('Registration failed:', error);
        }
    };

    return (
        <div>
            <button onClick={() => registerUnifiedId('myid')}>
                Register UnifiedID
            </button>
        </div>
    );
}
```

## Contract Functions

### Updated Function Signatures

All contract functions now use the `SignatureVerifier.SignatureData` struct:

```solidity
struct SignatureData {
    uint256 nonce;
    uint256 deadline;
    bytes signature;
}
```

### Function Examples

```solidity
// Register UnifiedID
function registerUnifiedId(
    string calldata unifiedId,
    uint256 chainId,
    address primary,
    SignatureVerifier.SignatureData calldata masterSigData,
    SignatureVerifier.SignatureData calldata primarySigData
) external;

// Update primary address
function updatePrimaryAddress(
    string calldata unifiedId,
    uint256 chainId,
    address newPrimary,
    SignatureVerifier.SignatureData calldata currentSigData,
    SignatureVerifier.SignatureData calldata newSigData
) external;

// Add secondary address
function addSecondaryAddress(
    string calldata unifiedId,
    uint256 chainId,
    address secondary,
    SignatureVerifier.SignatureData calldata primarySigData,
    SignatureVerifier.SignatureData calldata secondarySigData
) external;
```

## Security Features

### 1. **Deadline Protection**
- All signatures include a deadline timestamp
- Prevents replay attacks with old signatures
- Configurable expiration time (default: 1 hour)

### 2. **Nonce System**
- Each UnifiedID has its own nonce counter
- Prevents signature replay attacks
- Nonce increments with each successful operation

### 3. **EIP-712 Compliance**
- Structured data signing prevents signature malleability
- Domain separation prevents cross-contract attacks
- Chain ID prevents cross-chain replay attacks

### 4. **Address Verification**
- Signatures are verified against expected signers
- Multiple signature requirements for sensitive operations
- Clear error messages for debugging

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `SignatureExpired()` | Deadline has passed | Generate new signature with future deadline |
| `InvalidSignature()` | Wrong signer or malformed signature | Verify signer address and signature format |
| `InvalidNonce()` | Using wrong nonce | Get current nonce from contract |
| `InvalidSignatureLength()` | Signature not 65 bytes | Check signature generation process |

### Debugging Tips

1. **Check Nonce**: Always get current nonce from contract
2. **Verify Deadline**: Ensure deadline is in the future
3. **Confirm Signer**: Make sure the signing address matches expected signer
4. **Domain Separator**: Verify contract address and chain ID are correct
5. **Signature Format**: Ensure signature is properly formatted (65 bytes)

## Migration Guide

### From Old System

If you're migrating from the old signature system:

1. **Update Contract Calls**: Use new function signatures with `SignatureData` structs
2. **Replace Signature Generation**: Use EIP-712 typed data instead of message hashing
3. **Update Frontend**: Use the provided `SignatureHelper` class
4. **Test Thoroughly**: Verify all operations work with new signatures

### Example Migration

**Old Way:**
```javascript
// Complex message construction
const message = abi.encode(['string', 'address', 'uint256'], [unifiedId, primary, nonce]);
const hash = keccak256(message);
const signature = await wallet.signMessage(arrayify(hash));
```

**New Way:**
```javascript
// Simple EIP-712 signing
const sigData = await helper.signRegisterUnifiedId(unifiedId, primary, nonce, deadline, wallet);
```

## Best Practices

### 1. **Always Use Deadlines**
```javascript
// Good: 1 hour deadline
const deadline = Math.floor(Date.now() / 1000) + 3600;

// Bad: Very long deadline
const deadline = Math.floor(Date.now() / 1000) + 86400 * 365; // 1 year
```

### 2. **Handle Nonces Properly**
```javascript
// Always get current nonce
const nonce = await contract.getNonce(unifiedId);

// Don't hardcode or cache nonces
// const nonce = 0; // ❌ Wrong
```

### 3. **Verify Signatures Before Sending**
```javascript
// Optional: Verify signature locally before sending transaction
const isValid = await helper.verifySignatureLocally(sigData, expectedSigner);
if (!isValid) {
    throw new Error('Invalid signature generated');
}
```

### 4. **Use Helper Functions**
```javascript
// Use the provided helper for complete operations
await helper.registerUnifiedIdComplete(...);

// Instead of manually constructing everything
// const sigData = { nonce, deadline, signature }; // More error-prone
```

## Conclusion

The new signature system provides:

- ✅ **Simplified Integration**: Easy to use with standard tools
- ✅ **Enhanced Security**: Industry-standard EIP-712 implementation
- ✅ **Better Developer Experience**: Clear documentation and helper tools
- ✅ **Future-Proof**: Follows established crypto standards

The system is now ready for production use and should resolve all previous signature verification issues. The initialization problems you experienced should be completely resolved with this standardized approach. 