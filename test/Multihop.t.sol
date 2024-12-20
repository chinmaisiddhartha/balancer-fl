// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// import {Test} from "forge-std/Test.sol";
// import {Arbitrage} from "../contracts/Arb.sol";
// import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

// contract MultihopTest is Test {
//     Arbitrage public arb;
//     address constant WETH = 0x4200000000000000000000000000000000000006;
//     address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
//     address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
//     address constant USDPLUS = 0xB79DD08EA68A908A97220C76d19A6aA9cBDE4376;

//     // Pool addresses
//     address constant POOL_1 = 0x68a1f6B6A725Bb74B6aBE41379a0e77031C0C5f5;
//     address constant POOL_2 = 0x4959E3B68c28162417F5378112f382CE97d9F226;
//     address constant POOL_3 = 0x273FDFE6018230F188741D7F93d4Ab589bD26197;
//     address constant POOL_4 = 0x88A43bbDF9D098eEC7bCEda4e2494615dfD9bB9C;

//     address constant WHALE = 0xB33FC0B28ECA45dcc710Bc6B429bb1a26132141c;
//     address attacker = address(0xBEEF);

//     function setUp() public {
//         vm.createSelectFork(vm.envString("BASE_RPC_URL"), 23294930);
//         arb = new Arbitrage();
        
//         vm.label(address(arb), "Arbitrage");
//         vm.label(WETH, "WETH");
//         vm.label(USDC, "USDC");
//         vm.label(CBBTC, "CBBTC");
//         vm.label(USDPLUS, "USDPLUS");

//         vm.deal(WHALE, 100 ether);
//         vm.startPrank(WHALE);
//         IERC20(WETH).transfer(address(arb), 2 ether);
//         vm.stopPrank();
//         vm.txGasPrice(100 gwei);
//     }

   
//     function testFlashLoan() public {
//         vm.startPrank(address(this), address(this));
//         bytes32 salt = bytes32(uint256(1));
//         address[] memory path = new address[](5);
//         path[0] = WETH;
//         path[1] = CBBTC;
//         path[2] = USDPLUS;
//         path[3] = USDC;
//         path[4] = WETH;
        
//         // Test PancakeV3 -> UniV2 route
//         uint8[] memory route1 = new uint8[](4);
//         route1[0] = 1;
//         route1[1] = 1;
//         route1[2] = 1;
//         route1[3] = 0;

        
//         address[] memory pools1 = new address[](4);
//         pools1[0] = POOL_1;
//         pools1[1] = POOL_2;
//         pools1[2] = POOL_3;
//         pools1[3] = POOL_4;

//         bytes32 commitment1 = keccak256(abi.encode(
//             WETH, 1 ether, path, route1, pools1, salt, address(this)
//         ));
//         arb.commit(commitment1);

//         uint256 gasBefore = gasleft();
//         vm.roll(block.number + 1);
//         arb.getFlashloanWithSubmarine(
//             WETH, 1 ether, path, route1, pools1, salt
//         );
//         uint256 gasUsed = gasBefore - gasleft();
//         emit log_named_uint("Gas used for PancakeV3 -> UniV2", gasUsed);

//         vm.stopPrank();
//     }

//     function testFlashLoanGasOptimization() public {
//         vm.startPrank(address(this), address(this));  
        
//         uint256[] memory flashAmounts = new uint256[](4);
//         flashAmounts[0] = 1 ether;
//         flashAmounts[1] = 5 ether;
//         flashAmounts[2] = 15 ether; 
//         flashAmounts[3] = 30 ether;
        
//         address[] memory path = new address[](5);
//         path[0] = WETH;
//         path[1] = CBBTC;
//         path[2] = USDPLUS;
//         path[3] = USDC;
//         path[4] = WETH;
        
//         uint8[] memory route = new uint8[](4);
//         route[0] = 1;
//         route[1] = 1;
//         route[2] = 1;
//         route[3] = 0;

        
//         address[] memory pools = new address[](4);
//         pools[0] = POOL_1;
//         pools[1] = POOL_2;
//         pools[2] = POOL_3;
//         pools[3] = POOL_4;
    
//         for(uint i = 0; i < flashAmounts.length; i++) {
//             bytes32 salt = bytes32(uint256(i + 1));
//             bytes32 commitment = keccak256(abi.encode(
//                 WETH, flashAmounts[i], path, route, pools, salt, address(this)
//             ));
//             arb.commit(commitment);
    
//             uint256 gasBefore = gasleft();
//             vm.roll(block.number + i + 1);
//             try arb.getFlashloanWithSubmarine(
//                 WETH, flashAmounts[i], path, route, pools, salt
//             ) {
//                 uint256 gasUsed = gasBefore - gasleft();
//                 emit log_named_uint("Flash amount", flashAmounts[i]);
//                 emit log_named_uint("Gas used", gasUsed);
//             } catch {
//                 emit log_named_uint("Failed flash amount", flashAmounts[i]);
//             }
//         }
//         vm.stopPrank();
//     }
    

//     function testPrivateMempoolProtection() public {
//         bytes32 salt = bytes32(uint256(1));
//         address[] memory path = new address[](5);
//         path[0] = WETH;
//         path[1] = CBBTC;
//         path[2] = USDPLUS;
//         path[3] = USDC;
//         path[4] = WETH;
        
//         uint8[] memory exchRoute = new uint8[](4);
//         exchRoute[0] = 1;
//         exchRoute[1] = 1;
//         exchRoute[2] = 1;
//         exchRoute[3] = 0;

        
//         address[] memory pools = new address[](4);
//         pools[0] = POOL_1;
//         pools[1] = POOL_2;
//         pools[2] = POOL_3;
//         pools[3] = POOL_4;

//         bytes32 commitment = keccak256(abi.encode(
//             WETH, 1 ether, path, exchRoute, pools, salt, address(this)
//         ));
//         arb.commit(commitment);
  
//         // Test gas price requirement
//         vm.txGasPrice(1 gwei);
//         vm.expectRevert("Low priority fee");
//         arb.getFlashloanWithSubmarine(WETH, 1 ether, path, exchRoute, pools, salt);

//         // Test direct EOA requirement
//         vm.txGasPrice(100 gwei);
//         address contractCaller = address(0xBEEF);
//         vm.startPrank(address(this), contractCaller); // msg.sender != tx.origin
//         vm.expectRevert("No flashbots");
//         arb.getFlashloanWithSubmarine(WETH, 1 ether, path, exchRoute, pools, salt);
//         vm.stopPrank();
        
//         // Test success case with correct conditions
//         vm.roll(block.number + 1);
//         vm.startPrank(address(this), address(this)); // msg.sender == tx.origin
//         arb.getFlashloanWithSubmarine(WETH, 1 ether, path, exchRoute, pools, salt);

//     }
// }
