// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ServiceLevelBond.sol";

contract DeployServiceLevelBond is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        ServiceLevelBond deployed = new ServiceLevelBond();
        vm.stopBroadcast();
        console.log("ServiceLevelBond deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
