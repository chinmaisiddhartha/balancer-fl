// // import { ethers } from "hardhat";
// // import { expect } from "chai";
// // import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

// // describe("Arbitrage", function () {
// //   async function deployContractAndSetupTokens() {
// //     const [owner, otherAccount] = await ethers.getSigners();
// //     const Arbitrage = await ethers.getContractFactory("Arbitrage");
// //     const arbitrage = await Arbitrage.deploy();

// //     const WETH = "0x4200000000000000000000000000000000000006";
// //     const USDT = "0x532f27101965dd16442e59d40670faf5ebb142e4";
// //     const WBTC = "0x0555E30da8f98308EdB960aa94C0Db47230d2B9c";
// //     const DAI = "0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb";

// //     const wethContract = await ethers.getContractAt("IERC20", WETH);
// //     const usdtContract = await ethers.getContractAt("IERC20", USDT);
// //     const wbtcContract = await ethers.getContractAt("IERC20", WBTC);
// //     const daiContract = await ethers.getContractAt("IERC20", DAI);


// //     // Impersonate a whale account and transfer some WETH to our contract
// //     const WHALE_ADDRESS = "0xB33FC0B28ECA45dcc710Bc6B429bb1a26132141c"; // WETH whale
// //     // const WHALE_ADDRESS = "0xd261B5F831e0fA4345667c36b3e58463650A9a89"; // USDC whale
// //     // const WHALE_ADDRESS = "0xd261B5F831e0fA4345667c36b3e58463650A9a89"; // USDC whale

// //     await ethers.provider.send("hardhat_impersonateAccount", [WHALE_ADDRESS]);
// //     const whale = await ethers.getSigner(WHALE_ADDRESS);
// //     await wethContract.connect(whale).transfer(await arbitrage.getAddress(), ethers.parseEther("2"));

// //     return { arbitrage, owner, otherAccount, WETH, USDT, WBTC, wethContract, usdtContract, wbtcContract };
// //   }

// //   describe("deployment", async function () {
// //     it("should deploy the contract", async function () {
// //       const { arbitrage } = await loadFixture(deployContractAndSetupTokens);
// //       expect(await arbitrage.getAddress()).to.not.equal(ethers.ZeroAddress);
// //       console.log("Arbitrage contract address:", await arbitrage.getAddress());
// //     });

// //     it("should attempt flashloan and arbitrage", async function () {
// //       const { arbitrage, owner, wethContract, WETH, USDT } = await loadFixture(deployContractAndSetupTokens);

// //       console.log("checking WETH balance of our smart contract..!!");
// //       const balance = await wethContract.balanceOf(await arbitrage.getAddress());
// //       console.log("WETH balance of our smart contract before swap is:", balance.toString());

// //       const token = "0x532f27101965dd16442E59d40670FaF5eBB142E4"
// //       const flashAmount = ethers.parseEther("1");
// //       const path = [WETH, token, WETH];
// //       const v3Fee = 2500; // 0.3% fee tier for Uniswap V3
// //       const exchRoute = [1, 1]; // Uniswap V3, Uniswap V2, SushiSwap V2
      
// //       // You'll need to provide actual pool addresses for each swap
// //       const pools = [
// //         "0x4e829f8a5213c42535ab84aa40bd4adcce9cba02",
// //         "0x36a46dff597c5a444bbc521d26787f57867d2214" // WETH/USDT Uniswap V3 pool
// //         // "0x3041CbD36888bECc7bbCBc0045E3B1f144466f5f" // USDC/USDT SushiSwap pair
// //         // "0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc"  // USDC/WETH Uniswap v2 pair
// //       ];

// //       const tx = await arbitrage.connect(owner).getFlashloan(WETH, flashAmount, path, v3Fee, exchRoute, pools);
// //       const receipt = await tx.wait();
// //       expect(receipt?.status).to.equal(1);
// //       console.log("Arbitrage transaction:", tx);

// //       console.log("checking WETH balance of our smart contract after swap..!!");
// //       const balanceAfter = await wethContract.balanceOf(await arbitrage.getAddress());
// //       console.log("WETH balance of our smart contract after the swap is:", balanceAfter.toString());
      
// //       // Check if there's any profit (or at least no significant loss)
// //       expect(balanceAfter).to.be.gte(balance * 99n / 100n); // Allow for up to 1% loss due to fees
// //     });  
// //   });
// // });


