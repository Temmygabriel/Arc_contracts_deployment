// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MultiSigTreasury.sol";

contract DeployMultiSigTreasury is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        MultiSigTreasury deployed = new MultiSigTreasury();
        vm.stopBroadcast();
        console.log("MultiSigTreasury deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
