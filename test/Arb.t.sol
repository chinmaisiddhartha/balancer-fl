// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Arbitrage} from "../contracts/Arb.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

contract ArbitrageTest is Test {
    Arbitrage public arb;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    
    // Pool addresses
    address constant POOL_1 = 0x41d160033C222E6f3722EC97379867324567d883;
    address constant POOL_2 = 0x4C36388bE6F416A29C8d8Eee81C771cE6bE14B18;
    
    // address constant WHALE = 0xB33FC0B28ECA45dcc710Bc6B429bb1a26132141c; // WETH 
    address constant WHALE = 0x9643f8d57b8992B5f0b9a8A5f0e19B4c74b41CA9; // USDC, USDbC
    address attacker = address(0xBEEF);

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 23169135);
        arb = new Arbitrage();
        
        vm.label(address(arb), "Arbitrage");
        vm.label(WETH, "WETH");
        vm.label(USDC, "USDC");
        
        vm.deal(WHALE, 100 ether);
        deal(USDC, WHALE, 10000e6);
        vm.startPrank(WHALE);
        IERC20(USDC).transfer(address(arb), 1000e6);
        vm.stopPrank();
        vm.txGasPrice(100 gwei);
    }

    function testCallbackAuthentication() public {
        vm.stopPrank();  // Clear any existing pranks
        
        // Test unauthorized callback
        vm.expectRevert();
        vm.prank(address(0x1234));
        arb.uniswapV3SwapCallback(100, 200, "");
    
        // Test authorized transaction
        vm.startPrank(address(this), address(this));
        bytes32 salt = bytes32(uint256(1));
        address[] memory path = new address[](3);
        path[0] = USDC;
        path[1] = WETH;
        path[2] = USDC;
        
        uint8[] memory exchRoute = new uint8[](2);
        exchRoute[0] = 0;
        exchRoute[1] = 1;
        
        address[] memory pools = new address[](2);
        pools[0] = POOL_1;
        pools[1] = POOL_2;
    
        bytes32 commitment = keccak256(abi.encode(
            USDC, 3897e6, path, exchRoute, pools, salt, address(this)
        ));
        arb.commit(commitment);
    
        vm.roll(block.number + 1);
        arb.getFlashloanWithSubmarine(
            USDC, 3897e6, path, exchRoute, pools, salt
        );
        vm.stopPrank();
    }

    function testFlashLoanWithMultipleRoutes() public {
        vm.startPrank(address(this), address(this));
        bytes32 salt = bytes32(uint256(1));
        address[] memory path = new address[](3);
        path[0] = USDC;
        path[1] = WETH;
        path[2] = USDC;
        
        // Test PancakeV3 -> UniV2 route
        uint8[] memory route1 = new uint8[](2);
        route1[0] = 0;
        route1[1] = 1;
        
        address[] memory pools1 = new address[](2);
        pools1[0] = POOL_1;
        pools1[1] = POOL_2;

        bytes32 commitment1 = keccak256(abi.encode(
            USDC, 3897e6, path, route1, pools1, salt, address(this)
        ));
        arb.commit(commitment1);

        uint256 gasBefore = gasleft();
        vm.roll(block.number + 1);
        arb.getFlashloanWithSubmarine(
            USDC, 3897e6, path, route1, pools1, salt
        );
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for PancakeV3 -> UniV2", gasUsed);

        // Test UniV2 -> PancakeV3 route
        bytes32 salt2 = bytes32(uint256(2));
        uint8[] memory route2 = new uint8[](2);
        route2[0] = 1;
        route2[1] = 0;
        
        address[] memory pools2 = new address[](2);
        pools2[0] = POOL_2;
        pools2[1] = POOL_1;

        bytes32 commitment2 = keccak256(abi.encode(
            USDC, 10000e6, path, route2, pools2, salt2, address(this)
        ));
        arb.commit(commitment2);

        gasBefore = gasleft();
        vm.roll(block.number + 2);
        arb.getFlashloanWithSubmarine(
            USDC, 10000e6, path, route2, pools2, salt2
        );
        gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for UniV2 -> PancakeV3", gasUsed);
        vm.stopPrank();
    }

    function testFlashLoanGasOptimization() public {
        vm.startPrank(address(this), address(this));  
        
        uint256[] memory flashAmounts = new uint256[](4);
        flashAmounts[0] = 10000e6 ;
        flashAmounts[1] = 11070e6;
        flashAmounts[2] = 3897e6; 
        flashAmounts[3] = 25000e6;
        
        address[] memory path = new address[](3);
        path[0] = USDC;
        path[1] = WETH;
        path[2] = USDC;
        
        uint8[] memory route = new uint8[](2);
        route[0] = 0;
        route[1] = 1;
        
        address[] memory pools = new address[](2);
        pools[0] = POOL_1;
        pools[1] = POOL_2;
    
        for(uint i = 0; i < flashAmounts.length; i++) {
            bytes32 salt = bytes32(uint256(i + 1));
            bytes32 commitment = keccak256(abi.encode(
                USDC, flashAmounts[i], path, route, pools, salt, address(this)
            ));
            arb.commit(commitment);
    
            uint256 gasBefore = gasleft();
            vm.roll(block.number + i + 1);
            try arb.getFlashloanWithSubmarine(
                USDC, flashAmounts[i], path, route, pools, salt
            ) {
                uint256 gasUsed = gasBefore - gasleft();
                emit log_named_uint("Flash amount", flashAmounts[i]);
                emit log_named_uint("Gas used", gasUsed);
            } catch {
                emit log_named_uint("Failed flash amount", flashAmounts[i]);
            }
        }
        vm.stopPrank();
    }
    

    function testPrivateMempoolProtection() public {
        bytes32 salt = bytes32(uint256(1));
        address[] memory path = new address[](3);
        path[0] = USDC;
        path[1] = WETH;
        path[2] = USDC;
        
        uint8[] memory exchRoute = new uint8[](2);
        exchRoute[0] = 0;
        exchRoute[1] = 1;
        
        address[] memory pools = new address[](2);
        pools[0] = POOL_1;
        pools[1] = POOL_2;

        bytes32 commitment = keccak256(abi.encode(
            USDC, 6837e6, path, exchRoute, pools, salt, address(this)
        ));
        arb.commit(commitment);
  
        // Test gas price requirement
        vm.txGasPrice(1 gwei);
        vm.expectRevert("Low priority fee");
        arb.getFlashloanWithSubmarine(USDC, 6837e6, path, exchRoute, pools, salt);

        // Test direct EOA requirement
        vm.txGasPrice(100 gwei);
        address contractCaller = address(0xBEEF);
        vm.startPrank(address(this), contractCaller); // msg.sender != tx.origin
        vm.expectRevert("No flashbots");
        arb.getFlashloanWithSubmarine(USDC, 6837e6, path, exchRoute, pools, salt);
        vm.stopPrank();
        
        // Test success case with correct conditions
        vm.roll(block.number + 1);
        vm.startPrank(address(this), address(this)); // msg.sender == tx.origin
        arb.getFlashloanWithSubmarine(USDC, 6837e6, path, exchRoute, pools, salt);

    }
}
