// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Recommended fixed-height pattern for value-bearing Gravity randomness.
// Read alongside references/randomness.md.
//
// The schedule is fixed at deployment:
//   1. Entries close at `entryCloseBlock`.
//   2. The randomness comes from the later `randomnessBlock`.
//   3. Anyone can finalize, but every attempt reads that same fixed height.
//
// Participants and the target height cannot change after the randomness becomes known,
// so reverting and retrying finalize() cannot produce a different winner.

library GravityRandomnessByHeight {
    address internal constant RANDOMNESS_BY_HEIGHT =
        0x00000000000000000000000000000001625f5002;

    error RandomnessLookupFailed();

    /// Query one fixed block height. The precompile expects a raw ABI word with no selector.
    function atHeight(uint256 blockNumber)
        internal
        view
        returns (bool found, bytes32 randomness)
    {
        (bool ok, bytes memory output) =
            RANDOMNESS_BY_HEIGHT.staticcall(abi.encode(blockNumber));
        if (!ok || output.length != 64) revert RandomnessLookupFailed();

        uint256 foundWord;
        (foundWord, randomness) = abi.decode(output, (uint256, bytes32));
        found = foundWord == 1;
    }
}

contract FixedHeightRaffle {
    uint256 public immutable entryCloseBlock;
    uint256 public immutable randomnessBlock;

    address[] public tickets;
    address public winner;
    bool public finalized;

    error InvalidSchedule();
    error EntryClosed();
    error DrawNotReady();
    error AlreadyFinalized();
    error NoTickets();
    error RandomnessUnavailable();

    /// `entryBlocks` sets the entry window. `revealDelayBlocks` must leave the
    /// randomness block strictly after entries close.
    constructor(uint256 entryBlocks, uint256 revealDelayBlocks) {
        if (entryBlocks == 0 || revealDelayBlocks == 0) revert InvalidSchedule();
        entryCloseBlock = block.number + entryBlocks;
        randomnessBlock = entryCloseBlock + revealDelayBlocks;
    }

    /// Entries are frozen before the target block's randomness is produced.
    function enter() external /* payable: charge the ticket price */ {
        if (block.number >= entryCloseBlock) revert EntryClosed();
        tickets.push(msg.sender);
    }

    /// Permissionless finalization is safe because both the tickets and randomness
    /// height are fixed. A reverted retry computes the same winner.
    function finalize() external {
        if (finalized) revert AlreadyFinalized();
        if (block.number < randomnessBlock) revert DrawNotReady();
        if (tickets.length == 0) revert NoTickets();

        (bool found, bytes32 randomness) =
            GravityRandomnessByHeight.atHeight(randomnessBlock);
        if (!found || randomness == bytes32(0)) revert RandomnessUnavailable();

        winner = tickets[uint256(randomness) % tickets.length];
        finalized = true;

        // In production, let `winner` claim in a separate call. Do not let a
        // recipient-controlled callback revert finalization.
    }
}
