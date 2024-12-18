// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    // VRF mock values
    uint96 public MOCK_BASE_FEE = 0.1 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    int256 public MOCK_WEI_PER_UNIT_LINK = 4e15;

    address public FOUNDRY_DEFAULT_SENDER =
        0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 public constant CHAIN_ID_SEPOLIA = 11155111;
    uint256 public constant CHAIN_ID_LOCAL = 31337;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfig;

    constructor() {
        networkConfig[CHAIN_ID_SEPOLIA] = getSepoliaEthConfig();
    }

    /**
     * @notice Retrieves network configuration based on chain ID
     * @dev Returns Sepolia config if valid coordinator exists for chain ID,
     * @dev returns Anvil mock config for local chain, otherwise reverts
     * @param chainId The blockchain network ID to get config for
     * @return NetworkConfig The network configuration for the specified chain
     */
    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (networkConfig[chainId].vrfCoordinator != address(0)) {
            return networkConfig[CHAIN_ID_SEPOLIA];
        } else if (chainId == CHAIN_ID_LOCAL) {
            return getCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    /**
     * @notice Returns network configuration for current chain
     * @dev Uses block.chainid to determine current network and get config
     * @return NetworkConfig struct containing network configuration parameters
     */
    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    /**
     * @notice Returns Sepolia testnet network configuration
     * @dev Contains hardcoded values for Sepolia VRF coordinator and parameters
     * @return NetworkConfig Configuration struct with Sepolia testnet settings
     */
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.1 ether, // 1e16
                interval: 30, // 30 seconds
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // https://docs.chain.link/vrf/v2-5/supported-networks - Sepolia testnet
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // https://docs.chain.link/vrf/v2-5/supported-networks - Sepolia testnet
                callbackGasLimit: 500000, // 500k
                subscriptionId: 0,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                account: 0x643315C9Be056cDEA171F4e7b2222a4ddaB9F88D // private key for sepolia testnet account - get from Metamask
            });
    }

    /**
     * @notice Returns local Anvil network configuration with mock contracts
     * @dev Deploys VRFCoordinator and Link token mocks if not already deployed
     * @dev Caches local config to avoid redeploying mocks
     * @dev Sets up mock contracts with test values and funds test account
     * @return NetworkConfig Configuration struct with local test settings
     */
    function getCreateAnvilConfig() public returns (NetworkConfig memory) {
        // Check if local network config is already set
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // Deploy VRF Coordinator Mock
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UNIT_LINK
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether, // 1e16
            interval: 30, // 30 seconds
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000, // 500k
            subscriptionId: 0,
            link: address(linkToken),
            account: FOUNDRY_DEFAULT_SENDER
        });
        vm.deal(localNetworkConfig.account, 100 ether);
        return localNetworkConfig;
    }
}
