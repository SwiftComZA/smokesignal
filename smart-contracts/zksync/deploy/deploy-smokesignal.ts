import { Wallet, utils } from "zksync-web3";
import * as ethers from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";

// load env file
import dotenv from "dotenv";
dotenv.config();

// load wallet private key from env file
const PRIVATE_KEY = process.env.WALLET_PRIVATE_KEY || "";

if (!PRIVATE_KEY)
  throw "⛔️ Private key not detected! Add it to the .env file!";

// An example of a deploy script that will deploy and call a simple contract.
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script for the SmokeSignal contract`);

  // Initialize the wallet.
  const wallet = new Wallet(PRIVATE_KEY);

  // Create deployer object and load the artifact of the contract you want to deploy.
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact("SmokeSignal_zkSync");

  // Estimate contract deployment fee
  const donationAddress = "0x959192eb0F3D33531711E596A66A7ee574e18A79";
                           
  const deploymentFee = await deployer.estimateDeployFee(artifact, [donationAddress]);

  const parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const smokeSignalContract = await deployer.deploy(artifact, [donationAddress]);

  //obtain the Constructor Arguments
  console.log(
    "Constructor args:" + smokeSignalContract.interface.encodeDeploy([donationAddress])
  );

  // Show the contract info.
  const contractAddress = smokeSignalContract.address;
  console.log(`${artifact.contractName} was deployed to ${contractAddress}`);

  // verify contract for tesnet & mainnet
  if (process.env.NODE_ENV != "test") {
    // Contract MUST be fully qualified name (e.g. path/sourceName:contractName)
    const contractFullyQualifedName = "contracts/SmokeSignal.sol:SmokeSignal_zkSync";

    // Verify contract programmatically
    const verificationId = await hre.run("verify:verify", {
      address: contractAddress,
      contract: contractFullyQualifedName,
      constructorArguments: [donationAddress],
      bytecode: artifact.bytecode,
    });
  } else {
    console.log(`Contract not verified, deployed locally.`);
  }
}
