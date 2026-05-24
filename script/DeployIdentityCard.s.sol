// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/IdentityCard.sol";

contract DeployIdentityCard is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        IdentityCard deployed = new IdentityCard();
        vm.stopBroadcast();
        console.log("IdentityCard deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
