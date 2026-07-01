// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/RecurringPayment.sol";

contract DeployRecurringPayment is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        RecurringPayment deployed = new RecurringPayment();
        vm.stopBroadcast();
        console.log("RecurringPayment deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
