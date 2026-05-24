// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TrustCircle.sol";

contract DeployTrustCircle is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        TrustCircle deployed = new TrustCircle();
        vm.stopBroadcast();
        console.log("TrustCircle deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
