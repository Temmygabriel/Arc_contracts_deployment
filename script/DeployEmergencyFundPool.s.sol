// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EmergencyFundPool.sol";

contract DeployEmergencyFundPool is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        EmergencyFundPool deployed = new EmergencyFundPool();
        vm.stopBroadcast();
        console.log("EmergencyFundPool deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
