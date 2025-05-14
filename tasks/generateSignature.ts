// tasks/generate-sigs.ts
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

/**
 * Hardhat Task: generate-sigs
 *
 * Generates ABI-encoded signatures for SafleID lifecycle functions:
 * - initiateRegisterSafleId
 * - initiateAddSecondaryAddress
 * - initiateRemoveSecondaryAddress
 * - initiateUpdateSafleId
 * - initiateUpdateSafleIdPrimaryAddress
 *
 * Usage:
 * npx hardhat generate-sigs --safleId <id> --newSafleId <newId> --network hardhat
 */
task('generate-sigs', 'Generate signatures for SafleID functions').setAction(
    async (taskArgs, hre: HardhatRuntimeEnvironment) => {
        // Destructure four signers from mnemonic-defined accounts
        const [master, primary, secondary, newPrimaryWallet] = await hre.ethers.getSigners()
        console.log('Master Address:', master.address)
        console.log('Primary Address:', primary.address)
        console.log('Secondary Address:', secondary.address)
        console.log('New Primary Wallet Address:', newPrimaryWallet.address)
        // Helper to ABI-encode data
        const encode = (types: string[], values: any[]) => hre.ethers.utils.defaultAbiCoder.encode(types, values)

        // Helper to hash and sign
        const sign = async (signer: any, types: string[], values: any[]) => {
            const data = encode(types, values)

            const hash = hre.ethers.utils.keccak256(data)
            return await signer.signMessage(hre.ethers.utils.arrayify(hash))
        }

        const safleId = 'v2test'
        const newSafleId = 'v2test2'
        const newPrimaryAddress = newPrimaryWallet.address
        const secAddress = secondary.address

        console.log('\n=== Generated Signatures for SafleID Operations ===\n')
        console.log('Data encode for initiateRegisterSafleId:')
        console.log('Encoded Data:', encode(['string', 'address'], [safleId, master.address]))
        // 1) initiateRegisterSafleId
        console.log(
            'initiateRegisterSafleId:',
            await sign(master, ['string', 'address', 'uint256'], [safleId, master.address, 0])
        )

        // 2) initiateAddSecondaryAddress
        console.log(
            'initiateAddSecondaryAddressSig1:',
            await sign(master, ['string', 'address'], [safleId, secAddress])
        )
        console.log(
            'initiateAddSecondaryAddressSig2:',
            await sign(secondary, ['string', 'address'], [safleId, secAddress])
        )

        // 4) initiateUpdateSafleId
        console.log('initiateUpdateSafleId:', await sign(master, ['string', 'address'], [newSafleId, master.address]))

        // 5) initiateUpdateSafleIdPrimaryAddress
        console.log(
            'initiateUpdateSafleIdPrimaryAddress (current primary):',
            await sign(master, ['string', 'address'], [newSafleId, newPrimaryAddress])
        )

        // Optionally: signature from new primary
        console.log(
            'initiateUpdateSafleIdPrimaryAddress (new primary):',
            await sign(newPrimaryWallet, ['string', 'address'], [newSafleId, newPrimaryAddress])
        )
        // 3) initiateRemoveSecondaryAddress
        console.log(
            'initiateRemoveSecondaryAddress:',
            await sign(newPrimaryWallet, ['string', 'address'], [newSafleId, secAddress])
        )

        console.log('\nDone. Copy these signatures into your tests or scripts.')
    }
)
