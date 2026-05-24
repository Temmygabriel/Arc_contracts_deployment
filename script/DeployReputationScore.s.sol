// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ReputationScore.sol";

contract DeployReputationScore is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        ReputationScore deployed = new ReputationScore();
        vm.stopBroadcast();
        console.log("ReputationScore deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
