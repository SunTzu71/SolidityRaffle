// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    /**
     * @notice Creates a Chainlink VRF subscription using the configuration from HelperConfig
     * @return subscriptionId The ID of the created subscription
     * @return vrfCoordinator The address of the VRF Coordinator contract
     */
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vfrCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subscroptionId, ) = createSubscription(
            vfrCoordinator,
            account
        );

        return (subscroptionId, vfrCoordinator);
    }

    /**
     * @notice Creates a Chainlink VRF subscription using the provided VRF Coordinator address
     * @param vrfCoordinator The address of the VRF Coordinator contract
     * @return subscriptionId The ID of the created subscription
     * @return vrfCoordinator The address of the VRF Coordinator contract used
     */
    function createSubscription(
        address vrfCoordinator,
        address account
    ) public returns (uint256, address) {
        console2.log("Creating subscription on chain id: ", block.chainid);
        vm.startBroadcast(account);
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
        address account = helperConfig.getConfig().account;

        fundSubscription(vrfCoordinator, subscriptionId, link, account);
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
        address linkToken,
        address account
    ) public {
        console2.log("Funding subscription: ", subscriptionId);
        console2.log("Using vrfCoordinator: ", vrfCoordinator);
        console2.log("On chain id: ", block.chainid);

        if (block.chainid == CHAIN_ID_LOCAL) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT * 100
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
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

contract AddConsumer is Script {
    /**
     * @notice Adds a consumer contract to a VRF subscription
     * @param ContractToAddToVrf The address of the contract to add as a consumer
     * @param vrfCoordinator The address of the VRF Coordinator contract
     * @param subscriptionId The ID of the subscription to add the consumer to
     * @dev Adds the specified contract as a consumer of the VRF subscription
     */
    function addConsumer(
        address ContractToAddToVrf,
        address vrfCoordinator,
        uint256 subscriptionId,
        address account
    ) public {
        console2.log("Adding consumer contract: ", ContractToAddToVrf);
        console2.log("To vrfCoordinator: ", vrfCoordinator);
        console2.log("On chain id: ", block.chainid);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            ContractToAddToVrf
        );
        vm.stopBroadcast();
    }

    /**
     * @notice Adds a consumer contract to a VRF subscription using configuration from HelperConfig
     * @param mostRecentlyDeployed The address of the contract to add as a consumer
     * @dev Retrieves subscription ID and VRF Coordinator from config and calls addConsumer
     */
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        addConsumer(
            mostRecentlyDeployed,
            vrfCoordinator,
            subscriptionId,
            account
        );
    }

    /**
     * @notice Required entry point for running the script that adds a consumer to a VRF subscription
     * @dev Gets most recently deployed Raffle contract and adds it as consumer
     */
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
