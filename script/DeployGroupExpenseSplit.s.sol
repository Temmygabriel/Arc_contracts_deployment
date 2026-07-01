// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GroupExpenseSplit.sol";

contract DeployGroupExpenseSplit is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        GroupExpenseSplit deployed = new GroupExpenseSplit();
        vm.stopBroadcast();
        console.log("GroupExpenseSplit deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
