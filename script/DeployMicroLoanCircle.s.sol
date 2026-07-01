// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MicroLoanCircle.sol";

contract DeployMicroLoanCircle is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        MicroLoanCircle deployed = new MicroLoanCircle();
        vm.stopBroadcast();
        console.log("MicroLoanCircle deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
