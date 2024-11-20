// const path = [WETH, USDC, WETH];
// const exchRoute = [0, 2];
// const salt = ethers.randomBytes(32);


// import { ethers } from "hardhat";
// import { expect } from "chai";
// import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

// describe("Arbitrage on Base", function () {
//   async function deployContractAndSetupTokens() {
//     const [owner] = await ethers.getSigners();
    
//     // Set high gas price to pass withPrivateMempool modifier
//     const highGasPrice = ethers.parseUnits("100", "gwei");
//     const txOptions = {
//       gasPrice: highGasPrice,
//       gasLimit: 3000000
//     };
    
//     const Arbitrage = await ethers.getContractFactory("Arbitrage");
//     const arbitrage = await Arbitrage.deploy(txOptions);

//     const WETH = "0x4200000000000000000000000000000000000006";
//     const USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
//     const CBETH = "0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22";

//     // Setup whale
//     const WHALE = "0xB33FC0B28ECA45dcc710Bc6B429bb1a26132141c";
//     await ethers.provider.send("hardhat_setBalance", [
//       WHALE,
//       ethers.toBeHex(ethers.parseEther("10000"))
//     ]);
//     await ethers.provider.send("hardhat_impersonateAccount", [WHALE]);
//     const whale = await ethers.getSigner(WHALE);
    
//     // Get token contracts
//     const wethContract = await ethers.getContractAt("IERC20", WETH);
//     await wethContract.connect(whale).transfer(await arbitrage.getAddress(), ethers.parseEther("2"));

//     return { arbitrage, owner, WETH, USDC, CBETH, wethContract };
//   }
//   describe("Submarine Send Tests", function () {
//     it("should execute trade with submarine protection", async function () {
//         const { arbitrage, owner, WETH } = await loadFixture(deployContractAndSetupTokens);
        
//           const token = "0x18A8BD1fe17A1BB9FFB39eCD83E9489cfD17a022"
//           const flashAmount = ethers.parseEther("1");
//           const path = [WETH, token, WETH];
//           const exchRoute = [1, 0];

//           const pools = [
//             "0xcc4fab1466f0acf4c837216096a55924057252e4",
//             "0xff5375bd65056dbe6119256fc3be2eb0ffa8a840",
//           ];
//          const salt = ethers.randomBytes(32);

//          const commitment = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
//           ["address", "uint256", "address[]", "uint8[]", "address[]", "bytes32", "address"],
//           [WETH, flashAmount, path, exchRoute, pools, salt, owner.address]
//         ));
      

//         await arbitrage.commit(commitment);
//         await ethers.provider.send("evm_mine", []);

//         const tx = await arbitrage.connect(owner).getFlashloanWithSubmarine(
//           WETH,
//           flashAmount,
//           path,
//           exchRoute,
//           pools,
//           salt,
//           { 
//               gasLimit: 3000000,
//               maxPriorityFeePerGas: ethers.parseUnits("100", "gwei"),
//               maxFeePerGas: ethers.parseUnits("200", "gwei")
//           }
//       );
      

//         const receipt = await tx.wait();
//         expect(receipt?.status).to.equal(1);
//     });
// });

// });



