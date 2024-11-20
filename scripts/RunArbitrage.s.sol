//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../lib/forge-std/src/Script.sol";
import "../contracts/Arb.sol";
import "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

contract RunArbitrageScript is Script {
    Arbitrage public arbitrage;
    address constant DEPLOYED_CONTRACT = 0x7A8aB0187eB080b66919f8166e0e91EB16667557;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
    address constant PANCAKE_POOL = 0x404E927b203375779a6aBD52A2049cE0ADf6609B;
    address constant UNI_V2_POOL = 0x75CC10fdcEa4b7D13c115ABB08240ac9c9Be6f2f;
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
        exchRoute[0] = 0;
        exchRoute[1] = 2;

        address[] memory pools = new address[](2);
        pools[0] = PANCAKE_POOL;
        pools[1] = UNI_V2_POOL;

        bytes32 salt = bytes32(uint256(block.timestamp));
        bytes32 commitment = keccak256(abi.encode(
            WETH,
            1.8 ether,
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
            1.8 ether,
            path,
            exchRoute,
            pools,
            salt
        );

        vm.stopBroadcast();
    }
}
