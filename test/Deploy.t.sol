// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import {console} from "forge-std/Test.sol";
import {BaseTest} from "@kei.fi/testing-lib/BaseTest.sol";

import {DeployScript} from "script/Deploy.s.sol";

contract DeployTest is BaseTest, DeployScript {
    function setUp() public virtual override {
        super.setUp();
    }
}

contract DeployTest__run is DeployTest {
    struct ExpectDeployment {
        string name;
        address addr;
    }

    mapping(uint256 => ExpectDeployment[]) internal expected;

    function setUp() public virtual override {
        super.setUp();

        // forge test network
        expected[31337].push(ExpectDeployment("Counter", 0xEf286AbDF2Ac31D9ed831C01a2B8D16815567AD6));
        // abitrum network
        expected[42161].push(ExpectDeployment("Counter", 0x0000000000000000000000000000000000000000));
        // sepolia network
        expected[11155111].push(ExpectDeployment("Counter", 0x0000000000000000000000000000000000000000));
    }

    function assert_deployments() public view {
        ExpectDeployment[] memory deployments = expected[block.chainid];

        // first loop through and log all the addresses that are different generating a final hash to compare
        string memory errorMessage = "";
        for (uint256 i; i < deployments.length; i++) {
            address expectedDeployment = deployments[i].addr;
            address deployment = deployment[deployments[i].name];
            if (deployment != expectedDeployment) {
                errorMessage = string.concat(
                    errorMessage,
                    "\n",
                    deployments[i].name,
                    " changed. Current: ",
                    vm.toString(deployment),
                    " <> Expected: ",
                    vm.toString(expectedDeployment)
                );
            }
        }

        if (bytes(errorMessage).length > 0) {
            revert(errorMessage);
        }
    }

    function test_deploy() external {
        run();
        assert_deployments();
    }
}
