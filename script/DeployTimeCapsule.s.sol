// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TimeCapsule.sol";

contract DeployTimeCapsule is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        TimeCapsule deployed = new TimeCapsule();
        vm.stopBroadcast();
        console.log("TimeCapsule deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
