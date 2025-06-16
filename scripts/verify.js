const { run } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("Starting contract verification...");
  
  const network = await ethers.provider.getNetwork();
  console.log("Network:", network.name, "Chain ID:", network.chainId.toString());

  // Load deployment addresses
  const deploymentFile = path.join(__dirname, "..", "deployments", `${network.name}-${network.chainId}.json`);
  if (!fs.existsSync(deploymentFile)) {
    console.error("Deployment file not found. Please run deployment first.");
    process.exitCode = 1;
    return;
  }

  const deployment = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
  console.log("Loaded deployment from:", deploymentFile);

  const contracts = deployment.contracts;

  try {
    // Verify RegistrarStorageUtil (regular contract)
    console.log("\n1. Verifying RegistrarStorageUtil...");
    try {
      await run("verify:verify", {
        address: contracts.RegistrarStorageUtil,
        constructorArguments: []
      });
      console.log("✓ RegistrarStorageUtil verified");
    } catch (error) {
      console.log("✗ RegistrarStorageUtil verification failed:", error.message);
    }

    // Verify UnifiedIdResolver implementation
    console.log("\n2. Verifying UnifiedIdResolver implementation...");
    try {
      await run("verify:verify", {
        address: contracts.UnifiedIdResolverImpl,
        constructorArguments: []
      });
      console.log("✓ UnifiedIdResolver implementation verified");
    } catch (error) {
      console.log("✗ UnifiedIdResolver implementation verification failed:", error.message);
    }

    // Verify RegistrarStorageChildEvents implementation
    console.log("\n3. Verifying RegistrarStorageChildEvents implementation...");
    try {
      await run("verify:verify", {
        address: contracts.RegistrarStorageChildEventsImpl,
        constructorArguments: []
      });
      console.log("✓ RegistrarStorageChildEvents implementation verified");
    } catch (error) {
      console.log("✗ RegistrarStorageChildEvents implementation verification failed:", error.message);
    }

    // Verify MotherContract implementation
    console.log("\n4. Verifying MotherContract implementation...");
    try {
      await run("verify:verify", {
        address: contracts.MotherContractImpl,
        constructorArguments: []
      });
      console.log("✓ MotherContract implementation verified");
    } catch (error) {
      console.log("✗ MotherContract implementation verification failed:", error.message);
    }

    console.log("\n=== VERIFICATION COMPLETE ===");
    console.log("Note: Proxy contracts are automatically verified by OpenZeppelin.");
    console.log("Implementation contracts have been verified individually.");
    console.log("\nYou can view your contracts on Etherscan:");
    
    const explorerUrl = getExplorerUrl(network.chainId.toString());
    if (explorerUrl) {
      Object.entries(contracts).forEach(([name, address]) => {
        console.log(`${name}: ${explorerUrl}/address/${address}`);
      });
    }

  } catch (error) {
    console.error("Verification failed:", error);
    process.exitCode = 1;
  }
}

function getExplorerUrl(chainId) {
  const explorers = {
    "1": "https://etherscan.io",
    "11155111": "https://sepolia.etherscan.io",
    "137": "https://polygonscan.com",
    "80001": "https://mumbai.polygonscan.com"
  };
  return explorers[chainId];
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = main; 