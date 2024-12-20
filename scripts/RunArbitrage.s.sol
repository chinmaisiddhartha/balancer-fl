//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../lib/forge-std/src/Script.sol";
import {Arbitrage} from  "../contracts/Arb.sol";
import "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

contract RunArbitrageScript is Script {
    Arbitrage public arbitrage;
    address constant DEPLOYED_CONTRACT = 0x82B2c0D9AdbA9e1058a6C7de5987C979CCEA40e7;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x0d97F261b1e88845184f678e2d1e7a98D9FD38dE;
    address constant PANCAKE_POOL = 0xE745a591970e0Fa981204cf525E170a2B9e4fb93;
    address constant UNI_V2_POOL = 0xF65BB528cED09008603509c3fDa43e1cCfdDF935;
    uint256 constant MIN_PRIORITY_FEE = 3 gwei;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        uint256 baseFee = block.basefee;
        uint256 priorityFee = MIN_PRIORITY_FEE;
        uint256 gasPrice = baseFee + priorityFee;
        
        vm.txGasPrice(gasPrice);
        vm.startBroadcast(deployerPrivateKey);

        arbitrage = Arbitrage(payable(DEPLOYED_CONTRACT));
        
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = USDC;
        path[2] = WETH;

        uint8[] memory exchRoute = new uint8[](2);
        exchRoute[0] = 1;
        exchRoute[1] = 0;

        address[] memory pools = new address[](2);
        pools[0] = PANCAKE_POOL;
        pools[1] = UNI_V2_POOL;

        bytes32 salt = bytes32(uint256(block.timestamp));
        bytes32 commitment = keccak256(abi.encode(
            WETH,
            0.047728872 ether,
            path,
            exchRoute,
            pools,
            salt,
            deployer  // Using actual deployer address instead of msg.sender
        ));

        arbitrage.commit(commitment);
        console.log("Commitment submitted with gas price:", gasPrice);
        
        vm.roll(block.number + 1);

        arbitrage.getFlashloanWithSubmarine(
            WETH,
            0.047728872 ether,
            path,
            exchRoute,
            pools,
            salt
        );

        vm.stopBroadcast();
    }
}
