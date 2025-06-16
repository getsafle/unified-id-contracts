/**
 * @title SignatureHelper
 * @notice JavaScript/TypeScript helper for generating EIP-712 signatures for UnifiedID operations
 * @dev Works with the simplified SignatureVerifier library
 */

const { ethers } = require('ethers');

class SignatureHelper {
    constructor(contractAddress, chainId = 1) {
        this.contractAddress = contractAddress;
        this.chainId = chainId;
        
        // EIP-712 Domain
        this.domain = {
            name: 'UnifiedID',
            version: '1',
            chainId: this.chainId,
            verifyingContract: this.contractAddress
        };
        
        // EIP-712 Types
        this.types = {
            RegisterUnifiedId: [
                { name: 'unifiedId', type: 'string' },
                { name: 'primaryAddress', type: 'address' },
                { name: 'nonce', type: 'uint256' },
                { name: 'deadline', type: 'uint256' }
            ],
            UpdateUnifiedId: [
                { name: 'oldUnifiedId', type: 'string' },
                { name: 'newUnifiedId', type: 'string' },
                { name: 'nonce', type: 'uint256' },
                { name: 'deadline', type: 'uint256' }
            ],
            UpdatePrimaryAddress: [
                { name: 'unifiedId', type: 'string' },
                { name: 'newPrimaryAddress', type: 'address' },
                { name: 'nonce', type: 'uint256' },
                { name: 'deadline', type: 'uint256' }
            ],
            AddSecondaryAddress: [
                { name: 'unifiedId', type: 'string' },
                { name: 'secondaryAddress', type: 'address' },
                { name: 'nonce', type: 'uint256' },
                { name: 'deadline', type: 'uint256' }
            ],
            RemoveSecondaryAddress: [
                { name: 'unifiedId', type: 'string' },
                { name: 'secondaryAddress', type: 'address' },
                { name: 'nonce', type: 'uint256' },
                { name: 'deadline', type: 'uint256' }
            ],
            UpdateMasterAddress: [
                { name: 'unifiedId', type: 'string' },
                { name: 'newMasterAddress', type: 'address' },
                { name: 'nonce', type: 'uint256' },
                { name: 'deadline', type: 'uint256' }
            ]
        };
    }

    /**
     * Creates a deadline timestamp (current time + hours)
     * @param {number} hours - Hours from now
     * @returns {number} Unix timestamp
     */
    createDeadline(hours = 1) {
        return Math.floor(Date.now() / 1000) + (hours * 3600);
    }

    /**
     * Signs a register UnifiedID operation
     * @param {string} unifiedId - UnifiedID to register
     * @param {string} primaryAddress - Primary address
     * @param {number} nonce - Current nonce
     * @param {number} deadline - Deadline timestamp
     * @param {ethers.Signer} signer - Ethereum signer
     * @returns {Promise<Object>} Signature data object
     */
    async signRegisterUnifiedId(unifiedId, primaryAddress, nonce, deadline, signer) {
        const value = {
            unifiedId,
            primaryAddress,
            nonce,
            deadline
        };

        const signature = await signer._signTypedData(this.domain, { RegisterUnifiedId: this.types.RegisterUnifiedId }, value);
        
        return {
            nonce,
            deadline,
            signature
        };
    }

    /**
     * Signs an update UnifiedID operation
     * @param {string} oldUnifiedId - Current UnifiedID
     * @param {string} newUnifiedId - New UnifiedID
     * @param {number} nonce - Current nonce
     * @param {number} deadline - Deadline timestamp
     * @param {ethers.Signer} signer - Ethereum signer
     * @returns {Promise<Object>} Signature data object
     */
    async signUpdateUnifiedId(oldUnifiedId, newUnifiedId, nonce, deadline, signer) {
        const value = {
            oldUnifiedId,
            newUnifiedId,
            nonce,
            deadline
        };

        const signature = await signer._signTypedData(this.domain, { UpdateUnifiedId: this.types.UpdateUnifiedId }, value);
        
        return {
            nonce,
            deadline,
            signature
        };
    }

