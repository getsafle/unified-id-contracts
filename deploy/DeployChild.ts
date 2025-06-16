import assert from "assert";
import { type DeployFunction } from "hardhat-deploy/types";

const { ethers, upgrades } = require("hardhat");

const messagingContractName = "MessagingContract";
const registrarStorageChildContractName = "RegistrarStorageChildEvents";
const registrarStorageUtil = "RegistrarStorageUtil";

const deploy: DeployFunction = async (hre) => {
  const { getNamedAccounts, deployments, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  assert(deployer, "Missing named deployer account");

  // console.log(`Network: ${hre.network.name}`)
  // console.log(`Deployer: ${deployer}`)

  // // Deploy RegistrarStorageUtil
  const registrarStorageUtilDeployment = await deploy(registrarStorageUtil, {
    from: deployer,
    args: [], // Add any required constructor args if needed
    log: true,
    skipIfAlreadyDeployed: false,
  });
  console.log(
    `Deployed contract: ${registrarStorageUtil}, network: ${hre.network.name}, address: ${registrarStorageUtilDeployment.address}`,
  );

  // Get EndpointV2 deployment

  const registrarStorageChildContract = await ethers.getContractFactory(
    "RegistrarStorageChild",
  );
  // // Deploy RegistrarStorage with proxy pattern
  // console.log(registrarStorageChildContract)
  const registrarStorageProxy = await upgrades.deployProxy(
    registrarStorageChildContract,
    [deployer, registrarStorageUtilDeployment.address, deployer],
    {
      skipIfAlreadyDeployed: false,
    },
  );

  console.log(
    `Deployed proxy contract: ${registrarStorageChildContractName}, network: ${hre.network.name}, address: ${registrarStorageProxy.address}`,
  );

  // Note: Add initialization calls or contract interconnections as needed
};

deploy.tags = ["Child"];

export default deploy;
