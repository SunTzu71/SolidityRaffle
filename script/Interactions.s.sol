// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract CreateSubscription is Script {
    /**
     * @notice Creates a Chainlink VRF subscription using the configuration from HelperConfig
     * @return subscriptionId The ID of the created subscription
     * @return vrfCoordinator The address of the VRF Coordinator contract
     */
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        (uint256 subscriptionId, ) = createSubscription(vrfCoordinator);

        return (subscriptionId, vrfCoordinator);
    }

    /**
     * @notice Creates a Chainlink VRF subscription using the provided VRF Coordinator address
     * @param vrfCoordinator The address of the VRF Coordinator contract
     * @return subscriptionId The ID of the created subscription
     * @return vrfCoordinator The address of the VRF Coordinator contract used
     */
    function createSubscription(
        address vrfCoordinator
    ) public returns (uint256, address) {
        console2.log("Creating subscription on chain id: ", block.chainid);
        vm.startBroadcast();
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        console2.log("Subscription created with id: ", subscriptionId);
        console2.log(
            "Update your HelperConfig.s.sol file with the subscription id"
        );
        return (subscriptionId, vrfCoordinator);
    }

    /**
     * @notice Required entry point for running the script that creates a Chainlink VRF subscription
     */
    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether;

    /**
     * @notice Funds a VRF subscription using configuration from HelperConfig
     * @dev Retrieves VRF Coordinator, subscription ID and LINK token address from config
     * and calls fundSubscription with those parameters
     */
    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address link = helperConfig.getConfig().link;

        fundSubscription(vrfCoordinator, subscriptionId, link);
    }

    /**
     * @notice Funds a VRF subscription using the provided VRF Coordinator, subscription ID and LINK token address
     * @param vrfCoordinator The address of the VRF Coordinator contract
     * @param subscriptionId The ID of the subscription to fund
     * @param linkToken The address of the LINK token contract
     * @dev Uses mock VRF coordinator for local chains, real LINK token transfer for other chains
     */
    function fundSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken
    ) public {
        console2.log("Funding subscription: ", subscriptionId);
        console2.log("Using vrfCoordinator: ", vrfCoordinator);
        console2.log("On chain id: ", block.chainid);

        if (block.chainid == CHAIN_ID_LOCAL) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    /**
     * @notice Required entry point for running the script that funds a VRF subscription
     */
    function run() public {
        fundSubscriptionUsingConfig();
    }
}
