// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Direct and trusted-operator consumption of Gravity's current-block randomness.
// Read alongside references/randomness.md.
//
// For any value-bearing draw, prefer RandomnessByHeightConsumer.sol: commit a future
// block height, freeze every outcome-affecting input, then finalize permissionlessly.
// The owner-restricted raffle below is only a fallback when operator trust is explicit;
// it prevents participant wrap-and-abort but still lets the operator choose when to draw.
//
// ── When DIRECT use is already safe ──────────────────────────────────────────
// If no participant can profit by re-running the draw, just read block.prevrandao:
//
//     uint256 r = block.prevrandao;   // 0x44; 0 if randomness is off/unavailable
//
// e.g. cosmetic rolls, PvE/NPC behaviour, sampling where every outcome is equivalent
// to the caller. No ceremony needed.
//
// ── The trap: "test-and-abort" ───────────────────────────────────────────────
// When the caller CAN profit (a raffle, a rare-trait mint, anything paying out to a
// participant), a draw() that ANYONE can call is exploitable. An attacker wraps it:
//
//     try raffle.draw() { if (raffle.winner() != me) revert(); } catch {}
//
// On a loss they revert the whole tx and retry next block for a fresh prevrandao,
// repeating until they win. The value is unbiasable, but the attacker controls *which*
// block's value gets committed.
//

contract Raffle {
    address public immutable owner;
    address[] public tickets;
    address public winner;
    bool public open = true;

    error NotOwner();
    error Closed();
    error NoTickets();
    error NoRandomness();

    constructor() {
        owner = msg.sender;
    }

    /// Anyone enters while the raffle is open.
    function enter() external /* payable: charge the ticket price */ {
        if (!open) revert Closed();
        tickets.push(msg.sender);
    }

    /// Trusted-operator fallback: participants cannot wrap this call and abort on a loss,
    /// but the owner is trusted to draw once and accept whatever comes out.
    function draw() external {
        if (msg.sender != owner) revert NotOwner();
        if (!open) revert Closed();
        if (tickets.length == 0) revert NoTickets();
        uint256 r = block.prevrandao;        // Gravity's safe randomness for this block
        if (r == 0) revert NoRandomness();   // randomness disabled / unavailable
        winner = tickets[r % tickets.length];
        open = false;
        // pay out `winner` here.
    }
}
