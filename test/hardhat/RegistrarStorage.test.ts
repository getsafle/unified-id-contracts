// test/RegistrarStorageCrossChainLive.test.ts

import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract } from 'ethers'
import { ethers } from 'hardhat'
import { Options } from '@layerzerolabs/lz-v2-utilities'
import { EndpointId } from '@layerzerolabs/lz-definitions'

// Replace with your actual deployed contract addresses
const REGISTRAR_STORAGE_ADDRESS = '0x9DFEE63A3b416326C797081C590cac1933C57D9E'

describe.only('RegistrarStorage Cross-Chain Tests (Live Deployments)', async () => {
    // Endpoint IDs for the testnets
    const eidSource = EndpointId.ZKPOLYGONSEP_V2_TESTNET // zkPolygon Sepolia
    const eidDestination = EndpointId.AMOY_V2_TESTNET // Amoy

    // Contract instances
    let registrarStorage: Contract

    // Signers
    let owner: SignerWithAddress
    let user: SignerWithAddress
    let wallet: SignerWithAddress

    before(async function () {
        // Get signers
        ;[owner, user, wallet] = await ethers.getSigners()

        // Connect to deployed RegistrarStorage on zkPolygon Sepolia
        const zkPolygonProvider = ethers.provider // Assumes network is zkPolygonSepolia
        registrarStorage = await ethers.getContractAt('RegistrarStorage', REGISTRAR_STORAGE_ADDRESS, user)

        // Connect to deployed VerificationContract on Amoy
    })
    it("should return the owner's address", async function () {
        console.log(owner.address)
    })

    it('Should Register a SafleID', async function () {
        const safleId = 'safleId1'
        const feeAmount = Number(ethers.utils.parseEther('0.002')) // Convert 1 ETH to wei

        // Step 1: Register the registrar (if needed)
        // Assuming this is handled elsewhere or not needed for this test

        // Step 2: Prepare the message to sign
        // const setWallet = await registrarStorage
        //     .connect(owner)
        //     .setMessagingContract('0x8e8DDfD011FF80dBde0b543DeD9D290e6D532dF1', {
        //         gasLimit: 300000, // Arbitrary starting value, adjust as needed
        //     })
        // setWallet.wait()
        const operation = 'registerSafleId'
        const message = ethers.utils.solidityKeccak256(
            ['string', 'string', 'address'], // Types
            [
                ethers.utils.hexlify(ethers.utils.toUtf8Bytes(operation)),
                ethers.utils.hexlify(ethers.utils.toUtf8Bytes(safleId)),
                owner.address,
            ] // Values
        )
        console.log(EndpointId.AMOY_V2_TESTNET)
        const signature = await owner.signMessage(ethers.utils.arrayify(message))
        console.log(signature)
        const tx = await registrarStorage.connect(owner).initiateRegisterSafleId(
            safleId,
            owner.address,
            signature,
            '0x0000000000000000000000000000000000000000', // Assuming this is a placeholder
            EndpointId.AMOY_V2_TESTNET,
            feeAmount,
            {
                gasLimit: 300000, // Arbitrary starting value, adjust as needed
            }
        )
        await tx.wait()
    })

    // beforeEach(async function () {
    //     // Ensure a SafleID exists for testing (assuming fees are 0 for simplicity)
    //     const safleIdExists = await registrarStorage.userAddresses('testSafleId').exists
    //     if (!safleIdExists) {
    //         await registrarStorage.connect(user).registerSafleId(
    //             'testSafleId',
    //             user.address,
    //             '0x', // Dummy signature
    //             ethers.constants.AddressZero, // Native ETH payment
    //             { value: ethers.utils.parseEther('0') }
    //         )
    //     }
    // })

    // it('should successfully add a secondary address via internal cross-chain verification', async function () {
    //     // Initial state check
    //     const initialSecondaryAddresses = await registrarStorage.getSecondaryAddresses('testSafleId')
    //     expect(initialSecondaryAddresses).to.be.empty

    //     // Prepare parameters for initiateAddSecondaryAddress
    //     const safleId = 'testSafleId'
    //     const secondaryAddress = wallet.address
    //     const primarySignature = '0xabcdef' // Dummy signature
    //     const secondarySignature = '0x123456' // Dummy signature
    //     const dstEid = eidDestination
    //     const options = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toBytes()

    //     // Send the initiate transaction
    //     const nativeFee = ethers.utils.parseEther('0.01') // Adjust based on actual network fees
    //     const tx = await registrarStorage
    //         .connect(user)
    //         .initiateAddSecondaryAddress(
    //             safleId,
    //             secondaryAddress,
    //             primarySignature,
    //             secondarySignature,
    //             dstEid,
    //             options,
    //             { value: nativeFee }
    //         )
    //     const receipt = await tx.wait()
    //     console.log(`Initiate transaction sent: ${receipt.transactionHash}`)

    //     // Since messaging happens internally, we assume VerificationContract responds with isValid = true
    //     console.log('Waiting for cross-chain verification to complete...')
    //     console.log(`Check LayerZero Scan: https://testnet.layerzeroscan.com/tx/${receipt.transactionHash}`)

    //     // Wait for the cross-chain process to complete (adjust delay as needed)
    //     await new Promise((resolve) => setTimeout(resolve, 60000)) // Wait 1 minute

    //     // Check final state
    //     const secondaryAddresses = await registrarStorage.getSecondaryAddresses('testSafleId')
    //     expect(secondaryAddresses).to.include(secondaryAddress)
    // })

    // it('should revert if insufficient funds are provided for messaging', async function () {
    //     // Initial state check
    //     const initialSecondaryAddresses = await registrarStorage.getSecondaryAddresses('testSafleId')
    //     expect(initialSecondaryAddresses).to.be.empty

    //     // Prepare parameters
    //     const safleId = 'testSafleId'
    //     const secondaryAddress = wallet.address
    //     const primarySignature = '0xabcdef'
    //     const secondarySignature = '0x123456'
    //     const dstEid = eidDestination
    //     const options = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toBytes()

    //     // Attempt with 0 ETH (insufficient for LayerZero messaging)
    //     await expect(
    //         registrarStorage
    //             .connect(user)
    //             .initiateAddSecondaryAddress(
    //                 safleId,
    //                 secondaryAddress,
    //                 primarySignature,
    //                 secondarySignature,
    //                 dstEid,
    //                 options,
    //                 { value: 0 }
    //             )
    //     ).to.be.reverted // Exact revert reason depends on LayerZero implementation

    //     // Check state remains unchanged
    //     const secondaryAddresses = await registrarStorage.getSecondaryAddresses('testSafleId')
    //     expect(secondaryAddresses).to.be.empty
    // })
})
