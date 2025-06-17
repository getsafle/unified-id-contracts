const { ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("Starting deployment...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const network = await ethers.provider.getNetwork();
  console.log("Network:", network.name, "Chain ID:", network.chainId.toString());

  // Deployment configuration
  const config = {
    chainId: network.chainId.toString(),
    maxSecondaryAddresses: process.env.MAX_SECONDARY_ADDRESSES || 10,
    minUnifiedIdLength: process.env.MIN_UNIFIED_ID_LENGTH || 4,
    maxUnifiedIdLength: process.env.MAX_UNIFIED_ID_LENGTH || 16,
    ethUsdPriceFeed: process.env.ETH_USD_PRICE_FEED || "0x694AA1769357215DE4FAC081bf1f309aDC325306" // Sepolia
  };

  const deployed = {};

  try {
    // Step 1: Deploy RegistrarStorageUtil (regular contract)
    console.log("\n1. Deploying RegistrarStorageUtil...");
    const RegistrarStorageUtil = await ethers.getContractFactory("RegistrarStorageUtil");
    const storageUtil = await RegistrarStorageUtil.deploy();
    await storageUtil.deployed();
    deployed.RegistrarStorageUtil = storageUtil.address;
    console.log("RegistrarStorageUtil deployed to:", deployed.RegistrarStorageUtil);

    // Step 2: Deploy UnifiedIdResolver (upgradeable)
    console.log("\n2. Deploying UnifiedIdResolver...");
    const UnifiedIdResolver = await ethers.getContractFactory("UnifiedIdResolver");
    const resolver = await upgrades.deployProxy(
      UnifiedIdResolver, 
      [deployer.address], // Initial registry address (will be updated later)
      { 
        initializer: "initialize",
        kind: "uups"
      }
    );
    await resolver.deployed();
    deployed.UnifiedIdResolver = resolver.address;
    deployed.UnifiedIdResolverImpl = await upgrades.erc1967.getImplementationAddress(deployed.UnifiedIdResolver);
    console.log("UnifiedIdResolver proxy deployed to:", deployed.UnifiedIdResolver);
    console.log("UnifiedIdResolver implementation deployed to:", deployed.UnifiedIdResolverImpl);

    // Step 3: Deploy RegistrarStorageChildEvents (upgradeable)
    console.log("\n3. Deploying RegistrarStorageChildEvents...");
    const RegistrarStorageChildEvents = await ethers.getContractFactory("RegistrarStorageChildEvents");
    const registrar = await upgrades.deployProxy(
      RegistrarStorageChildEvents,
      [
        deployed.RegistrarStorageUtil,
        deployed.UnifiedIdResolver,
        config.chainId
      ],
      {
        initializer: "initialize",
        kind: "uups"
      }
    );
    await registrar.deployed();
    deployed.RegistrarStorageChildEvents = registrar.address;
    deployed.RegistrarStorageChildEventsImpl = await upgrades.erc1967.getImplementationAddress(deployed.RegistrarStorageChildEvents);
    console.log("RegistrarStorageChildEvents proxy deployed to:", deployed.RegistrarStorageChildEvents);
    console.log("RegistrarStorageChildEvents implementation deployed to:", deployed.RegistrarStorageChildEventsImpl);

    // Step 4: Deploy RegistrarStorageMother (upgradeable)
    console.log("\n4. Deploying RegistrarStorageMother...");
    const RegistrarStorageMother = await ethers.getContractFactory("RegistrarStorageMother");
    const motherContract = await upgrades.deployProxy(
      RegistrarStorageMother,
      [
        deployed.RegistrarStorageUtil,
        deployed.UnifiedIdResolver
      ],
      {
        initializer: "initialize",
        kind: "uups"
      }
    );
    await motherContract.deployed();
    deployed.RegistrarStorageMother = motherContract.address;
    deployed.RegistrarStorageMotherImpl = await upgrades.erc1967.getImplementationAddress(deployed.RegistrarStorageMother);
    console.log("RegistrarStorageMother proxy deployed to:", deployed.RegistrarStorageMother);
    console.log("RegistrarStorageMother implementation deployed to:", deployed.RegistrarStorageMotherImpl);

    // Step 5: Update UnifiedIdResolver to set RegistrarStorageChildEvents as registry
    console.log("\n5. Updating UnifiedIdResolver registry...");
    const resolverContract = await ethers.getContractAt("UnifiedIdResolver", deployed.UnifiedIdResolver);
    
    // Grant registry role to RegistrarStorageChildEvents
    const REGISTRY_ROLE = await resolverContract.REGISTRY_ROLE();
    const AUTHORIZED_CALLER_ROLE = await resolverContract.AUTHORIZED_CALLER_ROLE();
    
    await resolverContract.grantRole(REGISTRY_ROLE, deployed.RegistrarStorageChildEvents);
    console.log("Granted REGISTRY_ROLE to RegistrarStorageChildEvents");
    
    await resolverContract.grantRole(AUTHORIZED_CALLER_ROLE, deployed.RegistrarStorageChildEvents);
    console.log("Granted AUTHORIZED_CALLER_ROLE to RegistrarStorageChildEvents");

    // Also grant to RegistrarStorageMother
    await resolverContract.grantRole(REGISTRY_ROLE, deployed.RegistrarStorageMother);
    console.log("Granted REGISTRY_ROLE to RegistrarStorageMother");
    
    await resolverContract.grantRole(AUTHORIZED_CALLER_ROLE, deployed.RegistrarStorageMother);
    console.log("Granted AUTHORIZED_CALLER_ROLE to RegistrarStorageMother");

    // Step 6: Configure RegistrarStorageUtil
    console.log("\n6. Configuring RegistrarStorageUtil...");
    const storageUtilContract = await ethers.getContractAt("RegistrarStorageUtil", deployed.RegistrarStorageUtil);
    
    // Set ETH price feed if provided
    if (config.ethUsdPriceFeed && config.ethUsdPriceFeed !== "0x0000000000000000000000000000000000000000") {
      try {
        await storageUtilContract.setEthPriceFeed(config.ethUsdPriceFeed);
        console.log("Set ETH price feed to:", config.ethUsdPriceFeed);
      } catch (error) {
        console.log("Failed to set ETH price feed:", error.message);
      }
    }

    // Create deployment summary
    const deploymentSummary = {
      network: network.name,
      chainId: network.chainId.toString(),
      deployer: deployer.address,
      timestamp: new Date().toISOString(),
      contracts: deployed,
      config: config
    };

    // Save deployment addresses
    const deploymentsDir = path.join(__dirname, "..", "deployments");
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    const deploymentFile = path.join(deploymentsDir, `${network.name}-${network.chainId}.json`);
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentSummary, null, 2));

    console.log("\n=== DEPLOYMENT COMPLETE ===");
    console.log("Deployment summary saved to:", deploymentFile);
    console.log("\nDeployed contracts:");
    Object.entries(deployed).forEach(([name, address]) => {
      console.log(`${name}: ${address}`);
    });

    console.log("\n=== NEXT STEPS ===");
    console.log("1. Run 'npm run setup' to configure roles and settings");
    console.log("2. Verify contracts on Etherscan using 'npm run verify'");
    console.log("3. Update your .env file with the deployed addresses");

    return deployed;

  } catch (error) {
    console.error("Deployment failed:", error);
    process.exitCode = 1;
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = main; 