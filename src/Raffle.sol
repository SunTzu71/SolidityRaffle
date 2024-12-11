// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {VRFConsumerBaseV2Plus} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title Raffle contract
 * @author Chris Hall
 * @notice This contract is a raffle contract
 * @dev Implements ChainLink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    // custom errors
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle_UpkeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState
    );

    //  Type declarations
    enum RaffleState {
        Open,
        Calculating
    }

    // State variables
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    bytes2 private immutable i_keyhash;
    uint32 private immutable i_callbackGasLimit;
    uint256 private i_subscriptionId;
    bytes32 private i_gasLane;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinatorV2,
        bytes32 gasLane, // keyHash
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.Open;
    }

    /**
     * function enterRaffle
     * @notice Enters the address that calls this function into the raffle
     * @dev Requires ETH payment equal to i_entranceFee to enter
     * @dev Only allows entry when raffle state is Open
     * @dev Adds msg.sender as payable address to players array
     * @dev Emits RaffleEntered event when successful
     */
    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if (s_raffleState != RaffleState.Open) {
            revert Raffle__NotOpen();
        }

        s_players.push(payable(msg.sender)); // need payable in order to send ETH to winner

        emit RaffleEntered(msg.sender);
    }

    /**
     * function checkUpkeep
     * @dev Used by Chainlink automation nodes to check if
     * @dev upkeep needs to be performed on the contract.
     * 1. Time interval passed between raffle runs
     * 2. Lottery is open
     * 3. Contract has ETH
     * 4. Your subscription has LINK
     * @param - ignored
     * @return upkeepNeeded Boolean indicating if upkeep is needed, and any data needed by performUpkeep
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view returns (bool upkeepNeeded, bytes memory /*performData*/) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool isOpen = s_raffleState == RaffleState.Open;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;

        return (upkeepNeeded, "");
    }

    /**
     * function performUpkeep
     * @dev Called by Chainlink Automation when upkeep is needed
     * @dev First checks if upkeep is actually needed,
     * @dev then requests random words from Chainlink VRF to pick winner
     * @dev Sets state to Calculating to prevent new entries during selection
     * @param - ignore
     */
    function performUpkeep(bytes calldata /*performData*/) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.Calculating;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        s_vrfCoordinator.requestRandomWords(request);
    }

    /**
     * @dev Called by ChainLink VRF when random words are ready
     * @dev Picks a random winner, awards prize money, and resets players list
     * @dev sets recent winner and RaffleState back to open
     * @param - ignored for now requestId
     * @param randomWords Array of random numbers supplied by Chainlink VRF
     */
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winnerIndex];
        s_recentWinner = winner;
        s_raffleState = RaffleState.Open;
        s_players = new address payable[](0);

        emit WinnerPicked(s_recentWinner);

        (bool success, ) = winner.call{value: address(this).balance}("");

        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * function getEntranceFee
     * @notice Returns the amount of ETH required to enter the raffle
     * @dev Returns immutable i_entranceFee state variable
     * @return uint256 Entrance fee amount in wei
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
