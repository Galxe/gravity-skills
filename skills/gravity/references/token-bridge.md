# Cross-chain G token bridge

Moves native **G** from **Ethereum** to **Gravity L1**: you lock G ERC-20 on Ethereum, validators reach consensus on the event, and native G is minted to you on Gravity. Security is the chain's own validator consensus + [native oracle](native-oracle.md) — no extra relayer to trust.

```
Ethereum                                Gravity L1
user → GBridgeSender (locks G)          GBridgeReceiver (mints native G)
          → GravityPortal.send()  ──emits MessageSent──► consensus relays ──► NativeOracle ──► receiver
```

> **One-way for now (Ethereum → Gravity only).** There is no user-facing path back yet — your G is locked on Ethereum with no withdraw function, so **treat bridged G as burned on the Ethereum side**. A Gravity → Ethereum return path is planned once the Chainlink integration lands.

> **Timing — wait for Ethereum finality.** G is minted on Gravity only after your Ethereum lock transaction is *finalized*, not merely mined. Under Ethereum's Casper FFG (Gasper) consensus, a block is finalized once the next two epochs are justified/finalized — 1 epoch = 32 slots × 12 s = 6.4 min, so finality is ~2 epochs (**≈13 min**, in practice ~13–19 min depending on where in the epoch your tx landed). Only then does the consensus engine relay the message and mint.

**Bridging as a user?** Use a wallet or `cast` — see [`../examples/bridge-g-from-ethereum.md`](../examples/bridge-g-from-ethereum.md). The rest of this file is the contract interface.

## Addresses

**Ethereum mainnet**
| Contract | Address |
| --- | --- |
| `GBridgeSender` (lock G here) | `0xE82c61Ac9Ec2041b493118051afa4F18a55dC876` |
| `GravityPortal` (message bus) | `0x76cf8526Fa9461e50B2c6702a7246ce6915f6E53` |
| G token (ERC-20) | `0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649` |

On Gravity, `GBridgeReceiver` (genesis-deployed) mints via the `NativeMintPrecompile` (`0x1625F5000`); it's an oracle callback and fires automatically — you don't call it.

## Bridging via `GBridgeSender`

```solidity
interface IGBridgeSender {
    // Lock `amount` G and bridge to `recipient` on Gravity. Approve this contract for G first.
    // msg.value must cover the portal fee (>= fee and <= 2*fee).
    function bridgeToGravity(uint256 amount, address recipient)
        external payable returns (uint128 messageNonce);

    // PREFERRED: approve + bridge in one tx via ERC-2612 permit — saves the separate
    // approve() transaction (lower gas, one signature instead of two txs).
    function bridgeToGravityWithPermit(uint256 amount, address recipient,
        uint256 deadline, uint8 v, bytes32 r, bytes32 s) external payable returns (uint128);

    function calculateBridgeFee(uint256 amount, address recipient) external view returns (uint256);
}
event TokensLocked(address indexed from, address indexed recipient, uint256 amount, uint128 indexed nonce);
```

> **Prefer `bridgeToGravityWithPermit`** when your client can sign an ERC-2612 permit: it folds the ERC-20 approval into the bridge call, so you pay one transaction instead of two (`approve` + `bridge`). The G token supports permit. Fall back to `approve` + `bridgeToGravity` only when signing a permit isn't practical.

Flow: `calculateBridgeFee` → sign a permit → `bridgeToGravityWithPermit{value: fee}(amount, recipient, deadline, v, r, s)` (or, without permit: `approve(sender, amount)` → `bridgeToGravity{value: fee}(amount, recipient)`). After your Ethereum tx **finalizes** (~13 min, see above), consensus relays it and the receiver emits `NativeMinted(recipient, amount, nonce)` on Gravity.

## GravityPortal — arbitrary messages (advanced)

`GBridgeSender` wraps `GravityPortal`, the generic Ethereum→Gravity message bus. Use it directly to send any message:

```solidity
interface IGravityPortal {
    function send(bytes calldata message) external payable returns (uint128 messageNonce);
    function calculateFee(uint256 messageLength) external view returns (uint256); // baseFee + len*feePerByte
}
event MessageSent(uint128 indexed nonce, uint256 indexed block_number, bytes payload);
```
Fee guard: `msg.value` must be `>= fee` (else `InsufficientFee`) and `<= 2*fee` (else `ExcessiveFee`).
