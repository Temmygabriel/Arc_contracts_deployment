// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MoodRing.sol";

contract DeployMoodRing is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        MoodRing deployed = new MoodRing();
        vm.stopBroadcast();
        console.log("MoodRing deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
