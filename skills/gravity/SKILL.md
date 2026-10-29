---
name: gravity
description: Reference for building smart contracts on and bridging to Gravity L1 (EVM-compatible Layer 1, chain ID 127001, native token G). Use when someone asks how to connect to Gravity (chain ID / RPC / explorer), bridge the G token from Ethereum (via cast, a wallet, or a contract), bridge native G from Gravity back to Ethereum via the Chainlink CCIP G bridge, use Chainlink CCIP between Gravity and Ethereum, read the native on-chain oracle or write an oracle callback, use safe on-chain randomness (block.prevrandao), find a system or bridge contract address, or which canonical EVM preinstalls (Multicall3, Permit2, CreateX, ERC-4337, Wrapped-G) exist. Covers Gravity Mainnet (127001) and Longevity Testnet (7771625); distinct from the legacy Alpha Mainnet L2 (Arbitrum Nitro, chain 1625).
metadata:
  author: gravity
  version: '0.1'
compatibility: Standard EVM tooling (Foundry/cast, Hardhat, viem, ethers, wagmi, any EVM wallet). Solidity ^0.8.30 for the system-contract interfaces.
---

# Gravity L1

Gravity is an **EVM-compatible Layer 1** (AptosBFT consensus + parallel EVM execution). For developers and users it behaves like Ethereum — same JSON-RPC, Solidity, wallets, and ecosystem addresses — with three protocol-native extras: a **verified on-chain oracle**, a **canonical G token bridge** from Ethereum, and **safe on-chain randomness**.

## Connect

| | |
| --- | --- |
| **Chain ID** | `127001` (testnet: `7771625`) |
| **Native token** | `G`, 18 decimals (gas + staking + governance) |
| **RPC** | `https://mainnet-rpc.gravity.xyz` |
| **Explorer** | `https://mainnet-explorer.gravity.xyz` (Blockscout) |
| **Add to wallet** | https://chainlist.org/chain/127001 |
| **G ERC-20 on Ethereum** | `0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649` (the token you bridge from) |

> The legacy **Alpha Mainnet (L2, Arbitrum Nitro, chain `1625`)** is a different, older network — don't confuse it with this L1. More: [`references/network-params.md`](references/network-params.md).

## What you might want to do

- **Bridge G from Ethereum** (cast / wallet / contract) → [`references/token-bridge.md`](references/token-bridge.md) + [`examples/bridge-g-from-ethereum.md`](examples/bridge-g-from-ethereum.md)
- **Bridge G from Gravity back to Ethereum** (Chainlink CCIP; cast / viem / contract), or send your own CCIP messages Gravity → Ethereum → [`references/bridge-g-to-ethereum.md`](references/bridge-g-to-ethereum.md) + [`examples/bridge-g-to-ethereum.md`](examples/bridge-g-to-ethereum.md)
- **Get safe randomness** → just read `block.prevrandao`. Details + the test-and-abort caveat: [`references/randomness.md`](references/randomness.md)
- **Read the native oracle / write a callback** → [`references/native-oracle.md`](references/native-oracle.md) + [`examples/OracleConsumer.sol`](examples/OracleConsumer.sol)
- **Use Multicall3 / Permit2 / CreateX / ERC-4337 (v0.6–v0.8) / Safe v1.4.1 / wG / bridged USDC.e·USDT.e·WETH.e** → live at their canonical addresses: [`references/preinstalls.md`](references/preinstalls.md)
- **Find a system contract address** → [`references/system-contracts.md`](references/system-contracts.md)

## The three native features at a glance

**Native oracle** (`0x1625F4000`) — the consensus engine writes verified external data (cross-chain events, OAuth JWKs, DNS, price feeds) on-chain. Contracts read it by `(sourceType, sourceId, nonce)` or register a callback. This is what the G bridge runs on.

**G token bridge** — lock G ERC-20 on Ethereum via `GBridgeSender`; native G is minted to you on Gravity after your Ethereum tx **finalizes** (~2 epochs, ≈13 min). No extra relayer to trust. The **way back** is a separate Chainlink CCIP bridge: call `GravityGSender.bridge` on Gravity (`0x40011DF49B772a70b171712f36AA59E1FCdCE62F`), pay the CCIP fee in native G, and ERC-20 G is minted on Ethereum, usually within seconds to minutes — see [`references/bridge-g-to-ethereum.md`](references/bridge-g-to-ethereum.md).

**Safe randomness** — each block's `block.prevrandao` is a DKG/WVUF value the validator set computes collectively: unpredictable and unbiasable (no proposer grinding). `0` when disabled/unavailable.

> **Addresses are load-bearing.** Copy hex addresses verbatim from the reference files; never abbreviate. If one is marked `TBA`/`blocked`, say so rather than inventing a value.
