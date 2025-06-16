const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("Starting post-deployment setup...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Setup account:", deployer.address);

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

  // Configuration from environment variables
  const config = {
    adminAddress: process.env.ADMIN_ADDRESS || deployer.address,
    relayerAddresses: [
      process.env.RELAYER_ADDRESS_1,
      process.env.RELAYER_ADDRESS_2
    ].filter(Boolean),
    emergencyAddress: process.env.EMERGENCY_ADDRESS || deployer.address,
    upgraderAddress: process.env.UPGRADER_ADDRESS || deployer.address,
    registrars: [
      {
        address: process.env.REGISTRAR_1_ADDRESS,
        name: process.env.REGISTRAR_1_NAME || "registrar1"
      },
      {
        address: process.env.REGISTRAR_2_ADDRESS,
        name: process.env.REGISTRAR_2_NAME || "registrar2"
      }
    ].filter(r => r.address),
    maxSecondaryAddresses: parseInt(process.env.MAX_SECONDARY_ADDRESSES || "10"),
    minUnifiedIdLength: parseInt(process.env.MIN_UNIFIED_ID_LENGTH || "4"),
    maxUnifiedIdLength: parseInt(process.env.MAX_UNIFIED_ID_LENGTH || "16")
  };

  try {
    // Get contract instances
    const registrarStorage = await ethers.getContractAt("RegistrarStorageChildEvents", deployment.contracts.RegistrarStorageChildEvents);
    const resolver = await ethers.getContractAt("UnifiedIdResolver", deployment.contracts.UnifiedIdResolver);
    const storageUtil = await ethers.getContractAt("RegistrarStorageUtil", deployment.contracts.RegistrarStorageUtil);
    const motherContract = await ethers.getContractAt("RegistrarStorageMother", deployment.contracts.RegistrarStorageMother);

    console.log("\n=== SETTING UP ROLES ===");

    // Setup RegistrarStorageChildEvents roles
    console.log("\n1. Setting up RegistrarStorageChildEvents roles...");
    
    if (config.adminAddress !== deployer.address) {
      console.log(`Granting ADMIN_ROLE to ${config.adminAddress}`);
      await registrarStorage.grantRole(await registrarStorage.ADMIN_ROLE(), config.adminAddress);
    }

    if (config.emergencyAddress !== deployer.address) {
      console.log(`Granting EMERGENCY_ROLE to ${config.emergencyAddress}`);
      await registrarStorage.grantRole(await registrarStorage.EMERGENCY_ROLE(), config.emergencyAddress);
    }

    if (config.upgraderAddress !== deployer.address) {
      console.log(`Granting UPGRADER_ROLE to ${config.upgraderAddress}`);
      await registrarStorage.grantRole(await registrarStorage.UPGRADER_ROLE(), config.upgraderAddress);
    }

    // Setup relayers
    for (const relayerAddress of config.relayerAddresses) {
      console.log(`Granting RELAYER_ROLE to ${relayerAddress}`);
      await registrarStorage.grantRole(await registrarStorage.RELAYER_ROLE(), relayerAddress);
    }

    // Setup registrars
    for (const registrar of config.registrars) {
      console.log(`Granting REGISTRAR_ROLE to ${registrar.address} (${registrar.name})`);
      await registrarStorage.grantRole(await registrarStorage.REGISTRAR_ROLE(), registrar.address);
    }

    // Setup UnifiedIdResolver roles
    console.log("\n2. Setting up UnifiedIdResolver roles...");
    
    if (config.adminAddress !== deployer.address) {
      console.log(`Granting ADMIN_ROLE to ${config.adminAddress}`);
      await resolver.grantRole(await resolver.ADMIN_ROLE(), config.adminAddress);
    }

    if (config.upgraderAddress !== deployer.address) {
      console.log(`Granting UPGRADER_ROLE to ${config.upgraderAddress}`);
      await resolver.grantRole(await resolver.UPGRADER_ROLE(), config.upgraderAddress);
    }

    // Setup RegistrarStorageUtil roles
    console.log("\n3. Setting up RegistrarStorageUtil roles...");
    
    if (config.adminAddress !== deployer.address) {
      console.log(`Granting ADMIN_ROLE to ${config.adminAddress}`);
      await storageUtil.grantRole(await storageUtil.ADMIN_ROLE(), config.adminAddress);
      
      console.log(`Granting PRICE_FEED_MANAGER_ROLE to ${config.adminAddress}`);
      await storageUtil.grantRole(await storageUtil.PRICE_FEED_MANAGER_ROLE(), config.adminAddress);
      
      console.log(`Granting CONFIG_MANAGER_ROLE to ${config.adminAddress}`);
      await storageUtil.grantRole(await storageUtil.CONFIG_MANAGER_ROLE(), config.adminAddress);
    }

    // Setup RegistrarStorageMother roles
    console.log("\n4. Setting up RegistrarStorageMother roles...");
    
    if (config.adminAddress !== deployer.address) {
      console.log(`Granting ADMIN_ROLE to ${config.adminAddress}`);
      await motherContract.grantRole(await motherContract.ADMIN_ROLE(), config.adminAddress);
    }

    if (config.upgraderAddress !== deployer.address) {
      console.log(`Granting UPGRADER_ROLE to ${config.upgraderAddress}`);
      await motherContract.grantRole(await motherContract.UPGRADER_ROLE(), config.upgraderAddress);
    }

    console.log("\n=== CONFIGURING SETTINGS ===");

    // Configure contract settings
    console.log("\n5. Configuring contract settings...");
    
    try {
      // Update unified ID length limits if they differ from defaults
      const currentMin = await storageUtil.minUnifiedIdLength();
      const currentMax = await storageUtil.maxUnifiedIdLength();
      
      if (currentMin.toString() !== config.minUnifiedIdLength.toString() || 
          currentMax.toString() !== config.maxUnifiedIdLength.toString()) {
        console.log(`Setting unified ID length limits: ${config.minUnifiedIdLength} - ${config.maxUnifiedIdLength}`);
        await storageUtil.setUnifiedIdLengthLimits(config.minUnifiedIdLength, config.maxUnifiedIdLength);
      }
    } catch (error) {
      console.log("Failed to update unified ID length limits:", error.message);
    }

    // Register registrars in the system
    console.log("\n6. Registering registrars...");
    for (const registrar of config.registrars) {
      try {
        console.log(`Registering ${registrar.name} (${registrar.address})`);
        // Note: This might require payment, so we'll check if it's already registered first
        const existingAddress = await registrarStorage.registrarNameToAddress(registrar.name);
        if (existingAddress === "0x0000000000000000000000000000000000000000") {
          await registrarStorage.registerRegistrar(registrar.name, registrar.address);
          console.log(`Successfully registered ${registrar.name}`);
        } else {
          console.log(`${registrar.name} is already registered`);
        }
      } catch (error) {
        console.log(`Failed to register ${registrar.name}:`, error.message);
      }
    }

    console.log("\n=== CONFIGURATION SUMMARY ===");
    console.log("Admin address:", config.adminAddress);
    console.log("Emergency address:", config.emergencyAddress);
    console.log("Upgrader address:", config.upgraderAddress);
    console.log("Relayers:", config.relayerAddresses);
    console.log("Registrars:", config.registrars.map(r => `${r.name} (${r.address})`));
    console.log("Max secondary addresses:", config.maxSecondaryAddresses);
    console.log("Unified ID length range:", `${config.minUnifiedIdLength} - ${config.maxUnifiedIdLength}`);

    // Save setup configuration
    const setupSummary = {
      network: network.name,
      chainId: network.chainId.toString(),
      setupAccount: deployer.address,
      timestamp: new Date().toISOString(),
      config: config,
      contracts: deployment.contracts
    };

    const setupFile = path.join(__dirname, "..", "deployments", `setup-${network.name}-${network.chainId}.json`);
    fs.writeFileSync(setupFile, JSON.stringify(setupSummary, null, 2));

    console.log("\n=== SETUP COMPLETE ===");
    console.log("Setup summary saved to:", setupFile);
    console.log("\nYour contracts are now ready to use!");
    console.log("\n=== CONTRACT ADDRESSES ===");
    Object.entries(deployment.contracts).forEach(([name, address]) => {
      console.log(`${name}: ${address}`);
    });

  } catch (error) {
    console.error("Setup failed:", error);
    process.exitCode = 1;
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = main; 