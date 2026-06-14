// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Beacon.sol";

contract DeployBeacon is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        Beacon deployed = new Beacon();
        vm.stopBroadcast();
        console.log("Beacon deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
