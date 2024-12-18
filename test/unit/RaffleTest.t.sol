// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    /**
     * @dev Initializes test setup with deployed Raffle contract and helper configuration.
     * Creates deployer, runs deployment, gets configuration parameters.
     * Sets up test player with starting balance.
     */
    function setUp() public {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    /**
     * Tests that raffle initializes in open state
     * Verifies raffle contract starts in the correct openstate
     * No setup needed as done in setUp()
     */
    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.Open);
    }

    /**
     * Tests that entering the raffle with insufficient payment reverts
     * Simulates user not paying required entrance fee
     * Expects transaction to revert with specific error
     * Verifies fee validation works correctly
     */
    function testRaffleRevertDidNotPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    /**
     * Tests recording of a player when they enter the raffle
     * Simulates player joining raffle with proper entrance fee
     * Verifies that player's address is correctly stored in array
     * Checks that recorded player matches the original player address
     */
    function testRaffleRecordPlayerEntered() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    /**
     * Tests that entering raffle emits event
     * Simulates player entering raffle with proper fee
     * Expects RaffleEntered event with correct player address
     * Verifies event emission works correctly
     */
    function testEnteringRaffleEmitsEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /**
     * Tests that entering raffle is not allowed while calculating
     * Simulates player entering raffle, advancing time, and triggering performUpkeep
     * Expects revert when trying to enter during calculation state
     * Verifies state transition and restriction logic works
     */
    function testDontAllowEnteringWhileCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /**
     * Tests checkUpkeep returns false with no balance
     * Sets up scenario where time has passed but contract has no balance
     * Expects checkUpkeep to return false since no funds available
     * Verifies balance requirement for upkeep works correctly
     */
    function testCheckUpKeepNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    /**
     * Tests that checkUpkeep returns false when raffle is not open
     * Simulates full raffle scenario with time passed and player entered
     * Expects checkUpkeep to return false since raffle is calculating
     * Verifies state checks in checkUpkeep work correctly
     */
    function testCheckUpKeepRaffleNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(raffleState == Raffle.RaffleState.Calculating);
        assert(upkeepNeeded == false);
    }

    /**
     * Tests performUpkeep succeeds when conditions are met
     * Simulates player entering raffle and time passing
     * Triggers performUpkeep and expects it to work
     * Verifies upkeep executes successfully when conditions are right
     */
    function testPerformUpKeepRunIfUpKeepTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
    }

    /**
     * Tests that performUpkeep reverts when conditions are not met
     * Sets up initial state variables and simulates player entering raffle
     * Expects revert with UpkeepNotNeeded error and correct parameters
     * Verifies performUpkeep validation works correctly
     */
    function testPerformUpKeepRevertsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep("");
    }

    /**
     * @dev Modifier that simulates entering the raffle and advancing time
     * Pranks as player to enter raffle with entrance fee
     * Advances blockchain time and block number
     * Executes modified function after setup
     */
    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    /**
     * Tests that performUpkeep updates state and emits request ID
     * Records logs during performUpkeep call to capture events
     * Extracts requestId from event logs and checks state changes
     * Verifies raffle state updates and valid requestId emitted
     */
    function testPerformUpkeepUpdatesRaffleStateEmitsRequestId() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1); // 0 = open, 1 = calculating
    }

    modifier skipFork() {
        if (block.chainid != CHAIN_ID_LOCAL) {
            return;
        }
        _;
    }

    /**
     * Tests that fulfillRandomWords reverts when called before upkeep
     * Takes a random request ID parameter simulating a completion request
     * Expects VRFCoordinator to revert the request as invalid
     * Verifies request validation and sequence enforcement works
     */
    function testFullfillRandomWordsAfterUpkeep(
        uint256 randomRequestId
    ) public raffleEntered skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    /**
     * Tests fulfillRandomWords picks winner and resets raffle state
     * Simulates multiple players entering raffle then picks winner
     * Adds additional players, triggers upkeep and fulfills random words
     * Verifies winner selection, prize distribution and state reset
     * Checks winner address, raffle state, balances and timestamps
     */
    function testFullfillRandomWordsPickWinnerResets()
        public
        raffleEntered
        skipFork
    {
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        uint256 prize = entranceFee * (additionalEntrants + 1);

        // Add additional players
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();

        // Get starting balances of all players
        address[] memory players = new address[](additionalEntrants + 1);
        uint256[] memory startingBalances = new uint256[](
            additionalEntrants + 1
        );

        players[0] = PLAYER;
        startingBalances[0] = PLAYER.balance;

        for (uint256 i = 0; i < additionalEntrants; i++) {
            players[i + 1] = address(uint160(i + 1));
            startingBalances[i + 1] = players[i + 1].balance;
        }

        // Perform upkeep and fulfill random words
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Get the winner
        address recentWinner = raffle.getRecentWinner();

        // Assertions
        assert(recentWinner != address(0));
        assert(raffle.getRaffleState() == Raffle.RaffleState.Open);
        assert(raffle.getLastTimeStamp() >= startingTimeStamp);
        assert(raffle.getNumberOfPlayers() == 0); // Should be 0 after reset

        // Verify winner received the prize
        bool winnerFound = false;
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == recentWinner) {
                assert(recentWinner.balance == startingBalances[i] + prize);
                winnerFound = true;
                break;
            }
        }
        assert(winnerFound); // Ensure winner was one of the players
    }
}
