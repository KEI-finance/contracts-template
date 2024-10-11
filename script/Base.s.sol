// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import {Script, console2, stdJson} from "forge-std/Script.sol";

abstract contract BaseScript is Script {
    using stdJson for string;

    struct DeployConfig {
        bytes32 salt;
    }

    address public deployer;
    DeployConfig internal config;
    mapping(string => address) public deployment;

    modifier record() {
        vm.startBroadcast(deployer);

        _;

        // only record deployments on non testnets
        vm.stopBroadcast();
    }

    function setUp() public virtual {
        uint256 privateKey;
        if (block.chainid == 31337) {
            (,privateKey) = makeAddrAndKey('DEPLOYER');
        } else {
            privateKey = vm.envUint(string.concat("PRIVATE_KEY_", vm.toString(block.chainid)));
        }
        deployer = vm.rememberKey(privateKey);
        loadConfig();
    }

    function getConfig() public view returns (DeployConfig memory) {
        return config;
    }

    function getAddress(string memory name) internal view returns (address) {
        return getAddress(name, "");
    }

    function getAddress(string memory name, bytes memory args) internal view returns (address) {
        bytes32 hash = hashInitCode(vm.getCode(name), args);
        return vm.computeCreate2Address(config.salt, hash);
    }

    function deploy(string memory name) internal returns (address addr) {
        return deploy(name, "", true, config.salt);
    }

    function deploy(string memory name, bytes32 salt) internal returns (address addr) {
        return deploy(name, "", true, salt);
    }

    function deploy(string memory name, bool deployIfMissing) internal returns (address addr) {
        return deploy(name, "", deployIfMissing, config.salt);
    }

    function deploy(string memory name, bool deployIfMissing, bytes32 salt) internal returns (address addr) {
        return deploy(name, "", deployIfMissing, salt);
    }

    function deploy(string memory name, bytes memory args) internal returns (address addr) {
        return deploy(name, args, true, config.salt);
    }

    function deploy(string memory name, bytes memory args, bytes32 salt) internal returns (address addr) {
        return deploy(name, args, true, salt);
    }

    function deploy(string memory name, bytes memory args, bool deployIfMissing, bytes32 salt) internal returns (address addr) {
        addr = getAddress(name, args);
        deployment[name] = addr;

        if (addr.code.length == 0) {
            require(deployIfMissing, string.concat('MISSING_CONTRACT_', name));

            bytes memory bytecode = abi.encodePacked(vm.getCode(name), args);

            assembly {
                addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
                if iszero(extcodesize(addr)) { revert(0, 0) }
            }
        }
    }

    function loadConfig() internal virtual {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/config.json");
        string memory json = vm.readFile(path);

        string memory key = string.concat(".", vm.toString(block.chainid));

        if (!vm.keyExists(json, key)) {
            key = string.concat(".11155111"); // use sepolia as a fallback
        }

//        config.salt = bytes32(json.readUint(string.concat(key, ".salt")));
    }
}
