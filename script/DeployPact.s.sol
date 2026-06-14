// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Pact.sol";

contract DeployPact is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        Pact deployed = new Pact();
        vm.stopBroadcast();
        console.log("Pact deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
