// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/VoiceVote.sol";

contract DeployVoiceVote is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        VoiceVote deployed = new VoiceVote();
        vm.stopBroadcast();
        console.log("VoiceVote deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
