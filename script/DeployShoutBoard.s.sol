// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ShoutBoard.sol";

contract DeployShoutBoard is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        ShoutBoard deployed = new ShoutBoard();
        vm.stopBroadcast();
        console.log("ShoutBoard deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