import { ethers } from "hardhat";
import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("Arbitrage on Base", function () {
  async function deployContractAndSetupTokens() {
    const [owner, otherAccount] = await ethers.getSigners();
    console.log("owner address:", owner.address);
    console.log("owner balance:", ethers.formatEther(await ethers.provider.getBalance(owner.address)));

    // Fund the owner account with ETH
    await ethers.provider.send("hardhat_setBalance", [
      owner.address,
      ethers.toBeHex(ethers.parseEther("10000"))
    ]);

    const Arbitrage = await ethers.getContractFactory("Arbitrage");
    const arbitrage = await Arbitrage.deploy();

    const WETH = "0x4200000000000000000000000000000000000006";
    const USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
    const CBETH = "0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22";

    const wethContract = await ethers.getContractAt("IERC20", WETH);
    const usdcContract = await ethers.getContractAt("IERC20", USDC);
    const cbethContract = await ethers.getContractAt("IERC20", CBETH);

    // Fund and impersonate whale
    const WHALE_ADDRESS = "0xB33FC0B28ECA45dcc710Bc6B429bb1a26132141c";
    await ethers.provider.send("hardhat_setBalance", [
      WHALE_ADDRESS,
      ethers.toBeHex(ethers.parseEther("10000"))
    ]);
    await ethers.provider.send("hardhat_impersonateAccount", [WHALE_ADDRESS]);
    const whale = await ethers.getSigner(WHALE_ADDRESS);
    await wethContract.connect(whale).transfer(await arbitrage.getAddress(), ethers.parseEther("2"));

    return { arbitrage, owner, otherAccount, WETH, USDC, CBETH, wethContract, usdcContract, cbethContract };
  }

  describe("deployment", async function () {
    it("should deploy the contract", async function () {
      const { arbitrage } = await loadFixture(deployContractAndSetupTokens);
      expect(await arbitrage.getAddress()).to.not.equal(ethers.ZeroAddress);
      console.log("Arbitrage contract address:", await arbitrage.getAddress());
    });

    it("should attempt flashloan and arbitrage", async function () {
      const { arbitrage, owner, wethContract, WETH, USDC } = await loadFixture(deployContractAndSetupTokens);

      console.log("checking WETH balance of our smart contract..!!");
      const balance = await wethContract.balanceOf(await arbitrage.getAddress());
      console.log("WETH balance of our smart contract before swap is:", balance.toString());

      const token = "0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed"; // cbETH on Base
      const flashAmount = ethers.parseEther("1");
      const path = [WETH, USDC, WETH];
      const exchRoute = [0, 2];
      
      const pools = [
        "0x88a43bbdf9d098eec7bceda4e2494615dfd9bb9c",
        "0x72ab388e2e2f6facef59e3c3fa2c4e29011c2d38",
      ];

      try {
        const tx = await arbitrage.connect(owner).getFlashloan(
          WETH, 
          flashAmount, 
          path, 
          exchRoute, 
          pools,
          { gasLimit: 3000000 }
        );
        
        const receipt = await tx.wait();
        console.log("\nTransaction successful!");
        
        const events = receipt?.logs.map((log: { topics: string[], data: string }) => {
          try {
            return arbitrage.interface.parseLog({
              topics: [...log.topics],
              data: log.data
            });
          } catch (e) {
            return null;
          }
        }).filter(Boolean);

        console.log("\nEvent Logs:");
        events?.forEach((event: any) => {
          console.log(`\nEvent: ${event?.name}`);
          console.log("Args:", event?.args);
        });        
      } catch (error: any) {
        console.log("\n🔥 Detailed Error Information:");
        console.log("Error Code:", error.code);
        console.log("Error Name:", error.name);
        console.log("Error Message:", error.message);
        
        if (error.error) {
          console.log("\nInternal Error Details:");
          console.log("Data:", error.error.data);
          console.log("Message:", error.error.message);
          console.log("Stack:", error.error.stack);
        }
        
        if (error.transaction) {
          console.log("\nTransaction Details:");
          console.log("To:", error.transaction.to);
          console.log("From:", error.transaction.from);
          console.log("Data:", error.transaction.data);
        }
        
        throw error;
      }

      console.log("checking WETH balance of our smart contract after swap..!!");
      const balanceAfter = await wethContract.balanceOf(await arbitrage.getAddress());
      console.log("WETH balance of our smart contract after the swap is:", balanceAfter.toString());
      
      expect(balanceAfter).to.be.gte(balance * 99n / 100n);
    });  
  });
});
