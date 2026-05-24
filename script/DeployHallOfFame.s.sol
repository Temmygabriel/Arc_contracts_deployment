// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/HallOfFame.sol";

contract DeployHallOfFame is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        HallOfFame deployed = new HallOfFame();
        vm.stopBroadcast();
        console.log("HallOfFame deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
