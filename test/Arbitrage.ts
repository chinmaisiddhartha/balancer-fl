import { ethers } from "hardhat";
import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("Arbitrage", function () {
  async function deployContractAndSetupTokens() {
    const [owner, otherAccount] = await ethers.getSigners();
    const Arbitrage = await ethers.getContractFactory("Arbitrage");
    const arbitrage = await Arbitrage.deploy();

    const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    const USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
    const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

    const wethContract = await ethers.getContractAt("IERC20", WETH);
    const usdtContract = await ethers.getContractAt("IERC20", USDT);
    const usdcContract = await ethers.getContractAt("IERC20", USDC);

    // Impersonate a whale account and transfer some WETH to our contract
    const WHALE_ADDRESS = "0x157e23d3E68aC6f99334B8b0fE71F0eb844911Dd";
    await ethers.provider.send("hardhat_impersonateAccount", [WHALE_ADDRESS]);
    const whale = await ethers.getSigner(WHALE_ADDRESS);
    await wethContract.connect(whale).transfer(await arbitrage.getAddress(), ethers.parseEther("2"));

    return { arbitrage, owner, otherAccount, WETH, USDT, USDC, wethContract, usdtContract, usdcContract };
  }

  describe("deployment", async function () {
    it("should deploy the contract", async function () {
      const { arbitrage } = await loadFixture(deployContractAndSetupTokens);
      expect(await arbitrage.getAddress()).to.not.equal(ethers.ZeroAddress);
      console.log("Arbitrage contract address:", await arbitrage.getAddress());
    });

    it("should attempt flashloan and arbitrage", async function () {
      const { arbitrage, owner, wethContract, WETH, USDT, USDC } = await loadFixture(deployContractAndSetupTokens);

      console.log("checking WETH balance of our smart contract..!!");
      const balance = await wethContract.balanceOf(await arbitrage.getAddress());
      console.log("WETH balance of our smart contract before swap is:", balance.toString());

      const flashAmount = ethers.parseEther("1");
      const path = [WETH, USDT, WETH];
      const v3Fee = 3000; // 0.3% fee tier for Uniswap V3
      const exchRoute = [1, 0]; // Uniswap V3, Uniswap V2, SushiSwap V2
      
      // You'll need to provide actual pool addresses for each swap
      const pools = [
        "0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36",
        "0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852" // WETH/USDT Uniswap V3 pool
        // "0x3041CbD36888bECc7bbCBc0045E3B1f144466f5f" // USDC/USDT SushiSwap pair
        // "0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc"  // USDC/WETH Uniswap v2 pair
      ];

      const tx = await arbitrage.connect(owner).getFlashloan(WETH, flashAmount, path, v3Fee, exchRoute, pools);
      const receipt = await tx.wait();
      expect(receipt?.status).to.equal(1);
      console.log("Arbitrage transaction:", tx);

      console.log("checking WETH balance of our smart contract after swap..!!");
      const balanceAfter = await wethContract.balanceOf(await arbitrage.getAddress());
      console.log("WETH balance of our smart contract after the swap is:", balanceAfter.toString());
      
      // Check if there's any profit (or at least no significant loss)
      expect(balanceAfter).to.be.gte(balance * 99n / 100n); // Allow for up to 1% loss due to fees
    });  
  });
});