    /**
     * Signs an update primary address operation
     * @param {string} unifiedId - UnifiedID
     * @param {string} newPrimaryAddress - New primary address
     * @param {number} nonce - Current nonce
     * @param {number} deadline - Deadline timestamp
     * @param {ethers.Signer} signer - Ethereum signer
     * @returns {Promise<Object>} Signature data object
     */
    async signUpdatePrimaryAddress(unifiedId, newPrimaryAddress, nonce, deadline, signer) {
        const value = {
            unifiedId,
            newPrimaryAddress,
            nonce,
            deadline
        };

        const signature = await signer._signTypedData(this.domain, { UpdatePrimaryAddress: this.types.UpdatePrimaryAddress }, value);
        
        return {
            nonce,
            deadline,
            signature
        };
    }

    /**
     * Signs an add secondary address operation
     * @param {string} unifiedId - UnifiedID
     * @param {string} secondaryAddress - Secondary address to add
     * @param {number} nonce - Current nonce
     * @param {number} deadline - Deadline timestamp
     * @param {ethers.Signer} signer - Ethereum signer
     * @returns {Promise<Object>} Signature data object
     */
    async signAddSecondaryAddress(unifiedId, secondaryAddress, nonce, deadline, signer) {
        const value = {
            unifiedId,
            secondaryAddress,
            nonce,
            deadline
        };

        const signature = await signer._signTypedData(this.domain, { AddSecondaryAddress: this.types.AddSecondaryAddress }, value);
        
        return {
            nonce,
            deadline,
            signature
        };
    }

    /**
     * Signs a remove secondary address operation
     * @param {string} unifiedId - UnifiedID
     * @param {string} secondaryAddress - Secondary address to remove
     * @param {number} nonce - Current nonce
     * @param {number} deadline - Deadline timestamp
     * @param {ethers.Signer} signer - Ethereum signer
     * @returns {Promise<Object>} Signature data object
     */
    async signRemoveSecondaryAddress(unifiedId, secondaryAddress, nonce, deadline, signer) {
        const value = {
            unifiedId,
            secondaryAddress,
            nonce,
            deadline
        };

        const signature = await signer._signTypedData(this.domain, { RemoveSecondaryAddress: this.types.RemoveSecondaryAddress }, value);
        
        return {
            nonce,
            deadline,
            signature
        };
    }

    /**
     * Signs an update master address operation
     * @param {string} unifiedId - UnifiedID
     * @param {string} newMasterAddress - New master address
     * @param {number} nonce - Current nonce
     * @param {number} deadline - Deadline timestamp
     * @param {ethers.Signer} signer - Ethereum signer
     * @returns {Promise<Object>} Signature data object
     */
    async signUpdateMasterAddress(unifiedId, newMasterAddress, nonce, deadline, signer) {
        const value = {
            unifiedId,
            newMasterAddress,
            nonce,
            deadline
        };

        const signature = await signer._signTypedData(this.domain, { UpdateMasterAddress: this.types.UpdateMasterAddress }, value);
        
        return {
            nonce,
            deadline,
            signature
        };
    }

    /**
     * Complete example: Register a new UnifiedID
     * @param {string} unifiedId - UnifiedID to register
     * @param {string} primaryAddress - Primary address
     * @param {ethers.Signer} primarySigner - Primary address signer
     * @param {ethers.Signer} masterSigner - Master signer (optional, for existing UnifiedIDs)
     * @param {Object} contract - Contract instance
     * @returns {Promise<Object>} Transaction result
     */
    async registerUnifiedIdComplete(unifiedId, primaryAddress, primarySigner, masterSigner = null, contract) {
        // Get current nonce
        const nonce = await contract.getNonce(unifiedId);
        const deadline = this.createDeadline(1); // 1 hour deadline

        // Sign with primary address
        const primarySigData = await this.signRegisterUnifiedId(
            unifiedId,
            primaryAddress,
            nonce,
            deadline,
            primarySigner
        );

        // Sign with master address if provided (for existing UnifiedIDs)
        let masterSigData = {
            nonce: 0,
            deadline: 0,
            signature: '0x'
        };

        if (masterSigner) {
            masterSigData = await this.signRegisterUnifiedId(
                unifiedId,
                primaryAddress,
                nonce,
                deadline,
                masterSigner
            );
        }

        // Call contract
        return await contract.registerUnifiedId(
            unifiedId,
            this.chainId,
            primaryAddress,
            masterSigData,
            primarySigData
        );
    }

