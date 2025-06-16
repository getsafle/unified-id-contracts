import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

export default task(
  "SafleIdFullLifecycleTest",
  "Test full lifecycle for SafleId registration and updates",
).setAction(async (_, hre: HardhatRuntimeEnvironment) => {
  const [signer1, signer2, signer3, signer4] = await hre.ethers.getSigners();
  const feeAmount = hre.ethers.utils.parseEther("0.002");
  const chainId = (await hre.ethers.provider.getNetwork()).chainId;

  const RegistrarChild = await hre.ethers.getContractAt(
    "RegistrarStorageChildEvents",
    "0xA2C25C124D1fF9748CEF41efc7FeE555eFE5df18",
  );
  const RegistrarMother = await hre.ethers.getContractAt(
    "RegistrarStorageMother",
    "0xc4d22901973f18a547Cf10a8E1047e3270527530",
  );

  const safleId = "testSafleId5";
  const safleId2 = "testSafleId6";
  const safleId3 = "testSafleId7";
  const safleId4 = "UniqueId1";
  const safleId5 = "UniqueBOTId";
  const safleId6 = "UniqueBOTId2";
  const safleId1 = "test2";
  const createSignature = async (
    signer: any,
    dataTypes: string[],
    dataValues: any[],
  ) => {
    const encoded = hre.ethers.utils.defaultAbiCoder.encode(
      dataTypes,
      dataValues,
    );
    const hash = hre.ethers.utils.keccak256(encoded);
    return await signer.signMessage(hre.ethers.utils.arrayify(hash));
  };

  // Initiate Register on Child
  console.log("\n--- Initiating SafleId Registration on Child ---");
  const regData = hre.ethers.utils.defaultAbiCoder.encode(
    ["string"],
    [safleId4],
  );
  const regSig = await signer2.signMessage(
    hre.ethers.utils.arrayify(hre.ethers.utils.keccak256(regData)),
  );
  console.log("Signature:", safleId3, signer2.address, regData, regSig);
  // console.log('signers', signer1.address, signer2.address, signer3.address, signer4.address)
  // const regDataSigner2 = hre.ethers.utils.defaultAbiCoder.encode(
  //     ['string', 'address'],
  //     [safleId6, signer3.address]
  // )
  // const regSigSigner2 = await signer1.signMessage(hre.ethers.utils.arrayify(hre.ethers.utils.keccak256(regData)))
  // console.log('Signature (Signer2):', safleId6, signer1.address, regSigSigner2)

  // await (
  //     await RegistrarChild.connect(signer1).initiateRegisterSafleId(safleId, signer1.address, regSig, '0x')
  // ).wait()
  // console.log('Registration initiated on Child.')

  // // Register on Mother via Relayer
  // console.log('\n--- Registering SafleId on Mother via Relayer ---')
  // await (
  //     await RegistrarMother.connect(relayerSigner).registerSafleId(
  //         safleId,
  //         chainId,
  //         signer1.address,
  //         regData,
  //         regSig
  //     )
  // ).wait()
  // console.log('SafleId registered on Mother.')

  // Initiate Primary Address Update on Child
  // console.log('\n--- Initiating Primary Address Update on Child ---')
  // const newPrimary = signer2.address
  // const primaryUpdateData = hre.ethers.utils.defaultAbiCoder.encode(['string', 'address'], [safleId, newPrimary])
  // const primaryUpdateSig = await signer1.signMessage(
  //     hre.ethers.utils.arrayify(hre.ethers.utils.keccak256(primaryUpdateData))
  // )
  // await (
  //     await RegistrarChild.connect(signer1).initiateUpdateSafleIdPrimaryAddress(
  //         safleId,
  //         newPrimary,
  //         primaryUpdateSig,
  //         '0x'
  //     )
  // ).wait()
  // console.log('Primary address update initiated on Child.')

  // // Update Primary on Mother
  // console.log('\n--- Updating Primary Address on Mother ---')
  // await (
  //     await RegistrarMother.connect(relayerSigner).updatePrimaryAddress(
  //         safleId,
  //         chainId,
  //         newPrimary,
  //         primaryUpdateData,
  //         primaryUpdateSig
  //     )
  // ).wait()
  // console.log('Primary address updated on Mother.')

  // // Display final state
  // console.log('\nFinal SafleID Data on Mother:', await RegistrarMother.getChainData(safleId, chainId))
  // console.log('Test lifecycle completed successfully.')
});
