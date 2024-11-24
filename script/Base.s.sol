// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import {stdJson} from "forge-std/StdJson.sol";
import {BaseDeployScript} from "@kei.fi/testing-lib/BaseDeployScript.sol";

abstract contract BaseScript is BaseDeployScript {
    using stdJson for string;

    struct DeployConfig {
        // TODO update this
        address owner;
    }

    DeployConfig internal config;

    function loadConfig(string memory json, string memory key) internal virtual override {
        // TODO parse the config here to the config struct
        // config.owner = json.readAddress(string.concat(key, ".owner"));
    }
}
