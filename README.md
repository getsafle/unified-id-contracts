Here’s a formatted version of your input for a `README.md` file using Markdown syntax. It organizes the information clearly and concisely while maintaining the technical details you provided.

````markdown
# LayerZero Integration Project

This project integrates LayerZero for cross-chain communication between contracts deployed on the Cardona Testnet and Amoy Testnet. Below are the details for deployments, wiring, tasks, and the current issue.

## Documentation Reference

Refer to the [LayerZero Documentation](https://docs.layerzero.network/v2/developers/evm/create-lz-oapp/start) for detailed instructions on:

- Deployments
- Wiring
- Basics

## Deployments

### Commands

- **Deploy**:
  ```bash
  npx hardhat lz:deploy --network cardona-testnet
  ```
````

- **Wire**:
  ```bash
  npx hardhat lz:oapp:wire --oapp-config layerzero.config.ts
  ```
- **Check Wiring**:
  ```bash
  npx hardhat lz:oapp:peers:get --oapp-config layerzero.config.ts
  ```

### Deployment Strategy

- **Cardona Testnet**:
  - `RegistrarStorageChild` (upgradable via proxy)
  - `MessagingContract`
- **Amoy Testnet**:
  - `VerificationContract` (placeholder for "mother" contract)

### Deployed Contracts

- **Cardona Testnet**:
  - **RegistrarStorageUtil**: `0xbec521254ff3e724F0fC2765Da0960d1E70a0e5A`
  - **RegistrarStorage (Proxy)**: `0x3ec5f6847184C183379a54c25f634ACB617b8b61`
  - **MessagingContract**: `0x7b37a6bcAd02E18c01922cE0a17a84845bF86B25`
- **Amoy Testnet**:
  - **VerificationContract**: `0xDEFefbABB7Cf6d50cf91190aAD87a295785e2303`

## Tasks

The `ConfigureLayerZero` task is used to set the addresses of `MessagingContract` and `RegistrarStorageContract` in each other for delegation. Delegation is necessary due to contracts reaching the maximum code size limit in a single file.

### Template Test Contracts

- Test LayerZero functionality with:
  - `getLatestMessage.ts`
  - `sendMessage.ts`
- Run these tasks to verify template LayerZero deployments.

### Storage Implementation Test

- Use the `IntiateSafleIdRegister.ts` task to test the deployed storage implementation.

### Running Tasks

- Execute a task with:
  ```bash
  npx hardhat "taskName" --network cardona-testnet
  ```
  _(Replace `taskName` with the name found in the task files.)_

**Note**: `RegistrarStorageChild` is an upgradable contract and must be interacted with via its proxy implementation (`RegistrarStorage`).

## Deployment Folder

The `Deployments` folder is included, so you don’t need to redeploy or reconfigure contract addresses manually.

## Current Problem

The `RegistrarStorage` task is failing with a transaction revert. Possible causes:

1. **Obvious Issue**: The problem might be a simple oversight in the codebase (e.g., misconfiguration or logic error), but saturation with the codebase may be obscuring it.
2. **LayerZero Protocol**: The protocol might require identical `MessagingContract` deployments across networks, including bytecode similarity (less likely but possible).
   - Template OApp contracts work perfectly as they are identical across networks.
   - Storage contracts differ between Cardona Testnet (child) and Amoy Testnet (mother), which might cause issues.

## Environment

- **Private Key**:
  ```
  PRIVATE_KEY=4fdb540ad6b8aa4ee6aa5b5bacd0b76986ef82355b017515196ff72eea45233c
  ```
  _(Ensure this is stored securely, e.g., in a `.env` file, and not exposed in production.)_

## Next Steps

- Debug the `RegistrarStorage` task failure.
- Verify if LayerZero requires identical `MessagingContract` deployments across chains.
- Test interactions with the proxy contract (`RegistrarStorage`) to ensure proper delegation.
