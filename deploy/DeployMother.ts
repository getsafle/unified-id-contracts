import assert from "assert";

import { type DeployFunction } from "hardhat-deploy/types";

const verifierContractName = "VerificationContract";

const deploy: DeployFunction = async (hre) => {
  const { getNamedAccounts, deployments } = hre;

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  assert(deployer, "Missing named deployer account");

  console.log(`Network: ${hre.network.name}`);
  console.log(`Deployer: ${deployer}`);

  // console.log(
  //     `Deployed contract: ${verifierContractName}, network: ${hre.network.name}, address: ${verificationContractDeployment.address}`
  // )

  // Set MessagingContract in other contracts if needed
  // Example:
  // await someContract.setMessagingContract(messagingContractDeployment.address)
};

deploy.tags = ["Mother"];

export default deploy;
