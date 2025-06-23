// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {NftMarket} from "../src/NftMarket.sol";

contract NftMarketScript is Script {
    NftMarket public market;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        market = new NftMarket();

        vm.stopBroadcast();
    }
}
