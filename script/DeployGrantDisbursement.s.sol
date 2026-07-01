// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GrantDisbursement.sol";

contract DeployGrantDisbursement is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        GrantDisbursement deployed = new GrantDisbursement();
        vm.stopBroadcast();
        console.log("GrantDisbursement deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
