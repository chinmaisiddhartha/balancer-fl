import { ethers } from "hardhat";
import dotenv from "dotenv";
dotenv.config();

async function main() {
  const provider = new ethers.JsonRpcProvider(`https://site1.moralis-nodes.com/base/${process.env.BASE_NODE_API_KEY}`);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
  console.log("Connected wallet:", wallet.address);
  
  const arbitrage = await ethers.getContractAt("Arbitrage", "0x9B692209041A02209cfdA6f08bd54C67EC25Ff5f", wallet);
  
  const WETH = "0x4200000000000000000000000000000000000006";
  const token = "0x9a26F5433671751C3276a065f57e5a02D2817973";
  
  const wethContract = await ethers.getContractAt("IERC20", WETH, wallet);
  const balance = await wethContract.balanceOf(arbitrage.getAddress());
  console.log("Contract WETH balance:", ethers.formatEther(balance));
  
  const pools = [
    "0xd82403772cB858219cfb58bFab46Ba7a31073474",
    "0x377FeeeD4820B3B28D1ab429509e7A0789824fCA",
  ];
  
  for(let i = 0; i < pools.length; i++) {
    const code = await provider.getCode(pools[i]);
    console.log(`Pool ${i} exists:`, code !== "0x");
  }

  try {
    const tx = await arbitrage.getFlashloan(
      WETH,
      ethers.parseEther("0.5"),
      [WETH, token, WETH],
      [1, 0],
      pools,
      { gasLimit: 3000000 }
    );
    console.log("Transaction sent:", tx.hash);
    
    const receipt = await tx.wait();
    if (receipt) {
      console.log("\nTransaction Receipt Details:");
      console.log("Block Number:", receipt.blockNumber);
      console.log("Gas Used:", receipt.gasUsed.toString());
      console.log("Effective Gas Price:", receipt.gasPrice?.toString());
      console.log("Status:", receipt.status === 1 ? "Success" : "Failed");
      
      if (receipt.logs.length > 0) {
        console.log("\nEvent Logs:");
        receipt.logs.forEach((log, index) => {
          console.log(`Log ${index}:`, log);
        });
      }
      
      if (receipt.status === 0) {
        const reason = await provider.call(tx);
        console.log("\nRevert Reason:", reason);
      }
    }
  } catch (error: any) {
    console.log("\nTransaction Failed:");
    console.log("Error:", error.toString());
    if (error.receipt) {
      console.log("Receipt Status:", error.receipt.status);
      console.log("Gas Used:", error.receipt.gasUsed.toString());
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch(console.error);
