const { ethers } = require("hardhat");
require("dotenv").config();

async function testNetwork() {
  console.log("Testing network connectivity...");
  
  try {
    const provider = ethers.provider;
    console.log("Provider:", provider.connection?.url || "localhost");
    
    // Test basic connectivity
    console.log("Testing basic connectivity...");
    const blockNumber = await provider.getBlockNumber();
    console.log("✓ Current block number:", blockNumber);
    
    // Test account access
    console.log("Testing account access...");
    const [signer] = await ethers.getSigners();
    console.log("✓ Signer address:", signer.address);
    
    // Test balance
    console.log("Testing balance...");
    const balance = await provider.getBalance(signer.address);
    console.log("✓ Balance:", ethers.formatEther(balance), "ETH");
    
    // Test gas price
    console.log("Testing gas price...");
    const gasPrice = await provider.getFeeData();
    console.log("✓ Gas price:", gasPrice.gasPrice ? ethers.formatUnits(gasPrice.gasPrice, "gwei") : "unknown", "gwei");
    
    // Test network info
    console.log("Testing network info...");
    const network = await provider.getNetwork();
    console.log("✓ Network:", {
      name: network.name,
      chainId: network.chainId.toString()
    });
    
    console.log("\n🎉 All network tests passed!");
    
  } catch (error) {
    console.error("❌ Network test failed:");
    console.error("Error type:", error.constructor.name);
    console.error("Error code:", error.code);
    console.error("Error message:", error.message);
    
    if (error.code === 'UND_ERR_HEADERS_TIMEOUT') {
      console.log("\n🔧 Troubleshooting suggestions:");
      console.log("1. Check your internet connection");
      console.log("2. Try a different RPC URL in your .env file");
      console.log("3. Check if you're behind a firewall or proxy");
      console.log("4. Verify your RPC provider is working");
      console.log("5. Try increasing timeout in hardhat.config.js");
    }
    
    process.exitCode = 1;
  }
}

testNetwork(); 