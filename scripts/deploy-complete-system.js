const { ethers, upgrades, network } = require("hardhat");
const fs = require("fs");

async function main() {
  console.log(`🚀 Complete UnifiedID System Deployment to ${network.name}...`);
  console.log("=" .repeat(80));
  
  // Configuration with provided addresses and keys
  const config = {
    // Addresses for different roles
    addresses: {
      deployer: "0x_ADDRESS",
      owner: "0x_ADDRESS",
      relayer: "0x_ADDRESS",
      registrar: "0x_ADDRESS"
    },
    
    // Private keys for role assignment
    privateKeys: {
      deployer: "pvt_key",
      relayer: "pvt_key",
      registrar: "pvt_key"
    },
    
    // Network configuration
    chainId: network.config.chainId,
    
    // Contract configuration
    maxSecondaryAddresses: 10,
    minUnifiedIdLength: 4,
    maxUnifiedIdLength: 16,
    maxChainsPerUnifiedId: 50,
    ethUsdPriceFeed: "0x694AA1769357215DE4FAC081bf1f309aDC325306" // Sepolia ETH/USD price feed
  };

  let deploymentResults = {};

  try {
    console.log("\n📋 Configuration Summary:");
    console.log(`   Deployer/Owner: ${config.addresses.deployer}`);
    console.log(`   Relayer: ${config.addresses.relayer}`);
    console.log(`   Registrar: ${config.addresses.registrar}`);
    console.log(`   Chain ID: ${config.chainId}`);
    console.log(`   Min UnifiedID Length: ${config.minUnifiedIdLength}`);
    console.log(`   Max UnifiedID Length: ${config.maxUnifiedIdLength}`);
    console.log(`   Max Secondary Addresses: ${config.maxSecondaryAddresses}`);
    console.log(`   Max Chains Per UnifiedID: ${config.maxChainsPerUnifiedId}`);

    // Setup signers
    const deployerSigner = new ethers.Wallet(config.privateKeys.deployer, ethers.provider);
    const relayerSigner = new ethers.Wallet(config.privateKeys.relayer, ethers.provider);
    const registrarSigner = new ethers.Wallet(config.privateKeys.registrar, ethers.provider);

    console.log(`\n💰 Account Balances:`);
    console.log(`   Deployer: ${ethers.utils.formatEther(await deployerSigner.getBalance())} ETH`);
    console.log(`   Relayer: ${ethers.utils.formatEther(await relayerSigner.getBalance())} ETH`);
    console.log(`   Registrar: ${ethers.utils.formatEther(await registrarSigner.getBalance())} ETH`);

    // 1. Deploy and Initialize RegistrarStorageUtil
    console.log("\n📄 1. Deploying and Initializing RegistrarStorageUtil...");
    const RegistrarStorageUtil = await ethers.getContractFactory("RegistrarStorageUtil", deployerSigner);
    const utilContract = await upgrades.deployProxy(
      RegistrarStorageUtil,
      [config.addresses.owner], // Initialize with owner as admin
      { initializer: "initialize" }
    );
    await utilContract.deployed();
    const utilAddress = utilContract.address;
    console.log(`✅ RegistrarStorageUtil deployed to: ${utilAddress}`);
    deploymentResults.RegistrarStorageUtil = utilAddress;

    // Configure UnifiedID length limits in Util contract
    console.log("\n⚙️ Configuring RegistrarStorageUtil...");
    try {
      await utilContract.setUnifiedIdLengthLimits(config.minUnifiedIdLength, config.maxUnifiedIdLength);
      console.log(`✅ Set UnifiedID length limits: ${config.minUnifiedIdLength}-${config.maxUnifiedIdLength}`);
    } catch (error) {
      console.log(`⚠️ Could not set UnifiedID length limits: ${error.message}`);
    }

    // Set ETH price feed if available
    try {
      if (config.ethUsdPriceFeed !== "0x0000000000000000000000000000000000000000") {
        await utilContract.setEthPriceFeed(config.ethUsdPriceFeed);
        console.log(`✅ Set ETH price feed to: ${config.ethUsdPriceFeed}`);
      }
    } catch (error) {
      console.log(`⚠️ Could not set ETH price feed: ${error.message}`);
    }

    // 2. Deploy UnifiedIdResolver
    console.log("\n📄 2. Deploying UnifiedIdResolver...");
    const UnifiedIdResolver = await ethers.getContractFactory("UnifiedIdResolver", deployerSigner);
    const resolverContract = await upgrades.deployProxy(
      UnifiedIdResolver,
      [ethers.constants.AddressZero],  // Use ZeroAddress for registry initially
      { initializer: "initialize" }
    );
    await resolverContract.deployed();
    const resolverAddress = resolverContract.address;
    console.log(`✅ UnifiedIdResolver deployed to: ${resolverAddress}`);
    deploymentResults.UnifiedIdResolver = resolverAddress;

    // 3. Deploy Mother Contract (only on main chain)
    const isMainChain = network.config.chainId === 1 || network.name === "sepolia" || network.name === "ethereum";
    
    if (isMainChain) {
      console.log("\n📄 3. Deploying Mother Contract (Main Chain)...");
      const MotherContract = await ethers.getContractFactory("RegistrarStorageMother", deployerSigner);
      const motherContract = await upgrades.deployProxy(
        MotherContract,
        [
          utilAddress,       // _util
          resolverAddress    // _resolver
        ],
        { initializer: "initialize" }
      );
      await motherContract.deployed();
      const motherAddress = motherContract.address;
      console.log(`✅ Mother Contract deployed to: ${motherAddress}`);
      deploymentResults.RegistrarStorageMother = motherAddress;

      // Setup roles for Mother Contract
      console.log("\n🔐 Setting up Mother Contract roles...");
      const motherRelayerRole = await motherContract.RELAYER_ROLE();
      const motherAdminRole = await motherContract.ADMIN_ROLE();
      const motherEmergencyRole = await motherContract.EMERGENCY_ROLE();
      const motherUpgraderRole = await motherContract.UPGRADER_ROLE();
      
      // Grant all roles to deployer first
      await motherContract.grantRole(motherRelayerRole, config.addresses.deployer);
      await motherContract.grantRole(motherAdminRole, config.addresses.deployer);
      await motherContract.grantRole(motherEmergencyRole, config.addresses.deployer);
      await motherContract.grantRole(motherUpgraderRole, config.addresses.deployer);
      console.log(`✅ Granted all roles to deployer: ${config.addresses.deployer}`);
      
      // Grant specific roles to other addresses
      await motherContract.grantRole(motherRelayerRole, config.addresses.relayer);
      console.log(`✅ Granted RELAYER_ROLE to: ${config.addresses.relayer}`);
      
      await motherContract.grantRole(motherAdminRole, config.addresses.owner);
      await motherContract.grantRole(motherEmergencyRole, config.addresses.owner);
      await motherContract.grantRole(motherUpgraderRole, config.addresses.owner);
      console.log(`✅ Granted admin roles to: ${config.addresses.owner}`);
      
      console.log("✅ Roles configured for Mother Contract");
      
      // Configure Mother Contract settings
      console.log("\n⚙️ Configuring Mother Contract...");
      try {
        await motherContract.setMaxSecondaryAddressesPerChain(config.maxSecondaryAddresses);
        console.log(`✅ Set max secondary addresses per chain: ${config.maxSecondaryAddresses}`);
      } catch (error) {
        console.log(`⚠️ Could not set max secondary addresses: ${error.message}`);
      }

      try {
        await motherContract.setMaxChainsPerUnifiedId(config.maxChainsPerUnifiedId);
        console.log(`✅ Set max chains per unified ID: ${config.maxChainsPerUnifiedId}`);
      } catch (error) {
        console.log(`⚠️ Could not set max chains per unified ID: ${error.message}`);
      }

      console.log("✅ Mother Contract configuration completed");
    } else {
      console.log("\n⏭️ Skipping Mother Contract (Child chain deployment)");
    }

    // 4. Deploy Child Contract
    console.log("\n📄 4. Deploying Child Contract...");
    const ChildContract = await ethers.getContractFactory("RegistrarStorageChildEvents", deployerSigner);
    const childContract = await upgrades.deployProxy(
      ChildContract,
      [
        utilAddress,             // _RegistrarStorageUtil
        resolverAddress,         // _resolver  
        network.config.chainId   // _chainId
      ],
      { initializer: "initialize" }
    );
    await childContract.deployed();
    const childAddress = childContract.address;
    console.log(`✅ Child Contract deployed to: ${childAddress}`);
    deploymentResults.RegistrarStorageChildEvents = childAddress;

    // Setup roles for Child Contract
    console.log("\n🔐 Setting up Child Contract roles...");
    const childRelayerRole = await childContract.RELAYER_ROLE();
    const childRegistrarRole = await childContract.REGISTRAR_ROLE();
    const childAdminRole = await childContract.ADMIN_ROLE();
    const childEmergencyRole = await childContract.EMERGENCY_ROLE();
    const childUpgraderRole = await childContract.UPGRADER_ROLE();
    
    // Grant all roles to deployer first
    await childContract.grantRole(childRelayerRole, config.addresses.deployer);
    await childContract.grantRole(childRegistrarRole, config.addresses.deployer);
    await childContract.grantRole(childAdminRole, config.addresses.deployer);
    await childContract.grantRole(childEmergencyRole, config.addresses.deployer);
    await childContract.grantRole(childUpgraderRole, config.addresses.deployer);
    console.log(`✅ Granted all roles to deployer: ${config.addresses.deployer}`);
    
    // Grant specific roles to other addresses
    await childContract.grantRole(childRelayerRole, config.addresses.relayer);
    console.log(`✅ Granted RELAYER_ROLE to: ${config.addresses.relayer}`);
    
    await childContract.grantRole(childRegistrarRole, config.addresses.registrar);
    console.log(`✅ Granted REGISTRAR_ROLE to: ${config.addresses.registrar}`);
    
    await childContract.grantRole(childAdminRole, config.addresses.owner);
    await childContract.grantRole(childEmergencyRole, config.addresses.owner);
    await childContract.grantRole(childUpgraderRole, config.addresses.owner);
    console.log(`✅ Granted admin roles to: ${config.addresses.owner}`);
    
    console.log("✅ Roles configured for Child Contract");

    // Configure Child Contract settings
    console.log("\n⚙️ Configuring Child Contract...");
    try {
      // Set max secondary addresses
      await childContract.setMaxSecondaryAddresses(config.maxSecondaryAddresses);
      console.log(`✅ Set max secondary addresses: ${config.maxSecondaryAddresses}`);
    } catch (error) {
      console.log(`⚠️ Could not set max secondary addresses: ${error.message}`);
    }

    try {
      // Set unified ID length limits
      await childContract.setUnifiedIdLengthLimits(config.minUnifiedIdLength, config.maxUnifiedIdLength);
      console.log(`✅ Set unified ID length limits: ${config.minUnifiedIdLength}-${config.maxUnifiedIdLength}`);
    } catch (error) {
      console.log(`⚠️ Could not set unified ID length limits: ${error.message}`);
    }

    // Register the relayer as a registrar
    try {
      await childContract.registerRegistrar("relayer", config.addresses.relayer, {
        value: ethers.utils.parseEther("0.001")
      });
      console.log(`✅ Registered relayer as registrar: ${config.addresses.relayer}`);
    } catch (error) {
      console.log(`⚠️ Could not register relayer as registrar: ${error.message}`);
    }

    // Register the registrar address as a registrar
    try {
      await childContract.registerRegistrar("registrar", config.addresses.registrar, {
        value: ethers.utils.parseEther("0.001")
      });
      console.log(`✅ Registered registrar address as registrar: ${config.addresses.registrar}`);
    } catch (error) {
      console.log(`⚠️ Could not register registrar address: ${error.message}`);
    }

    console.log("✅ Child Contract configuration completed");

    // 5. Configure Resolver with contract addresses
    console.log("\n📄 5. Configuring UnifiedIdResolver...");
    try {
      if (isMainChain && deploymentResults.RegistrarStorageMother) {
        await resolverContract.setRegistry(deploymentResults.RegistrarStorageMother);
        console.log(`✅ Set registry to Mother Contract: ${deploymentResults.RegistrarStorageMother}`);
      }
      
      // Set child contract address in resolver (if method exists)
      try {
        await resolverContract.setChildContract(network.config.chainId, childAddress);
        console.log(`✅ Set child contract for chain ${network.config.chainId}: ${childAddress}`);
      } catch (error) {
        console.log(`⚠️ Could not set child contract in resolver: ${error.message}`);
      }
    } catch (error) {
      console.log(`⚠️ Could not configure resolver: ${error.message}`);
    }

    // 6. Verify role assignments
    console.log("\n🔍 Verifying role assignments...");
    
    // Verify Mother Contract roles (if deployed)
    if (isMainChain && deploymentResults.RegistrarStorageMother) {
      const motherContract = await ethers.getContractAt("RegistrarStorageMother", deploymentResults.RegistrarStorageMother, deployerSigner);
      
      const motherRelayerRole = await motherContract.RELAYER_ROLE();
      const motherAdminRole = await motherContract.ADMIN_ROLE();
      
      console.log("\n📋 Mother Contract Roles:");
      console.log(`   Deployer has RELAYER_ROLE: ${await motherContract.hasRole(motherRelayerRole, config.addresses.deployer)}`);
      console.log(`   Deployer has ADMIN_ROLE: ${await motherContract.hasRole(motherAdminRole, config.addresses.deployer)}`);
      console.log(`   Relayer has RELAYER_ROLE: ${await motherContract.hasRole(motherRelayerRole, config.addresses.relayer)}`);
      console.log(`   Owner has ADMIN_ROLE: ${await motherContract.hasRole(motherAdminRole, config.addresses.owner)}`);
    }

    // Verify Child Contract roles
    const childContractForVerification = await ethers.getContractAt("RegistrarStorageChildEvents", childAddress, deployerSigner);
    
    console.log("\n📋 Child Contract Roles:");
    console.log(`   Deployer has RELAYER_ROLE: ${await childContractForVerification.hasRole(childRelayerRole, config.addresses.deployer)}`);
    console.log(`   Deployer has REGISTRAR_ROLE: ${await childContractForVerification.hasRole(childRegistrarRole, config.addresses.deployer)}`);
    console.log(`   Deployer has ADMIN_ROLE: ${await childContractForVerification.hasRole(childAdminRole, config.addresses.deployer)}`);
    console.log(`   Relayer has RELAYER_ROLE: ${await childContractForVerification.hasRole(childRelayerRole, config.addresses.relayer)}`);
    console.log(`   Registrar has REGISTRAR_ROLE: ${await childContractForVerification.hasRole(childRegistrarRole, config.addresses.registrar)}`);
    console.log(`   Owner has ADMIN_ROLE: ${await childContractForVerification.hasRole(childAdminRole, config.addresses.owner)}`);

    // 7. Save deployment results
    console.log("\n💾 Saving deployment results...");
    const deploymentInfo = {
      network: network.name,
      chainId: network.config.chainId,
      timestamp: new Date().toISOString(),
      contracts: deploymentResults,
      configuration: {
        maxSecondaryAddresses: config.maxSecondaryAddresses,
        minUnifiedIdLength: config.minUnifiedIdLength,
        maxUnifiedIdLength: config.maxUnifiedIdLength,
        maxChainsPerUnifiedId: config.maxChainsPerUnifiedId
      },
      roles: {
        deployer: config.addresses.deployer,
        owner: config.addresses.owner,
        relayer: config.addresses.relayer,
        registrar: config.addresses.registrar
      }
    };

    const filename = `deployment-${network.name}-${Date.now()}.json`;
    fs.writeFileSync(filename, JSON.stringify(deploymentInfo, null, 2));
    console.log(`✅ Deployment info saved to: ${filename}`);

    // 8. Generate environment variables
    console.log("\n🔧 Environment Variables:");
    console.log(`RELAYER_PRIVATE_KEY=${config.privateKeys.relayer}`);
    console.log(`REGISTRAR_PRIVATE_KEY=${config.privateKeys.registrar}`);
    console.log(`DEPLOYER_PRIVATE_KEY=${config.privateKeys.deployer}`);
    console.log(`MOTHER_CONTRACT_ADDRESS=${deploymentResults.RegistrarStorageMother || 'N/A'}`);
    console.log(`CHILD_CONTRACT_ADDRESS=${deploymentResults.RegistrarStorageChildEvents}`);
    console.log(`UTIL_CONTRACT_ADDRESS=${deploymentResults.RegistrarStorageUtil}`);
    console.log(`RESOLVER_CONTRACT_ADDRESS=${deploymentResults.UnifiedIdResolver}`);
    console.log(`CHAIN_ID=${network.config.chainId}`);

    console.log("\n🎉 Deployment completed successfully!");
    console.log("=" .repeat(80));

  } catch (error) {
    console.error("❌ Deployment failed:", error);
    throw error;
  }
}

// Run the deployment
if (require.main === module) {
  main()
    .then(() => {
      console.log("✅ Deployment script completed!");
      process.exit(0);
    })
    .catch((error) => {
      console.error("❌ Deployment script failed:", error);
      process.exit(1);
    });
}

module.exports = { main }; 