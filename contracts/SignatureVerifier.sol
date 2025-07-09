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
    
    /// @notice Register UnifiedID Type Hash - NOW INCLUDES TARGET CHAIN ID
    bytes32 public constant REGISTER_TYPEHASH = keccak256(
        "RegisterUnifiedId(string unifiedId,address primaryAddress,uint256 targetChainId,uint256 nonce,uint256 deadline)"
    );
    
    /// @notice Update UnifiedID Type Hash - NOW INCLUDES TARGET CHAIN ID
    bytes32 public constant UPDATE_UNIFIED_ID_TYPEHASH = keccak256(
        "UpdateUnifiedId(string oldUnifiedId,string newUnifiedId,uint256 targetChainId,uint256 nonce,uint256 deadline)"
    );
    
    /// @notice Update Primary Address Type Hash - NOW INCLUDES TARGET CHAIN ID
    bytes32 public constant UPDATE_PRIMARY_TYPEHASH = keccak256(
        "UpdatePrimaryAddress(string unifiedId,address newPrimaryAddress,uint256 targetChainId,uint256 nonce,uint256 deadline)"
    );
    
    /// @notice Add Secondary Address Type Hash - NOW INCLUDES TARGET CHAIN ID
    bytes32 public constant ADD_SECONDARY_TYPEHASH = keccak256(
        "AddSecondaryAddress(string unifiedId,address secondaryAddress,uint256 targetChainId,uint256 nonce,uint256 deadline)"
    );
    
    /// @notice Remove Secondary Address Type Hash - NOW INCLUDES TARGET CHAIN ID
    bytes32 public constant REMOVE_SECONDARY_TYPEHASH = keccak256(
        "RemoveSecondaryAddress(string unifiedId,address secondaryAddress,uint256 targetChainId,uint256 nonce,uint256 deadline)"
    );
    
    /// @notice Update Master Address Type Hash - NOW INCLUDES TARGET CHAIN ID
    bytes32 public constant UPDATE_MASTER_TYPEHASH = keccak256(
        "UpdateMasterAddress(string unifiedId,address newMasterAddress,uint256 targetChainId,uint256 nonce,uint256 deadline)"
    );
    
    // ==================== STRUCTS ====================
    
    /// @notice Standard signature data structure
    struct SignatureData {
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }
    
    /// @notice Enhanced signature data structure with target chain ID
    struct EnhancedSignatureData {
        uint256 nonce;
        uint256 deadline;
        uint256 targetChainId;
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
    error InvalidTargetChainId();
    
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
    
    /**
     * @notice Verifies EIP-712 signature with target chain ID validation
     * @param domainSeparator Domain separator for the contract
     * @param structHash Hash of the typed data struct
     * @param signer Expected signer address
     * @param sigData Enhanced signature data including target chain ID
     * @return True if signature is valid
     */
    function verifyEnhancedSignature(
        bytes32 domainSeparator,
        bytes32 structHash,
        address signer,
        EnhancedSignatureData memory sigData
    ) internal view returns (bool) {
        // Check deadline
        if (block.timestamp > sigData.deadline) revert SignatureExpired();
        
        // CRITICAL: Verify target chain ID matches current chain
        if (sigData.targetChainId != block.chainid) revert InvalidTargetChainId();
        
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
     * @notice Verifies signature for registering a UnifiedID with chain ID protection
     * @param domainSeparator Domain separator
     * @param unifiedId UnifiedID to register
     * @param primaryAddress Primary address for the UnifiedID
     * @param targetChainId Target chain ID for the registration
     * @param signer Expected signer address
     * @param sigData Enhanced signature data
     * @return True if signature is valid
     */
    function verifyRegisterSignature(
        bytes32 domainSeparator,
        string memory unifiedId,
        address primaryAddress,
        uint256 targetChainId,
        address signer,
        EnhancedSignatureData memory sigData
    ) internal view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            REGISTER_TYPEHASH,
            keccak256(bytes(unifiedId)),
            primaryAddress,
            targetChainId,
            sigData.nonce,
            sigData.deadline
        ));
        
        return verifyEnhancedSignature(domainSeparator, structHash, signer, sigData);
    }
    
    /**
     * @notice Verifies signature for updating a UnifiedID with chain ID protection
     * @param domainSeparator Domain separator
     * @param oldUnifiedId Current UnifiedID
     * @param newUnifiedId New UnifiedID
     * @param targetChainId Target chain ID for the update
     * @param signer Expected signer address
     * @param sigData Enhanced signature data
     * @return True if signature is valid
     */
    function verifyUpdateUnifiedIdSignature(
        bytes32 domainSeparator,
        string memory oldUnifiedId,
        string memory newUnifiedId,
        uint256 targetChainId,
        address signer,
        EnhancedSignatureData memory sigData
    ) internal view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            UPDATE_UNIFIED_ID_TYPEHASH,
            keccak256(bytes(oldUnifiedId)),
            keccak256(bytes(newUnifiedId)),
            targetChainId,
            sigData.nonce,
            sigData.deadline
        ));
        
        return verifyEnhancedSignature(domainSeparator, structHash, signer, sigData);
    }
    
    /**
     * @notice Verifies signature for updating primary address with chain ID protection
     * @param domainSeparator Domain separator
     * @param unifiedId UnifiedID
     * @param newPrimaryAddress New primary address
     * @param targetChainId Target chain ID for the update
     * @param signer Expected signer address
     * @param sigData Enhanced signature data
     * @return True if signature is valid
     */
    function verifyUpdatePrimarySignature(
        bytes32 domainSeparator,
        string memory unifiedId,
        address newPrimaryAddress,
        uint256 targetChainId,
        address signer,
        EnhancedSignatureData memory sigData
    ) internal view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            UPDATE_PRIMARY_TYPEHASH,
            keccak256(bytes(unifiedId)),
            newPrimaryAddress,
            targetChainId,
            sigData.nonce,
            sigData.deadline
        ));
        
        return verifyEnhancedSignature(domainSeparator, structHash, signer, sigData);
    }
    
    /**
     * @notice Verifies signature for adding secondary address with chain ID protection
     * @param domainSeparator Domain separator
     * @param unifiedId UnifiedID
     * @param secondaryAddress Secondary address to add
     * @param targetChainId Target chain ID for the operation
     * @param signer Expected signer address
     * @param sigData Enhanced signature data
     * @return True if signature is valid
     */
    function verifyAddSecondarySignature(
        bytes32 domainSeparator,
        string memory unifiedId,
        address secondaryAddress,
        uint256 targetChainId,
        address signer,
        EnhancedSignatureData memory sigData
    ) internal view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            ADD_SECONDARY_TYPEHASH,
            keccak256(bytes(unifiedId)),
            secondaryAddress,
            targetChainId,
            sigData.nonce,
            sigData.deadline
        ));
        
        return verifyEnhancedSignature(domainSeparator, structHash, signer, sigData);
    }
    
    /**
     * @notice Verifies signature for removing secondary address with chain ID protection
     * @param domainSeparator Domain separator
     * @param unifiedId UnifiedID
     * @param secondaryAddress Secondary address to remove
     * @param targetChainId Target chain ID for the operation
     * @param signer Expected signer address
     * @param sigData Enhanced signature data
     * @return True if signature is valid
     */
    function verifyRemoveSecondarySignature(
        bytes32 domainSeparator,
        string memory unifiedId,
        address secondaryAddress,
        uint256 targetChainId,
        address signer,
        EnhancedSignatureData memory sigData
    ) internal view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            REMOVE_SECONDARY_TYPEHASH,
            keccak256(bytes(unifiedId)),
            secondaryAddress,
            targetChainId,
            sigData.nonce,
            sigData.deadline
        ));
        
        return verifyEnhancedSignature(domainSeparator, structHash, signer, sigData);
    }
    
    /**
     * @notice Verifies signature for updating master address with chain ID protection
     * @param domainSeparator Domain separator
     * @param unifiedId UnifiedID
     * @param newMasterAddress New master address
     * @param targetChainId Target chain ID for the operation
     * @param signer Expected signer address
     * @param sigData Enhanced signature data
     * @return True if signature is valid
     */
    function verifyUpdateMasterSignature(
        bytes32 domainSeparator,
        string memory unifiedId,
        address newMasterAddress,
        uint256 targetChainId,
        address signer,
        EnhancedSignatureData memory sigData
    ) internal view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            UPDATE_MASTER_TYPEHASH,
            keccak256(bytes(unifiedId)),
            newMasterAddress,
            targetChainId,
            sigData.nonce,
            sigData.deadline
        ));
        
        return verifyEnhancedSignature(domainSeparator, structHash, signer, sigData);
    }
    
    // ==================== BACKWARD COMPATIBILITY ====================
    
    /**
     * @notice Legacy verification functions for backward compatibility
     * @dev These functions maintain the old behavior for existing integrations
     * @param domainSeparator Domain separator
     * @param unifiedId UnifiedID to register
     * @param primaryAddress Primary address for the UnifiedID
     * @param signer Expected signer address
     * @param sigData Legacy signature data
     * @return True if signature is valid
     */
    function verifyRegisterSignature(
        bytes32 domainSeparator,
        string memory unifiedId,
        address primaryAddress,
        address signer,
        SignatureData memory sigData
    ) internal view returns (bool) {
        // Convert to enhanced signature data with current chain ID
        EnhancedSignatureData memory enhancedSigData = EnhancedSignatureData({
            nonce: sigData.nonce,
            deadline: sigData.deadline,
            targetChainId: block.chainid,
            signature: sigData.signature
        });
        
        return verifyRegisterSignature(
            domainSeparator,
            unifiedId,
            primaryAddress,
            block.chainid,
            signer,
            enhancedSigData
        );
    }
    
    /**
     * @notice Legacy verification for updating UnifiedID
     */
    function verifyUpdateUnifiedIdSignature(
        bytes32 domainSeparator,
        string memory oldUnifiedId,
        string memory newUnifiedId,
        address signer,
        SignatureData memory sigData
    ) internal view returns (bool) {
        EnhancedSignatureData memory enhancedSigData = EnhancedSignatureData({
            nonce: sigData.nonce,
            deadline: sigData.deadline,
            targetChainId: block.chainid,
            signature: sigData.signature
        });
        
        return verifyUpdateUnifiedIdSignature(
            domainSeparator,
            oldUnifiedId,
            newUnifiedId,
            block.chainid,
            signer,
            enhancedSigData
        );
    }
    
    /**
     * @notice Legacy verification for updating primary address
     */
    function verifyUpdatePrimarySignature(
        bytes32 domainSeparator,
        string memory unifiedId,
        address newPrimaryAddress,
        address signer,
        SignatureData memory sigData
    ) internal view returns (bool) {
        EnhancedSignatureData memory enhancedSigData = EnhancedSignatureData({
            nonce: sigData.nonce,
            deadline: sigData.deadline,
            targetChainId: block.chainid,
            signature: sigData.signature
        });
        
        return verifyUpdatePrimarySignature(
            domainSeparator,
            unifiedId,
            newPrimaryAddress,
            block.chainid,
            signer,
            enhancedSigData
        );
    }
    
    /**
     * @notice Legacy verification for adding secondary address
     */
    function verifyAddSecondarySignature(
        bytes32 domainSeparator,
        string memory unifiedId,
        address secondaryAddress,
        address signer,
        SignatureData memory sigData
    ) internal view returns (bool) {
        EnhancedSignatureData memory enhancedSigData = EnhancedSignatureData({
            nonce: sigData.nonce,
            deadline: sigData.deadline,
            targetChainId: block.chainid,
            signature: sigData.signature
        });
        
        return verifyAddSecondarySignature(
            domainSeparator,
            unifiedId,
            secondaryAddress,
            block.chainid,
            signer,
            enhancedSigData
        );
    }
    
    /**
     * @notice Legacy verification for removing secondary address
     */
    function verifyRemoveSecondarySignature(
        bytes32 domainSeparator,
        string memory unifiedId,
        address secondaryAddress,
        address signer,
        SignatureData memory sigData
    ) internal view returns (bool) {
        EnhancedSignatureData memory enhancedSigData = EnhancedSignatureData({
            nonce: sigData.nonce,
            deadline: sigData.deadline,
            targetChainId: block.chainid,
            signature: sigData.signature
        });
        
        return verifyRemoveSecondarySignature(
            domainSeparator,
            unifiedId,
            secondaryAddress,
            block.chainid,
            signer,
            enhancedSigData
        );
    }
    
    /**
     * @notice Legacy verification for updating master address
     */
    function verifyUpdateMasterSignature(
        bytes32 domainSeparator,
        string memory unifiedId,
        address newMasterAddress,
        address signer,
        SignatureData memory sigData
    ) internal view returns (bool) {
        EnhancedSignatureData memory enhancedSigData = EnhancedSignatureData({
            nonce: sigData.nonce,
            deadline: sigData.deadline,
            targetChainId: block.chainid,
            signature: sigData.signature
        });
        
        return verifyUpdateMasterSignature(
            domainSeparator,
            unifiedId,
            newMasterAddress,
            block.chainid,
            signer,
            enhancedSigData
        );
    }
} 