// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Confession.sol";

contract DeployConfession is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        Confession deployed = new Confession();
        vm.stopBroadcast();
        console.log("Confession deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
