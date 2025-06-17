require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("@nomicfoundation/hardhat-verify");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.25",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1
      },
      viaIR: true,
      outputSelection: {
        "*": {
          "": ["ast"],
          "*": ["abi", "metadata", "devdoc", "userdoc", "storageLayout", "evm.legacyAssembly", "evm.bytecode", "evm.deployedBytecode", "evm.methodIdentifiers", "evm.gasEstimates", "evm.assembly"]
        }
      }
    }
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
      timeout: 120000, // 2 minutes
      httpHeaders: {}
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "https://rpc.sepolia.org",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 11155111,
      gas: 6000000, // Reduced from 10M to 6M
      timeout: 980000, // 2 minutes
      httpHeaders: {},
      blockGasLimit: 30000000
    },
    mainnet: {
      url: process.env.MAINNET_RPC_URL || "https://eth-mainnet.g.alchemy.com/v2/your-api-key",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 1,
      gasPrice: 20000000000, // 20 gwei
      gas: 6000000, // Reduced from 10M to 6M
      timeout: 120000, // 2 minutes
      httpHeaders: {},
      blockGasLimit: 30000000
    },
    polygon: {
      url: process.env.POLYGON_RPC_URL || "https://polygon-rpc.com",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 137,
      gasPrice: 30000000000, // 30 gwei
      gas: 6000000, // Reduced from 10M to 6M
      timeout: 120000, // 2 minutes
      httpHeaders: {},
      blockGasLimit: 30000000
    }
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY,
      sepolia: process.env.ETHERSCAN_API_KEY
    }
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    gasPrice: 20
  },
  mocha: {
    timeout: 300000 // 5 minutes for tests
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
}; 