// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Arbitrage} from "../contracts/Arb.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

contract ArbitrageTest is Test {
    Arbitrage public arb;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x1185cB5122Edad199BdBC0cbd7a0457E448f23c7;
    
    // Pool addresses
    address constant POOL_1 = 0x2C114787d52e9F080464dbed8e285e07EC4e120f;
    address constant POOL_2 = 0x52f38A65DAb3Cf23478cc567110BEC90162aB832;
    
    address constant WHALE = 0xB33FC0B28ECA45dcc710Bc6B429bb1a26132141c;
    address attacker = address(0xBEEF);

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 23428315);
        arb = new Arbitrage();
        
        vm.label(address(arb), "Arbitrage");
        vm.label(WETH, "WETH");
        vm.label(USDC, "USDC");
        
        vm.deal(WHALE, 100 ether);
        vm.startPrank(WHALE);
        IERC20(WETH).transfer(address(arb), 2 ether);
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
        path[0] = WETH;
        path[1] = USDC;
        path[2] = WETH;
        
        uint8[] memory exchRoute = new uint8[](2);
        exchRoute[0] = 1;
        exchRoute[1] = 3;
        
        address[] memory pools = new address[](2);
        pools[0] = POOL_1;
        pools[1] = POOL_2;
    
        bytes32 commitment = keccak256(abi.encode(
            WETH, 1 ether, path, exchRoute, pools, salt, address(this)
        ));
        arb.commit(commitment);
    
        vm.roll(block.number + 1);
        arb.getFlashloanWithSubmarine(
            WETH, 1 ether, path, exchRoute, pools, salt
        );
        vm.stopPrank();
    }

    function testFlashLoanWithMultipleRoutes() public {
        vm.startPrank(address(this), address(this));
        bytes32 salt = bytes32(uint256(1));
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = USDC;
        path[2] = WETH;
        
        // Test PancakeV3 -> UniV2 route
        uint8[] memory route1 = new uint8[](2);
        route1[0] = 1;
        route1[1] = 3;
        
        address[] memory pools1 = new address[](2);
        pools1[0] = POOL_1;
        pools1[1] = POOL_2;

        bytes32 commitment1 = keccak256(abi.encode(
            WETH, 1 ether, path, route1, pools1, salt, address(this)
        ));
        arb.commit(commitment1);

        uint256 gasBefore = gasleft();
        vm.roll(block.number + 1);
        arb.getFlashloanWithSubmarine(
            WETH, 1 ether, path, route1, pools1, salt
        );
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for PancakeV3 -> UniV2", gasUsed);

        // Test UniV2 -> PancakeV3 route
        bytes32 salt2 = bytes32(uint256(2));
        uint8[] memory route2 = new uint8[](2);
        route2[0] = 3;
        route2[1] = 1;
        
        address[] memory pools2 = new address[](2);
        pools2[0] = POOL_2;
        pools2[1] = POOL_1;

        bytes32 commitment2 = keccak256(abi.encode(
            WETH, 1 ether, path, route2, pools2, salt2, address(this)
        ));
        arb.commit(commitment2);

        gasBefore = gasleft();
        vm.roll(block.number + 2);
        arb.getFlashloanWithSubmarine(
            WETH, 1 ether, path, route2, pools2, salt2
        );
        gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for UniV2 -> PancakeV3", gasUsed);
        vm.stopPrank();
    }

    function testFlashLoanGasOptimization() public {
        vm.startPrank(address(this), address(this));  
        
        uint256[] memory flashAmounts = new uint256[](4);
        flashAmounts[0] = 0.845982 ether;
        flashAmounts[1] = 1 ether;
        flashAmounts[2] = 5 ether; 
        flashAmounts[3] = 10 ether;
        
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = USDC;
        path[2] = WETH;
        
        uint8[] memory route = new uint8[](2);
        route[0] = 1;
        route[1] = 3;
        
        address[] memory pools = new address[](2);
        pools[0] = POOL_1;
        pools[1] = POOL_2;
    
        for(uint i = 0; i < flashAmounts.length; i++) {
            bytes32 salt = bytes32(uint256(i + 1));
            bytes32 commitment = keccak256(abi.encode(
                WETH, flashAmounts[i], path, route, pools, salt, address(this)
            ));
            arb.commit(commitment);
    
            uint256 gasBefore = gasleft();
            vm.roll(block.number + i + 1);
            try arb.getFlashloanWithSubmarine(
                WETH, flashAmounts[i], path, route, pools, salt
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
        path[0] = WETH;
        path[1] = USDC;
        path[2] = WETH;
        
        uint8[] memory exchRoute = new uint8[](2);
        exchRoute[0] = 1;
        exchRoute[1] = 3;
        
        address[] memory pools = new address[](2);
        pools[0] = POOL_1;
        pools[1] = POOL_2;

        bytes32 commitment = keccak256(abi.encode(
            WETH, 1 ether, path, exchRoute, pools, salt, address(this)
        ));
        arb.commit(commitment);
  
        // Test gas price requirement
        vm.txGasPrice(1 gwei);
        vm.expectRevert("Low priority fee");
        arb.getFlashloanWithSubmarine(WETH, 1 ether, path, exchRoute, pools, salt);

        // Test direct EOA requirement
        vm.txGasPrice(100 gwei);
        address contractCaller = address(0xBEEF);
        vm.startPrank(address(this), contractCaller); // msg.sender != tx.origin
        vm.expectRevert("No flashbots");
        arb.getFlashloanWithSubmarine(WETH, 1 ether, path, exchRoute, pools, salt);
        vm.stopPrank();
        
        // Test success case with correct conditions
        vm.roll(block.number + 1);
        vm.startPrank(address(this), address(this)); // msg.sender == tx.origin
        arb.getFlashloanWithSubmarine(WETH, 1 ether, path, exchRoute, pools, salt);

    }
}
