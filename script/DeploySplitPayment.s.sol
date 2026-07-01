// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SplitPayment.sol";

contract DeploySplitPayment is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        SplitPayment deployed = new SplitPayment();
        vm.stopBroadcast();
        console.log("SplitPayment deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
