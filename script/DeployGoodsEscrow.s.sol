// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GoodsEscrow.sol";

contract DeployGoodsEscrow is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("RELAY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);
        GoodsEscrow deployed = new GoodsEscrow();
        vm.stopBroadcast();
        console.log("GoodsEscrow deployed at:", address(deployed));
        console.log("Deployer:", deployer);
    }
}
