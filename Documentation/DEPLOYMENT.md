# Unified ID Contracts Deployment

A comprehensive deployment setup for the Unified ID management system using Hardhat.

## Overview

This project deploys a complete Unified ID management system with the following contracts:
- **RegistrarStorageUtil**: Utility contract for signature verification and price feeds
- **UnifiedIdResolver**: Upgradeable resolver for UnifiedId to address mappings
- **RegistrarStorageChildEvents**: Main registrar contract with role-based access control
- **MotherContract**: Additional contract for extended functionality

## Prerequisites

- Node.js (v16+ recommended)
- npm or yarn
- A wallet with sufficient funds for deployment
- API keys for network providers (Alchemy, Infura, etc.)
- Etherscan API key for contract verification

## Installation

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Set up environment variables:**
   ```bash
   cp env.example .env
   ```
   
   Edit `.env` file with your configuration:
   ```env
   # Network Configuration
   PRIVATE_KEY=your_private_key_here
   SEPOLIA_RPC_URL=https://rpc.sepolia.org
   MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/your-api-key
   
   # API Keys
   ETHERSCAN_API_KEY=your_etherscan_api_key
   
   # Admin Addresses
   ADMIN_ADDRESS=your_admin_address_here
   RELAYER_ADDRESS_1=your_relayer_address_1
   RELAYER_ADDRESS_2=your_relayer_address_2
   EMERGENCY_ADDRESS=your_emergency_address_here
   UPGRADER_ADDRESS=your_upgrader_address_here
   
   # Registrar Configuration
   REGISTRAR_1_ADDRESS=your_registrar_1_address
   REGISTRAR_1_NAME=registrar1
   ```

## Configuration

The project uses the following Solidity compiler settings:
```json
{
  "optimizer": {
    "enabled": true,
    "runs": 22
  },
  "viaIR": true
}
```

## Deployment Steps

### Step 1: Compile Contracts

```bash
npm run compile
```

### Step 2: Deploy to Local Network (Testing)

1. **Start local Hardhat network:**
   ```bash
   npm run node
   ```

2. **Deploy contracts to localhost:**
   ```bash
   npm run deploy:localhost
   ```

### Step 3: Deploy to Testnet (Sepolia)

```bash
npm run deploy:sepolia
```

### Step 4: Deploy to Mainnet

```bash
npm run deploy:mainnet
```

### Step 5: Configure Roles and Settings

After deployment, run the setup script to configure roles, relayers, and admins:

```bash
npm run setup
```

This script will:
- Grant admin roles to specified addresses
- Set up relayer addresses
- Configure emergency and upgrader roles
- Register initial registrars
- Set contract parameters

### Step 6: Verify Contracts on Etherscan

```bash
npm run verify
```

## Deployed Contract Structure

The deployment creates the following contracts:

1. **RegistrarStorageUtil** (Regular Contract)
   - Handles signature verification
   - Manages price feeds
   - Configurable parameters

2. **UnifiedIdResolver** (UUPS Proxy)
   - Proxy: Main resolver address
   - Implementation: Logic contract
   - Handles UnifiedId ↔ Address mappings

3. **RegistrarStorageChildEvents** (UUPS Proxy)
   - Proxy: Main registrar address
   - Implementation: Logic contract
   - Core registration functionality

4. **MotherContract** (UUPS Proxy)
   - Proxy: Mother contract address
   - Implementation: Logic contract
   - Extended functionality

## Role Management

### Default Roles

Each contract has the following roles:
- **DEFAULT_ADMIN_ROLE**: Full administrative access
- **ADMIN_ROLE**: Administrative functions
- **UPGRADER_ROLE**: Contract upgrade permissions
- **EMERGENCY_ROLE**: Emergency operations
- **RELAYER_ROLE**: Transaction relay permissions
- **REGISTRAR_ROLE**: Registration permissions

### Setting Up Roles

The setup script automatically configures:
- Admin roles for specified addresses
- Relayer permissions for transaction processing
- Emergency access for critical operations
- Upgrader permissions for contract upgrades

## Network Support

The deployment supports the following networks:
- **Localhost** (Chain ID: 31337)
- **Sepolia Testnet** (Chain ID: 11155111)
- **Ethereum Mainnet** (Chain ID: 1)
- **Polygon** (Chain ID: 137)

## Gas Optimization

The contracts are optimized for gas efficiency:
- **Optimizer runs**: 22 (optimized for deployment cost)
- **Via IR**: Enabled for better optimization
- **Packed structs**: Used for storage efficiency
- **Role-based access**: Minimizes unnecessary checks

## Security Features

- **UUPS Upgradeable**: Secure upgrade pattern
- **Role-based access control**: Fine-grained permissions
- **Two-step ownership**: Prevents accidental ownership transfer
- **Signature verification**: EIP-712 compliant
- **Reentrancy protection**: Built-in safeguards

## Monitoring and Maintenance

### Checking Deployment Status

```bash
# View deployed contract addresses
cat deployments/sepolia-11155111.json

# View setup configuration
cat deployments/setup-sepolia-11155111.json
```

### Upgrading Contracts

Contracts using UUPS pattern can be upgraded:

```javascript
const { ethers, upgrades } = require("hardhat");

async function upgradeContract() {
  const NewImplementation = await ethers.getContractFactory("NewContractVersion");
  const upgraded = await upgrades.upgradeProxy(proxyAddress, NewImplementation);
  console.log("Contract upgraded:", await upgraded.getAddress());
}
```

## Troubleshooting

### Common Issues

1. **Compilation Errors**: Ensure all dependencies are installed
2. **Gas Limit Exceeded**: Increase gas limit in network configuration
3. **Verification Failed**: Check contract addresses and network settings
4. **Role Assignment Failed**: Ensure deployer has sufficient permissions

### Error Resolution

- **Type Conflicts**: Contracts use separate UserData structs - this is by design
- **Insufficient Funds**: Ensure deployer wallet has enough ETH
- **Network Issues**: Check RPC URL and network connectivity

## Development Scripts

```bash
# Compile contracts
npm run compile

# Run tests
npm run test

# Deploy to specific network
npm run deploy:localhost
npm run deploy:sepolia
npm run deploy:mainnet

# Setup roles and configuration
npm run setup

# Verify contracts
npm run verify

# Start local node
npm run node
```

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review deployment logs
3. Verify environment configuration
4. Check network connectivity and gas prices

## License

MIT License - see LICENSE file for details. 