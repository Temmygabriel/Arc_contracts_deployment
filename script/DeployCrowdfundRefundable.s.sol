// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/CrowdfundRefundable.sol";

contract DeployCrowdfundRefundable is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        CrowdfundRefundable deployed = new CrowdfundRefundable();
        vm.stopBroadcast();
        console.log("CrowdfundRefundable deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
