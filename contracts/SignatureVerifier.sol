// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

/**
 * @title SignatureVerifier
 * @notice Standardized signature verification library following EIP-712 and crypto industry best practices
 * @dev Implements clean, simple, and secure signature verification for all UnifiedID operations
 * @author kunalmkv
 */
library SignatureVerifier {
    
    // ==================== CONSTANTS ====================
    
    /// @notice EIP-712 Domain Separator Type Hash
    bytes32 public constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    
    /// @notice Register UnifiedID Type Hash
    bytes32 public constant REGISTER_TYPEHASH = keccak256(
        "RegisterUnifiedId(string unifiedId,address primaryAddress,uint256 nonce,uint256 deadline)"
    );
    
    /// @notice Update UnifiedID Type Hash
    bytes32 public constant UPDATE_UNIFIED_ID_TYPEHASH = keccak256(
        "UpdateUnifiedId(string oldUnifiedId,string newUnifiedId,uint256 nonce,uint256 deadline)"
    );
    
    /// @notice Update Primary Address Type Hash
    bytes32 public constant UPDATE_PRIMARY_TYPEHASH = keccak256(
        "UpdatePrimaryAddress(string unifiedId,address newPrimaryAddress,uint256 nonce,uint256 deadline)"
    );
    
    /// @notice Add Secondary Address Type Hash
    bytes32 public constant ADD_SECONDARY_TYPEHASH = keccak256(
        "AddSecondaryAddress(string unifiedId,address secondaryAddress,uint256 nonce,uint256 deadline)"
    );
    
    /// @notice Remove Secondary Address Type Hash
    bytes32 public constant REMOVE_SECONDARY_TYPEHASH = keccak256(
        "RemoveSecondaryAddress(string unifiedId,address secondaryAddress,uint256 nonce,uint256 deadline)"
    );
    
    /// @notice Update Master Address Type Hash
    bytes32 public constant UPDATE_MASTER_TYPEHASH = keccak256(
        "UpdateMasterAddress(string unifiedId,address newMasterAddress,uint256 nonce,uint256 deadline)"
    );
    
    // ==================== STRUCTS ====================
    
    /// @notice Standard signature data structure
    struct SignatureData {
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }
    
    /// @notice Domain separator parameters
    struct DomainData {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }
    
    // ==================== ERRORS ====================
    
    error SignatureExpired();
    error InvalidSignature();
    error InvalidSignatureLength();
    error InvalidNonce();
    
    // ==================== CORE FUNCTIONS ====================
    
    /**
     * @notice Creates EIP-712 domain separator
     * @param domain Domain data for the contract
     * @return Domain separator hash
     */
    function createDomainSeparator(DomainData memory domain) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            keccak256(bytes(domain.name)),
            keccak256(bytes(domain.version)),
            domain.chainId,
            domain.verifyingContract
        ));
    }
    
    /**
     * @notice Recovers signer address from signature
     * @param hash Message hash that was signed
     * @param signature Signature bytes (65 bytes)
     * @return Recovered signer address
     */
    function recoverSigner(bytes32 hash, bytes memory signature) internal pure returns (address) {
        if (signature.length != 65) revert InvalidSignatureLength();
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        if (v < 27) v += 27;
        if (v != 27 && v != 28) revert InvalidSignature();
        
        return ecrecover(hash, v, r, s);
    }
    
    /**
     * @notice Verifies EIP-712 signature
     * @param domainSeparator Domain separator for the contract
     * @param structHash Hash of the typed data struct
     * @param signer Expected signer address
     * @param sigData Signature data including deadline and signature
     * @return True if signature is valid
     */
    function verifySignature(
        bytes32 domainSeparator,
        bytes32 structHash,
        address signer,
        SignatureData memory sigData
    ) internal view returns (bool) {
        // Check deadline
        if (block.timestamp > sigData.deadline) revert SignatureExpired();
        
        // Create EIP-712 digest
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));
        
        // Recover and verify signer
        address recoveredSigner = recoverSigner(digest, sigData.signature);
        return recoveredSigner == signer;
    }
    
    // ==================== OPERATION-SPECIFIC VERIFICATION ====================
    
    /**
     * @notice Verifies signature for registering a UnifiedID
     * @param domainSeparator Domain separator
     * @param unifiedId UnifiedID to register
     * @param primaryAddress Primary address for the UnifiedID
     * @param signer Expected signer address
     * @param sigData Signature data
     * @return True if signature is valid
     */
    function verifyRegisterSignature(
        bytes32 domainSeparator,
        string memory unifiedId,
        address primaryAddress,
        address signer,
        SignatureData memory sigData
    ) internal view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            REGISTER_TYPEHASH,
            keccak256(bytes(unifiedId)),
            primaryAddress,
            sigData.nonce,
            sigData.deadline
        ));
        
        return verifySignature(domainSeparator, structHash, signer, sigData);
    }
    
    /**
     * @notice Verifies signature for updating a UnifiedID
     * @param domainSeparator Domain separator
     * @param oldUnifiedId Current UnifiedID
     * @param newUnifiedId New UnifiedID
     * @param signer Expected signer address
     * @param sigData Signature data
     * @return True if signature is valid
     */
    function verifyUpdateUnifiedIdSignature(
        bytes32 domainSeparator,
        string memory oldUnifiedId,
        string memory newUnifiedId,
        address signer,
        SignatureData memory sigData
    ) internal view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            UPDATE_UNIFIED_ID_TYPEHASH,
            keccak256(bytes(oldUnifiedId)),
            keccak256(bytes(newUnifiedId)),
            sigData.nonce,
            sigData.deadline
        ));
        
        return verifySignature(domainSeparator, structHash, signer, sigData);
    }
    
    /**
     * @notice Verifies signature for updating primary address
     * @param domainSeparator Domain separator
     * @param unifiedId UnifiedID
     * @param newPrimaryAddress New primary address
     * @param signer Expected signer address
     * @param sigData Signature data
     * @return True if signature is valid
     */
    function verifyUpdatePrimarySignature(
        bytes32 domainSeparator,
        string memory unifiedId,
        address newPrimaryAddress,
        address signer,
        SignatureData memory sigData
    ) internal view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            UPDATE_PRIMARY_TYPEHASH,
            keccak256(bytes(unifiedId)),
            newPrimaryAddress,
            sigData.nonce,
            sigData.deadline
        ));
        
        return verifySignature(domainSeparator, structHash, signer, sigData);
    }
    
    /**
     * @notice Verifies signature for adding secondary address
     * @param domainSeparator Domain separator
     * @param unifiedId UnifiedID
     * @param secondaryAddress Secondary address to add
     * @param signer Expected signer address
     * @param sigData Signature data
     * @return True if signature is valid
     */
    function verifyAddSecondarySignature(
        bytes32 domainSeparator,
        string memory unifiedId,
        address secondaryAddress,
        address signer,
        SignatureData memory sigData
    ) internal view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            ADD_SECONDARY_TYPEHASH,
            keccak256(bytes(unifiedId)),
            secondaryAddress,
            sigData.nonce,
            sigData.deadline
        ));
        
        return verifySignature(domainSeparator, structHash, signer, sigData);
    }
    
    /**
     * @notice Verifies signature for removing secondary address
     * @param domainSeparator Domain separator
     * @param unifiedId UnifiedID
     * @param secondaryAddress Secondary address to remove
     * @param signer Expected signer address
     * @param sigData Signature data
     * @return True if signature is valid
     */
    function verifyRemoveSecondarySignature(
        bytes32 domainSeparator,
        string memory unifiedId,
        address secondaryAddress,
        address signer,
        SignatureData memory sigData
    ) internal view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            REMOVE_SECONDARY_TYPEHASH,
            keccak256(bytes(unifiedId)),
            secondaryAddress,
            sigData.nonce,
            sigData.deadline
        ));
        
        return verifySignature(domainSeparator, structHash, signer, sigData);
    }
    
    /**
     * @notice Verifies signature for updating master address
     * @param domainSeparator Domain separator
     * @param unifiedId UnifiedID
     * @param newMasterAddress New master address
     * @param signer Expected signer address
     * @param sigData Signature data
     * @return True if signature is valid
     */
    function verifyUpdateMasterSignature(
        bytes32 domainSeparator,
        string memory unifiedId,
        address newMasterAddress,
        address signer,
        SignatureData memory sigData
    ) internal view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            UPDATE_MASTER_TYPEHASH,
            keccak256(bytes(unifiedId)),
            newMasterAddress,
            sigData.nonce,
            sigData.deadline
        ));
        
        return verifySignature(domainSeparator, structHash, signer, sigData);
    }
} 