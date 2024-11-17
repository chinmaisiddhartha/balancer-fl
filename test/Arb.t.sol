// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Arbitrage} from "../contracts/Arb.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import  "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@pancakeswap/v3-core/contracts/interfaces/IPancakeV3Pool.sol";

contract ArbitrageTest is Test {
    Arbitrage public arb;
    address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CBETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    address constant WHALE = 0xB33FC0B28ECA45dcc710Bc6B429bb1a26132141c;
    
    // Pool addresses
    address constant PANCAKE_POOL = 0xF6C0A374a483101e04EF5F7Ac9Bd15d9142BAC95;
    address constant UNI_V2_POOL = 0x41d160033C222E6f3722EC97379867324567d883;
    address constant UNI_V3_POOL = 0x4C36388bE6F416A29C8d8Eee81C771cE6bE14B18;

    // Events for tracking
    event CallbackReceived(address pool, uint256 amount0Delta, uint256 amount1Delta);
    
    function setUp() public {
        // Fork at specific block for consistent testing
        uint256 forkBlock = 22493668;
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), forkBlock);
        
        arb = new Arbitrage();
        
        // Label addresses for better trace output
        vm.label(address(arb), "Arbitrage");
        vm.label(BALANCER_VAULT, "Balancer Vault");
        vm.label(WETH, "WETH");
        vm.label(CBETH, "CBETH");
        vm.label(PANCAKE_POOL, "PancakeV3 Pool");
        vm.label(UNI_V2_POOL, "UniV2 Pool");
        
        // Setup initial balances
        deal(WETH, address(arb), 2 ether);
        deal(CBETH, address(arb), 1000 * 1e6);
    }

    function testCallbackAuthentication() public {
        // Test unauthorized callback
        vm.expectRevert("Unauthorized callback");
        vm.prank(address(0x1234));
        arb.uniswapV3SwapCallback(100, 200, "");
        
        // Test authorized callback from PancakeV3
        bytes memory data = abi.encode(WETH, CBETH, 1 ether);
        vm.prank(PANCAKE_POOL);
        arb.pancakeV3SwapCallback(100, 200, data);
        
        // Test authorized callback from UniV3
        vm.prank(UNI_V3_POOL);
        arb.uniswapV3SwapCallback(100, 200, data);
    }

    function testFlashLoanWithMultipleRoutes() public {
        uint256 flashAmount = 1 ether;
        
        // Test PancakeV3 -> UniV2 route
        address[] memory path1 = new address[](3);
        path1[0] = WETH;
        path1[1] = CBETH;
        path1[2] = WETH;
        
        uint8[] memory route1 = new uint8[](2);
        route1[0] = 2; // PancakeV3
        route1[1] = 0; // UniV2
        
        address[] memory pools1 = new address[](2);
        pools1[0] = PANCAKE_POOL;
        pools1[1] = UNI_V2_POOL;

        uint256 gasBefore = gasleft();
        arb.getFlashloan(WETH, flashAmount, path1, route1, pools1);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for PancakeV3 -> UniV2", gasUsed);

        // Test UniV3 -> PancakeV3 route
        uint8[] memory route2 = new uint8[](2);
        route2[0] = 1; // UniV3
        route2[1] = 2; // PancakeV3
        
        address[] memory pools2 = new address[](2);
        pools2[0] = UNI_V3_POOL;
        pools2[1] = PANCAKE_POOL;

        gasBefore = gasleft();
        arb.getFlashloan(WETH, flashAmount, path1, route2, pools2);
        gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for UniV3 -> PancakeV3", gasUsed);
    }

    function testMEVResistance() public {
        // Simulate frontrunning attempt
        address attacker = address(0x1337);
        vm.startPrank(attacker);
        vm.deal(attacker, 100 ether);
        
        // Try to manipulate pool price before arbitrage
        bytes memory data = abi.encode(WETH, CBETH, 5 ether);
        vm.expectRevert();
        IPancakeV3Pool(PANCAKE_POOL).swap(
            attacker,
            true,
            int256(5 ether),
            uint160(1 << 159), // Changed from uint160(1 << 160) to uint160(1 << 159)
            data
        );
        
        vm.stopPrank();
    }

    function testFlashLoanGasOptimization() public {
        uint256[] memory flashAmounts = new uint256[](3);
        flashAmounts[0] = 1 ether;
        flashAmounts[1] = 5 ether;
        flashAmounts[2] = 10 ether;
        
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = CBETH;
        path[2] = WETH;
        
        uint8[] memory route = new uint8[](2);
        route[0] = 2;
        route[1] = 0;
        
        address[] memory pools = new address[](2);
        pools[0] = PANCAKE_POOL;
        pools[1] = UNI_V2_POOL;

        for(uint i = 0; i < flashAmounts.length; i++) {
            uint256 gasBefore = gasleft();
            try arb.getFlashloan(WETH, flashAmounts[i], path, route, pools) {
                uint256 gasUsed = gasBefore - gasleft();
                emit log_named_uint("Flash amount", flashAmounts[i]);
                emit log_named_uint("Gas used", gasUsed);
            } catch {
                emit log_named_uint("Failed flash amount", flashAmounts[i]);
            }
        }
    }

    function testSlippageProtection() public {
        uint256 flashAmount = 1 ether;
        
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = CBETH;
        path[2] = WETH;
        
        uint8[] memory route = new uint8[](2);
        route[0] = 2;
        route[1] = 0;
        
        address[] memory pools = new address[](2);
        pools[0] = PANCAKE_POOL;
        pools[1] = UNI_V2_POOL;

        // Simulate extreme price movement
        vm.mockCall(
            PANCAKE_POOL,
            abi.encodeWithSelector(IPancakeV3PoolState.slot0.selector),
            abi.encode(uint160(1 << 159), 0, 0, 0, 0, 0, true) // Changed from uint160(1 << 160) to uint160(1 << 159)
        );

        vm.expectRevert("Insufficient output amount");
        arb.getFlashloan(WETH, flashAmount, path, route, pools);
    }
}