// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Endorsement.sol";

contract DeployEndorsement is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        Endorsement deployed = new Endorsement();
        vm.stopBroadcast();
        console.log("Endorsement deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