    /**
     * Complete example: Update primary address
     * @param {string} unifiedId - UnifiedID
     * @param {string} newPrimaryAddress - New primary address
     * @param {ethers.Signer} currentPrimarySigner - Current primary signer
     * @param {ethers.Signer} newPrimarySigner - New primary signer
     * @param {Object} contract - Contract instance
     * @returns {Promise<Object>} Transaction result
     */
    async updatePrimaryAddressComplete(unifiedId, newPrimaryAddress, currentPrimarySigner, newPrimarySigner, contract) {
        // Get current nonce
        const nonce = await contract.getNonce(unifiedId);
        const deadline = this.createDeadline(1);

        // Sign with current primary
        const currentSigData = await this.signUpdatePrimaryAddress(
            unifiedId,
            newPrimaryAddress,
            nonce,
            deadline,
            currentPrimarySigner
        );

        // Sign with new primary
        const newSigData = await this.signUpdatePrimaryAddress(
            unifiedId,
            newPrimaryAddress,
            nonce,
            deadline,
            newPrimarySigner
        );

        // Call contract
        return await contract.updatePrimaryAddress(
            unifiedId,
            this.chainId,
            newPrimaryAddress,
            currentSigData,
            newSigData
        );
    }

    /**
     * Complete example: Add secondary address
     * @param {string} unifiedId - UnifiedID
     * @param {string} secondaryAddress - Secondary address to add
     * @param {ethers.Signer} primarySigner - Primary signer
     * @param {ethers.Signer} secondarySigner - Secondary signer
     * @param {Object} contract - Contract instance
     * @returns {Promise<Object>} Transaction result
     */
    async addSecondaryAddressComplete(unifiedId, secondaryAddress, primarySigner, secondarySigner, contract) {
        // Get current nonce
        const nonce = await contract.getNonce(unifiedId);
        const deadline = this.createDeadline(1);

        // Sign with primary
        const primarySigData = await this.signAddSecondaryAddress(
            unifiedId,
            secondaryAddress,
            nonce,
            deadline,
            primarySigner
        );

        // Sign with secondary
        const secondarySigData = await this.signAddSecondaryAddress(
            unifiedId,
            secondaryAddress,
            nonce,
            deadline,
            secondarySigner
        );

        // Call contract
        return await contract.addSecondaryAddress(
            unifiedId,
            this.chainId,
            secondaryAddress,
            primarySigData,
            secondarySigData
        );
    }
}

// Usage example:
/*
const { ethers } = require('ethers');

// Initialize
const contractAddress = '0x...'; // Your deployed contract address
const chainId = 1; // Ethereum mainnet
const helper = new SignatureHelper(contractAddress, chainId);

// Setup signers
const provider = new ethers.providers.JsonRpcProvider('...');
const primaryWallet = new ethers.Wallet('private_key', provider);
const secondaryWallet = new ethers.Wallet('private_key_2', provider);

// Get contract instance
const contract = new ethers.Contract(contractAddress, abi, primaryWallet);

// Register a new UnifiedID
async function registerExample() {
    try {
        const tx = await helper.registerUnifiedIdComplete(
            'myunifiedid',
            primaryWallet.address,
            primaryWallet,
            null, // No master signer for new UnifiedID
            contract
        );
        console.log('Registration successful:', tx.hash);
    } catch (error) {
        console.error('Registration failed:', error);
    }
}

// Add secondary address
async function addSecondaryExample() {
    try {
        const tx = await helper.addSecondaryAddressComplete(
            'myunifiedid',
            secondaryWallet.address,
            primaryWallet,
            secondaryWallet,
            contract
        );
        console.log('Secondary address added:', tx.hash);
    } catch (error) {
        console.error('Failed to add secondary:', error);
    }
}
*/

module.exports = SignatureHelper; 