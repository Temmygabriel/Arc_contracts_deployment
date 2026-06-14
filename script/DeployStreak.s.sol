// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Streak.sol";

contract DeployStreak is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        Streak deployed = new Streak();
        vm.stopBroadcast();
        console.log("Streak deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
