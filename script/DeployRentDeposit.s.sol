// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/RentDeposit.sol";

contract DeployRentDeposit is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        RentDeposit deployed = new RentDeposit();
        vm.stopBroadcast();
        console.log("RentDeposit deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
