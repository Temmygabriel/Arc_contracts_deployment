// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/QuestBoard.sol";

contract DeployQuestBoard is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        QuestBoard deployed = new QuestBoard();
        vm.stopBroadcast();
        console.log("QuestBoard deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
