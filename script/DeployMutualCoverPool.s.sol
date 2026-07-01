// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MutualCoverPool.sol";

contract DeployMutualCoverPool is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        MutualCoverPool deployed = new MutualCoverPool();
        vm.stopBroadcast();
        console.log("MutualCoverPool deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
