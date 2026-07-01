// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/FreelanceEscrow.sol";

contract DeployFreelanceEscrow is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        FreelanceEscrow deployed = new FreelanceEscrow();
        vm.stopBroadcast();
        console.log("FreelanceEscrow deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
