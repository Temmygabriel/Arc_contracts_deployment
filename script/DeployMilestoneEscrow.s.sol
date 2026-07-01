// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MilestoneEscrow.sol";

contract DeployMilestoneEscrow is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        MilestoneEscrow deployed = new MilestoneEscrow();
        vm.stopBroadcast();
        console.log("MilestoneEscrow deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
