// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SkillBadge.sol";

contract DeploySkillBadge is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        SkillBadge deployed = new SkillBadge();
        vm.stopBroadcast();
        console.log("SkillBadge deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
