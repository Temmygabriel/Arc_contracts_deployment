// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ArbitratedEscrow.sol";

contract DeployArbitratedEscrow is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        ArbitratedEscrow deployed = new ArbitratedEscrow();
        vm.stopBroadcast();
        console.log("ArbitratedEscrow deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
