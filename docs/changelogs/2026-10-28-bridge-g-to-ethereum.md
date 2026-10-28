# docs(gravity): bridge G from Gravity L1 to Ethereum (Chainlink CCIP)

## Background
The Gravity L1 → Ethereum G bridge went live on 2026-10-28. The skill still
said the bridge was one-way.

## Changes
- `references/bridge-g-to-ethereum.md`: addresses, `GravityGSender` interface
  and events, revert selectors, fees/gas/latency, tracking, caveats, and how to
  use Chainlink CCIP directly from Gravity to Ethereum (routers, selectors).
- `examples/bridge-g-to-ethereum.md`: cast, viem and Solidity integrations.
- `SKILL.md`, `references/token-bridge.md`, `examples/bridge-g-from-ethereum.md`:
  replace the one-way notes with pointers to the return bridge.

Dynamic limits are not documented as numbers; the reference names the
on-chain getters.

## Verification
All three new examples ran against a local Anvil fork of Gravity mainnet: the
cast recipe and viem script each produced a deposit and CCIP message ID; the
Solidity contract bridged with exact fee payment (392,243 gas). Existing
`tests/check_examples.py` passes (8 Solidity tests, 2 Bash recipes).
