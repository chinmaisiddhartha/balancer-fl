// import { ethers } from "hardhat";
// import { expect } from "chai";
// import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

// describe("FlashLoan", function () {
//   async function deployContract() {
//     const [owner, otherAccount] = await ethers.getSigners();
//     const FlashLoan = await ethers.getContractFactory("FlashLoanTemplate");
//     const flashLoan = await FlashLoan.deploy();
    
//     const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
//     const wethContract = await ethers.getContractAt("IERC20", WETH);

//     // Lets send some WETH to our contract from a whale who has WETH
//     const WHALE_ADDRESS = "0x157e23d3E68aC6f99334B8b0fE71F0eb844911Dd";
//     await ethers.provider.send("hardhat_impersonateAccount", [WHALE_ADDRESS]);
//     const whale = await ethers.getSigner(WHALE_ADDRESS);
//     await wethContract
//       .connect(whale)
//       .transfer(flashLoan.getAddress(), ethers.parseEther("2"));
//     return { flashLoan, owner, otherAccount, wethContract, WETH };

//   }
//   describe("deployment", async function () {
//     it("should deploy the contract", async function () {
//       const { flashLoan } = await loadFixture(deployContract);
//       expect(flashLoan.getAddress()).to.not.equal(0);
//       console.log("FlashLoan contract address:", await flashLoan.getAddress());
//     });
    


//     it("should attempt flashloan", async function () {
//       const { flashLoan, owner, wethContract, WETH } = await loadFixture(deployContract);

//       console.log("checking WETH balance of our smart contract..!!");
//       const balance = await wethContract.balanceOf(flashLoan.getAddress());
//       console.log("WETH balance of our smart contract  before swap is:", balance.toString());

//       const WETH_ADDRESS = WETH;
//       const RAIL_ADDRESS = "0xe76c6c83af64e4c60245d8c7de953df673a7a33d";
//       const flashAmount = ethers.parseEther("5");
//       const path = [WETH_ADDRESS, RAIL_ADDRESS, WETH_ADDRESS];
//       const v3Fee = 10000;
//       const exchRoute = [0, 2];

//       const tx = await flashLoan.connect(owner).getFlashloan(WETH_ADDRESS, flashAmount, path, v3Fee, exchRoute);
//       const receipt = await tx.wait();
//       if (receipt === null) {
//         throw new Error("Transaction receipt is null");
//       }
//       expect(receipt.status).to.equal(1);
//       console.log("FlashLoan transaction :", tx);

//       console.log("checking WETH balance of our smart contract after swap..!!");
//       const balanceAfter = await wethContract.balanceOf(flashLoan.getAddress());
//       console.log("WETH balance of our smart contract  after the swap is:", balanceAfter.toString());
      
//     });  
//   });
// })