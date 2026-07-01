// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SavingsCircle.sol";

contract DeploySavingsCircle is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        SavingsCircle deployed = new SavingsCircle();
        vm.stopBroadcast();
        console.log("SavingsCircle deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
