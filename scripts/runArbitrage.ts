import { ethers } from "hardhat";
import { Arbitrage } from "../typechain-types";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Running arbitrage with account:", deployer.address);

  // Contract addresses
  const WETH = "0x4200000000000000000000000000000000000006";
  const TOKEN = "0x9a26F5433671751C3276a065f57e5a02D2817973";
  
  // Get contract instance
  const arbitrage = await ethers.getContractAt("Arbitrage", "YOUR_DEPLOYED_CONTRACT_ADDRESS") as Arbitrage;

  // Setup path and pools
  const path = [WETH, TOKEN, WETH];
  const exchRoute = [1, 0];
  const pools = [
    "0xd82403772cB858219cfb58bFab46Ba7a31073474",
    "0x377FeeeD4820B3B28D1ab429509e7A0789824fCA"
  ];

  // Generate salt and commitment
  const salt = ethers.randomBytes(32);
  const commitment = ethers.solidityPackedKeccak256(
    ["address", "uint256", "address[]", "uint8[]", "address[]", "bytes32", "address"],
    [WETH, ethers.parseEther("0.5"), path, exchRoute, pools, salt, deployer.address]
  );

  // Submit commitment
  const commitTx = await arbitrage.commit(commitment);
  await commitTx.wait();
  console.log("Commitment submitted:", commitment);

  // Wait for next block
  await ethers.provider.send("evm_mine", []);

  // Execute flashloan with submarine send
  const tx = await arbitrage.getFlashloanWithSubmarine(
    WETH,
    ethers.parseEther("0.5"),
    path,
    exchRoute,
    pools,
    salt,
    { gasLimit: 3000000 }
  );

  const receipt = await tx.wait();
  if (receipt === null) {
    throw new Error("Transaction failed");
  }
  console.log("Transaction executed:", receipt.hash);

  // Log events
  const events = receipt.logs.map(log => {
    try {
      return arbitrage.interface.parseLog({
        topics: [...log.topics],
        data: log.data
      });
    } catch (e) {
      return null;
    }
  }).filter(Boolean);

  console.log("Events:", events);
}
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
