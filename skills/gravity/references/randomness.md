# Safe on-chain randomness

On Gravity, **`block.prevrandao` is safe randomness** — a fresh per-block value the validator set computes collectively via DKG + a Weighted Verifiable Unpredictable Function (WVUF), inherited from Aptos's randomness design. It's unpredictable and **unbiasable**: no proposer or sub-threshold coalition can grind or pick it (unlike Ethereum L1, where `prevrandao` is the beacon RANDAO a proposer knows a slot ahead).

## Use it

```solidity
uint256 rand = block.prevrandao;            // opcode 0x44
uint256 dieRoll = (block.prevrandao % 6) + 1;
```

- It's `0` when randomness is disabled or not yet available — guard against `0` if your logic must not run without it. (Whether it's enabled is in `RandomnessConfig` at `0x1625F1003`: `variant == V2` means on.)
- Don't fall back to `blockhash` / `block.timestamp` / `block.number` for value-bearing randomness — those are the grindable footguns this replaces.

## Avoid test-and-abort

**Direct use is fine when no one can profit from a re-roll** — cosmetic rolls, NPC behaviour, sampling where every outcome is equivalent to the caller. Just read `block.prevrandao`.

**When the caller *can* profit** (a raffle, a rare-trait mint — any payout to a participant), a one-call draw is exploitable. An attacker wraps your `draw()` in their own contract, reverts the whole transaction whenever they lose, and retries next block for a *fresh* `prevrandao` — repeating until they win. The value is unbiasable, but the attacker chooses *which block's* value gets committed.

Aptos blocks this in the VM: randomness is only callable from a `#[randomness]` **private entry** function that nothing can wrap, so the result is always committed. **The EVM has no such guard** — any external function can be wrapped and reverted. The simple fix is to **restrict the draw to a trusted role** (e.g. `onlyOwner`): a participant can't wrap-and-abort a call they can't make, and the operator is trusted to draw once and accept the result.

> For a **trustless** high-value draw where you can't trust an operator, use participant **commit-reveal** or a dedicated **VRF** (e.g. Chainlink VRF) instead.

See [`../examples/RandomnessConsumer.sol`](../examples/RandomnessConsumer.sol) for the owner-restricted pattern.

## How the value reaches the EVM

For the curious / verifying against a release — the Aptos consensus randomness becomes EVM `prevRandao` via:

1. **Consensus decides it** — WVUF shares aggregate into a `Randomness` once enough weight combines (`gravity-sdk`: `consensus/src/rand/rand_gen/rand_store.rs` → `WVUF::aggregate`; `rand_manager.rs`).
2. **Attached to the block** — `state_computer.rs` (~L452): `randomness.map(|r| Random::from_bytes(r.randomness()))` → `ExternalBlockMeta.randomness`.
3. **Handed to Reth** — `bin/gravity_node/src/reth_cli.rs` (~L241) sets both `prev_randao` and `randomness` from the *same* 32 bytes (`B256::ZERO` when absent).
4. **Sealed** — pipe-exec sets `mix_hash = prev_randao` (`gravity-reth`: `crates/pipe-exec-layer-ext-v2/execute/src/lib.rs`).
5. **Surfaced** — Reth sets EVM `prevrandao = header.mix_hash()` for post-Merge specs (`crates/ethereum/evm/src/lib.rs`), which opcode `0x44` reads.

It's also queryable off-chain from a node: `GET /dkg/randomness/{block_number}`.
