// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Bounty.sol";

contract DeployBounty is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        Bounty deployed = new Bounty();
        vm.stopBroadcast();
        console.log("Bounty deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
