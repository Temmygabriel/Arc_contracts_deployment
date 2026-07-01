// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SupplierPaymentRelease.sol";

contract DeploySupplierPaymentRelease is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        SupplierPaymentRelease deployed = new SupplierPaymentRelease();
        vm.stopBroadcast();
        console.log("SupplierPaymentRelease deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
