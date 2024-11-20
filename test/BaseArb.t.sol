// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// import {Test} from "forge-std/Test.sol";
// import {Arbitrage} from "../contracts/Arb.sol";
// import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

// contract ArbitrageTest is Test {
//     Arbitrage public arb;
//     address constant WETH = 0x4200000000000000000000000000000000000006;
//     address constant BRETT = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
    
//     // Pool addresses
//     address constant UNI_V3_POOL = 0x75CC10fdcEa4b7D13c115ABB08240ac9c9Be6f2f;
//     address constant UNI_V2_POOL = 0x404E927b203375779a6aBD52A2049cE0ADf6609B;
    
//     address constant WHALE = 0xB33FC0B28ECA45dcc710Bc6B429bb1a26132141c;
//     address attacker = address(0xBEEF);

//     function setUp() public {
//         vm.createSelectFork(vm.envString("BASE_RPC_URL"), 22578759);
//         arb = new Arbitrage();
        
//         vm.deal(WHALE, 100 ether);
//         vm.startPrank(WHALE);
//         IERC20(WETH).transfer(address(arb), 2 ether);
//         vm.stopPrank();
//     }

//     function testMEVResistance() public {
//         bytes32 salt = bytes32(uint256(1));
//         address[] memory path = new address[](3);
//         path[0] = WETH;
//         path[1] = BRETT;
//         path[2] = WETH;
        
//         uint8[] memory exchRoute = new uint8[](2);
//         exchRoute[0] = 1; // PancakeV3
//         exchRoute[1] = 0; // UniV2
        
//         address[] memory pools = new address[](2);
//         pools[0] = UNI_V3_POOL;
//         pools[1] = UNI_V2_POOL;

//         bytes32 commitment = keccak256(abi.encode(
//             WETH, 1 ether, path, exchRoute, pools, salt, address(this)
//         ));

//         arb.commit(commitment);
        
//         // Simulate frontrunning attempt
//         vm.startPrank(attacker);
//         vm.deal(attacker, 100 ether);
//         vm.expectRevert();
//         arb.getFlashloanWithSubmarine(
//             WETH, 1 ether, path, exchRoute, pools, salt
//         );
//         vm.stopPrank();
//     }

//     function testSlippageProtection() public {
//         bytes32 salt = bytes32(uint256(1));
//         address[] memory path = new address[](3);
//         path[0] = WETH;
//         path[1] = BRETT;
//         path[2] = WETH;
        
//         uint8[] memory exchRoute = new uint8[](2);
//         exchRoute[0] = 1; // PancakeV3
//         exchRoute[1] = 0; // UniV2
        
//         address[] memory pools = new address[](2);
//         pools[0] = UNI_V3_POOL;
//         pools[1] = UNI_V2_POOL;

//         // Mock extreme price movement
//         vm.mockCall(
//             UNI_V2_POOL,
//             abi.encodeWithSelector(bytes4(keccak256("getReserves()"))),
//             abi.encode(uint112(1e18), uint112(1e6), uint32(block.timestamp))
//         );

//         bytes32 commitment = keccak256(abi.encode(
//             WETH, 1 ether, path, exchRoute, pools, salt, address(this)
//         ));
//         arb.commit(commitment);

//         vm.expectRevert();
//         arb.getFlashloanWithSubmarine(
//             WETH, 1 ether, path, exchRoute, pools, salt
//         );
//     }

//     function testSandwichAttack() public {
//         bytes32 salt = bytes32(uint256(1));
//         address[] memory path = new address[](3);
//         path[0] = WETH;
//         path[1] = BRETT;
//         path[2] = WETH;
        
//         uint8[] memory exchRoute = new uint8[](2);
//         exchRoute[0] = 1; // PancakeV3
//         exchRoute[1] = 0; // UniV2
        
//         address[] memory pools = new address[](2);
//         pools[0] = UNI_V3_POOL;
//         pools[1] = UNI_V2_POOL;

//         // Front-run attempt
//         vm.startPrank(attacker);
//         vm.deal(attacker, 100 ether);
//         vm.expectRevert();
//         arb.getFlashloanWithSubmarine(
//             WETH, 1 ether, path, exchRoute, pools, salt
//         );
//         vm.stopPrank();

//         // Our protected transaction
//         bytes32 commitment = keccak256(abi.encode(
//             WETH, 1 ether, path, exchRoute, pools, salt, address(this)
//         ));
//         arb.commit(commitment);
        
//         vm.roll(block.number + 1);
//         arb.getFlashloanWithSubmarine(
//             WETH, 1 ether, path, exchRoute, pools, salt
//         );
//     }
// }
// 