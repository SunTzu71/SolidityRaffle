
# Raffle Smart Contract

A decentralized lottery system built on Ethereum using Chainlink VRF for verifiable randomness and Chainlink Automation for automated execution.

## Overview

This smart contract implements a trustless lottery system where:
- Players can enter by paying an entrance fee
- Winners are selected randomly using Chainlink VRF
- The lottery automatically runs at regular intervals using Chainlink Automation
- The entire prize pool is transferred to the winner

## Features

- Fair and verifiable random winner selection
- Automated lottery execution
- Configurable entrance fee and time interval
- Protection against entries during winner selection
- Full transparency with on-chain transactions

## Technical Details

### Key Components

- **Chainlink VRF v2.5**: Provides verifiable random numbers for winner selection
- **Chainlink Automation**: Handles automated lottery execution
- **State Management**: Uses enum to track lottery states (Open/Calculating)

### Main Functions

- `enterRaffle()`: Allows players to enter the lottery by paying the entrance fee
- `checkUpkeep()`: Verifies if the lottery needs to run
- `performUpkeep()`: Initiates the winner selection process
- `fulfillRandomWords()`: Processes the random number and selects winner

### View Functions

- `getEntranceFee()`: Returns required entrance fee
- `getRaffleState()`: Returns current lottery state
- `getRecentWinner()`: Returns address of last winner
- `getPlayer()`: Returns player address at specific index
- `getLastTimeStamp()`: Returns timestamp of last lottery completion
- `getNumberOfPlayers()`: Returns current number of players

## Requirements

- Solidity ^0.8.19
- Chainlink VRF Subscription
- Chainlink Automation Registration

## Security Features

- Immutable state variables for critical parameters
- Custom error messages for better gas efficiency
- State checks to prevent invalid operations
- Protection against failed transfers

## Events

- `RaffleEntered`: Emitted when a player enters
- `WinnerPicked`: Emitted when a winner is selected
- `RequestedRaffleWinner`: Emitted when random number is requested

## License

This project is licensed under the MIT License.
