// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/VestingVault.sol";

contract DeployVestingVault is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        VestingVault deployed = new VestingVault();
        vm.stopBroadcast();
        console.log("VestingVault deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
