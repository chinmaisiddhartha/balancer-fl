//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../lib/forge-std/src/Script.sol";
import "../contracts/Arb.sol";
import "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

contract RunArbitrageScript is Script {
    Arbitrage public arbitrage;
    address constant DEPLOYED_CONTRACT = 0x7A8aB0187eB080b66919f8166e0e91EB16667557;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0xB1a03EdA10342529bBF8EB700a06C60441fEf25d;
    address constant PANCAKE_POOL = 0x17A3Ad8c74c4947005aFEDa9965305ae2EB2518a;
    address constant UNI_V2_POOL = 0xC16F5d5C0a2C0784EfaFEDf28B934a9F0bA21CD7;
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
        pools[0] = UNI_V2_POOL;
        pools[1] = PANCAKE_POOL;

        bytes32 salt = bytes32(uint256(block.timestamp));
        bytes32 commitment = keccak256(abi.encode(
            WETH,
            0.01 ether,
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
            0.01 ether,
            path,
            exchRoute,
            pools,
            salt
        );

        vm.stopBroadcast();
    }
}
