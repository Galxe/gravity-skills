# Safe on-chain randomness

On Gravity, **`block.prevrandao` is safe randomness** — a fresh per-block value the validator set computes collectively via DKG + a Weighted Verifiable Unpredictable Function (WVUF), inherited from Aptos's randomness design. It's unpredictable and **unbiasable**: no proposer or sub-threshold coalition can grind or pick it (unlike Ethereum L1, where `prevrandao` is the beacon RANDAO a proposer knows a slot ahead).

## Use it

```solidity
uint256 rand = block.prevrandao;            // opcode 0x44
uint256 dieRoll = (block.prevrandao % 6) + 1;
```

- It's `0` when randomness is disabled or not yet available — guard against `0` if your logic must not run without it. (Whether it's enabled is in `RandomnessConfig` at `0x1625F1003`: `variant == V2` means on.)
- Don't fall back to `blockhash` / `block.timestamp` / `block.number` for value-bearing randomness — those are the grindable footguns this replaces.

## Look up randomness by block height

From the Alpha hardfork onward, contracts can query a block's header `mix_hash` / `prev_randao` through the read-only `randomness_by_height` precompile:

```text
0x00000000000000000000000000000001625f5002
```

The precompile uses a raw fixed-size ABI, **without a Solidity function selector**:

- Input: one 32-byte ABI word containing `uint256 blockNumber`.
- Output: 64 bytes encoding `(uint256 found, bytes32 randomness)`.
- An unknown or future height returns `(0, bytes32(0))` instead of reverting.

```solidity
library GravityRandomness {
    address internal constant RANDOMNESS_BY_HEIGHT =
        0x00000000000000000000000000000001625f5002;

    error RandomnessLookupFailed();

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
```

`found` reports whether the requested block/header was available; it does not prove that a non-zero Gravity randomness value existed. Check both `found` and `randomness != bytes32(0)` when zero is not valid for your application. Do not treat a pre-Alpha header's `mix_hash` as Gravity protocol randomness.

The current gas policy charges 4,000 gas for the current block, future misses within the `uint64` height range, and the most recent 86,400 ancestor blocks (about eight hours at three blocks per second), and 20,000 gas for older historical lookups. These values are hardfork-adjustable.

Historical randomness is already public once its block exists. If it will select a winner or allocate value, freeze the eligible participants and other inputs before the chosen future block height, then finalize against that fixed height after the block is produced. Do not let participants choose their inputs after seeing the value.

## Prevent selective-revert retries ("test-and-abort")

**Direct use is fine when no one can profit from a re-roll** — cosmetic rolls, NPC behaviour, or sampling where every outcome is equivalent to the caller. Just read `block.prevrandao`.

**When the caller can profit** (a raffle, a rare-trait mint, or any participant payout), an externally callable one-transaction draw can be exploited. The draw contract does not need to contain any rollback logic: an attacker can wrap it in another contract and revert from the outer call after inspecting the result.

```solidity
interface IRaffle {
    function draw() external;
    function winner() external view returns (address);
}

contract RetryUntilWin {
    error Lost();

    function tryDraw(IRaffle raffle) external {
        raffle.draw();
        if (raffle.winner() != address(this)) revert Lost();
    }
}
```

EVM transactions are atomic. If `tryDraw()` reverts, every state change, log, and transfer made by its nested `raffle.draw()` call is also discarded. This is a **transaction-level revert**, not a chain rollback or fork: the failed transaction can remain in the canonical block and still consumes gas. The attacker retries in a later block for a fresh `prevrandao`; only a winning attempt is allowed to commit. The random value remains unpredictable and unbiasable, but the attacker selectively accepts which block's value reaches state.

This attack requires all of the following:

- A participant-controlled contract can call the draw.
- It can determine whether the result is favourable before the top-level transaction finishes.
- A retry can use a different random value or otherwise change the result.

Choose a defence that matches the trust model:

- **Trusted operator:** restrict `draw()` to a trusted role such as `onlyOwner`, which prevents participants from placing it inside their own reverting call stack. The operator must call once and accept the result. Do not make an unhandled callback or push payment to participant-controlled code during the draw; record the result first and use a pull-based claim so a recipient cannot revert the draw.
- **Fixed future height:** freeze all participants and inputs before a chosen future block, then let anyone finalize using `randomness_by_height` for that fixed height. A reverted retry reads the same value and cannot re-roll; do not accept new inputs after the value becomes public.
- **Trustless high-value draw:** use participant **commit-reveal** or a dedicated **VRF** such as Chainlink VRF when neither an operator nor a fixed-height design provides the required guarantees.

Aptos prevents wrapping at the VM level: randomness is callable only from a `#[randomness]` **private entry** function whose result must commit. The EVM has no equivalent general guard, so the contract design must remove the caller's ability to inspect and selectively reject fresh outcomes.

See [`../examples/RandomnessConsumer.sol`](../examples/RandomnessConsumer.sol) for the owner-restricted pattern.

## How the value reaches the EVM

For the curious / verifying against a release — the Aptos consensus randomness becomes EVM `prevRandao` via:

1. **Consensus decides it** — WVUF shares aggregate into a `Randomness` once enough weight combines (`gravity-sdk`: `consensus/src/rand/rand_gen/rand_store.rs` → `WVUF::aggregate`; `rand_manager.rs`).
2. **Attached to the block** — `state_computer.rs` (~L452): `randomness.map(|r| Random::from_bytes(r.randomness()))` → `ExternalBlockMeta.randomness`.
3. **Handed to Reth** — `bin/gravity_node/src/reth_cli.rs` (~L241) sets both `prev_randao` and `randomness` from the *same* 32 bytes (`B256::ZERO` when absent).
4. **Sealed** — pipe-exec sets `mix_hash = prev_randao` (`gravity-reth`: `crates/pipe-exec-layer-ext-v2/execute/src/lib.rs`).
5. **Surfaced** — Reth sets EVM `prevrandao = header.mix_hash()` for post-Merge specs (`crates/ethereum/evm/src/lib.rs`), which opcode `0x44` reads.

It's also queryable off-chain from a node: `GET /dkg/randomness/{block_number}`.
