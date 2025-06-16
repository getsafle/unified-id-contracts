// tasks/getLatestMessage.ts

import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

export default task(
  "getLatestMessage",
  "Retrieve the latest message object from the MyOApp contract",
).setAction(async (_, hre: HardhatRuntimeEnvironment) => {
  const [signer] = await hre.ethers.getSigners();

  // Get current network info
  const networkName = hre.network.name;
  const srcNetworkConfig = hre.config.networks[networkName];
  const srcEid = srcNetworkConfig?.eid;

  console.log("Fetching latest message:");
  console.log("- From address:", signer.address);
  console.log("- Network:", networkName, srcEid ? `(EID: ${srcEid})` : "");

  // Get the deployed MyOApp contract
  const myOApp = await hre.deployments.get("MyOApp");
  const contract = await hre.ethers.getContractAt(
    "MyOApp",
    myOApp.address,
    signer,
  );

  // Call the combined getter to retrieve the entire message object
  console.log("Retrieving latest message...");
  const [text, number, sender] = await contract.getLatestMessage();

  // Display the results
  console.log("🎉 Latest Message Received:");
  console.log("- Text:", text);
  console.log("- Number:", number.toString()); // Convert BigNumber to string for readability
  console.log("- Sender:", sender);

  // Optional: Check individual getters for consistency
  const latestText = await contract.getLatestText();
  const latestNumber = await contract.getLatestNumber();
  const latestSender = await contract.getLatestSender();

  console.log("\nVerifying with individual getters:");
  console.log("- Text (via getLatestText):", latestText);
  console.log("- Number (via getLatestNumber):", latestNumber.toString());
  console.log("- Sender (via getLatestSender):", latestSender);
});
