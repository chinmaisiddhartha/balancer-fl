// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "../lib/forge-std/src/Script.sol";
import {Arbitrage} from "../contracts/Arb.sol";

contract DeployScript is Script {
    function run() external {
        // Load environment variables
        string memory rpcUrl = vm.envString("BASE_RPC_URL");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Gas settings from environment or defaults
     
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        Arbitrage arbitrage = new Arbitrage();
        console.log("Arbitrage deployed to:", address(arbitrage));

        vm.stopBroadcast();
    }
}