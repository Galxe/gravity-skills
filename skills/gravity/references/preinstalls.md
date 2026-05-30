# Canonical EVM preinstalls

**Status: in progress — addresses known, not yet live on Gravity L1 mainnet.** The standard ecosystem contracts below are deployed deterministically (Nick-method presigned tx, or `CREATE2` via a fixed-address factory) so they land at the **same address on every EVM chain**. Deploying them onto Gravity L1 at those universal addresses is actively underway; the addresses are therefore already known and stable, but most are **not deployed on mainnet (`127001`) yet**.

> **Verify before you hardcode.** Until the rollout completes, check on-chain that an address actually has code before relying on it: `cast code <addr> --rpc-url https://mainnet-rpc.gravity.xyz` (or `eth_getCode`). An empty result (`0x`) means it isn't live yet — don't assume it's there just because it's listed here. As of this writing, none have landed on mainnet; treat every row as **planned** until you confirm otherwise.

## Canonical addresses (same on every EVM chain)

| Contract | Canonical address | Role |
| --- | --- | --- |
| Arachnid Deterministic Deployment Proxy | `0x4e59b44847b379578588920cA78FbF26c0B4956C` | `CREATE2` deployer factory |
| CreateX | `0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed` | `CREATE2`/`CREATE3` deployer factory |
| Safe Singleton Factory | `0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7` | `CREATE2` deployer factory (per-chain presigned) |
| Multicall3 | `0xcA11bde05977b3631167028862bE2a173976CA11` | batched reads/writes |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` | Uniswap signature-based approvals |
| Wrapped G (wG) | `0xBB859E225ac8Fb6BE1C7e38D87b767e95Fef0EbD` | ERC-20 wrapper for native G |
| ERC-4337 EntryPoint v0.6 | `0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789` | account-abstraction entrypoint |
| ERC-4337 EntryPoint v0.7 | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` | account-abstraction entrypoint |
| ERC-4337 EntryPoint v0.8 | `0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108` | account-abstraction entrypoint |

The deployer factories (Arachnid, CreateX, Safe SF) must land first because the rest are deployed *through* them (`CREATE2` with a known salt → known address). The Safe Singleton Factory is the slow one: it uses per-chain EIP-155-signed presigned txs that only the Safe team can publish, so EntryPoint v0.7/v0.8 (which deploy via it) are gated on that.

> **Addresses are load-bearing.** Copy these verbatim; never abbreviate or guess. Wrapped-G is the only Gravity-specific address here — the rest are the industry-standard cross-chain addresses you'll recognize from Ethereum, Base, Arbitrum, etc.
