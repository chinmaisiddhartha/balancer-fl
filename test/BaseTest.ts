// import { ethers } from "hardhat";
// import { expect } from "chai";
// import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

// describe("Arbitrage", function () {
//   async function deployContractAndSetupTokens() {
//     const [owner, otherAccount] = await ethers.getSigners();
//     const Arbitrage = await ethers.getContractFactory("Arbitrage");
//     const arbitrage = await Arbitrage.deploy();

//     const WETH = "0x4200000000000000000000000000000000000006";
//     const USDT = "0x532f27101965dd16442e59d40670faf5ebb142e4";
//     const WBTC = "0x0555E30da8f98308EdB960aa94C0Db47230d2B9c";
//     const DAI = "0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb";

//     const wethContract = await ethers.getContractAt("IERC20", WETH);
//     const usdtContract = await ethers.getContractAt("IERC20", USDT);
//     const wbtcContract = await ethers.getContractAt("IERC20", WBTC);
//     const daiContract = await ethers.getContractAt("IERC20", DAI);


//     // Impersonate a whale account and transfer some WETH to our contract
//     const WHALE_ADDRESS = "0xB33FC0B28ECA45dcc710Bc6B429bb1a26132141c"; // WETH whale
//     // const WHALE_ADDRESS = "0xd261B5F831e0fA4345667c36b3e58463650A9a89"; // USDC whale
//     // const WHALE_ADDRESS = "0xd261B5F831e0fA4345667c36b3e58463650A9a89"; // USDC whale

//     await ethers.provider.send("hardhat_impersonateAccount", [WHALE_ADDRESS]);
//     const whale = await ethers.getSigner(WHALE_ADDRESS);
//     await wethContract.connect(whale).transfer(await arbitrage.getAddress(), ethers.parseEther("2"));

//     return { arbitrage, owner, otherAccount, WETH, USDT, WBTC, wethContract, usdtContract, wbtcContract };
//   }

//   describe("deployment", async function () {
//     it("should deploy the contract", async function () {
//       const { arbitrage } = await loadFixture(deployContractAndSetupTokens);
//       expect(await arbitrage.getAddress()).to.not.equal(ethers.ZeroAddress);
//       console.log("Arbitrage contract address:", await arbitrage.getAddress());
//     });

//     it("should attempt flashloan and arbitrage", async function () {
//       const { arbitrage, owner, wethContract, WETH, USDT } = await loadFixture(deployContractAndSetupTokens);

//       console.log("checking WETH balance of our smart contract..!!");
//       const balance = await wethContract.balanceOf(await arbitrage.getAddress());
//       console.log("WETH balance of our smart contract before swap is:", balance.toString());

//       const token = "0x532f27101965dd16442E59d40670FaF5eBB142E4"
//       const flashAmount = ethers.parseEther("1");
//       const path = [WETH, token, WETH];
//       const v3Fee = 2500; // 0.3% fee tier for Uniswap V3
//       const exchRoute = [1, 1]; // Uniswap V3, Uniswap V2, SushiSwap V2
      
//       // You'll need to provide actual pool addresses for each swap
//       const pools = [
//         "0x4e829f8a5213c42535ab84aa40bd4adcce9cba02",
//         "0x36a46dff597c5a444bbc521d26787f57867d2214" // WETH/USDT Uniswap V3 pool
//         // "0x3041CbD36888bECc7bbCBc0045E3B1f144466f5f" // USDC/USDT SushiSwap pair
//         // "0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc"  // USDC/WETH Uniswap v2 pair
//       ];

//       const tx = await arbitrage.connect(owner).getFlashloan(WETH, flashAmount, path, v3Fee, exchRoute, pools);
//       const receipt = await tx.wait();
//       expect(receipt?.status).to.equal(1);
//       console.log("Arbitrage transaction:", tx);

//       console.log("checking WETH balance of our smart contract after swap..!!");
//       const balanceAfter = await wethContract.balanceOf(await arbitrage.getAddress());
//       console.log("WETH balance of our smart contract after the swap is:", balanceAfter.toString());
      
//       // Check if there's any profit (or at least no significant loss)
//       expect(balanceAfter).to.be.gte(balance * 99n / 100n); // Allow for up to 1% loss due to fees
//     });  
//   });
// });










