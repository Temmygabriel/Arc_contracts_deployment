// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PayrollStream.sol";

contract DeployPayrollStream is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        PayrollStream deployed = new PayrollStream();
        vm.stopBroadcast();
        console.log("PayrollStream deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
