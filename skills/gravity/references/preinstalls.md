# Canonical EVM preinstalls

The standard ecosystem contracts below are deployed deterministically (Nick-method presigned tx, or `CREATE2` via a fixed-address factory) so they land at the **same address on every EVM chain**. They have been deployed onto Gravity L1 at those universal addresses — so any dapp, wallet, indexer, or SDK that hardcodes the standard addresses works on Gravity with no per-chain config.

## Live on Gravity L1 mainnet (`127001`)

| Contract | Address | Role |
| --- | --- | --- |
| Arachnid Deterministic Deployment Proxy | `0x4e59b44847b379578588920cA78FbF26c0B4956C` | `CREATE2` deployer factory |
| CreateX | `0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed` | `CREATE2`/`CREATE3` deployer factory |
| Multicall3 | `0xcA11bde05977b3631167028862bE2a173976CA11` | batched reads/writes |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` | Uniswap signature-based approvals |
| Wrapped G (wG) | `0xBB859E225ac8Fb6BE1C7e38D87b767e95Fef0EbD` | ERC-20 wrapper for native G |
| ERC-4337 EntryPoint v0.6 | `0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789` | account-abstraction entrypoint |
| ERC-4337 SenderCreator v0.6 | `0x7fc98430eAEdbb6070B35B39D798725049088348` | EntryPoint v0.6 helper |

## Not yet live (gated on the Safe Singleton Factory)

| Contract | Address | Role |
| --- | --- | --- |
| Safe Singleton Factory | `0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7` | `CREATE2` deployer factory (per-chain presigned) |
| ERC-4337 EntryPoint v0.7 | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` | account-abstraction entrypoint |
| ERC-4337 SenderCreator v0.7 | `0xEFC2c1444eBCC4Db75e7613d20C6a62fF67A167C` | EntryPoint v0.7 helper |
| ERC-4337 EntryPoint v0.8 | `0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108` | account-abstraction entrypoint |

The Safe Singleton Factory uses per-chain EIP-155-signed presigned txs that only the Safe team can publish, so it can't be deployed permissionlessly. EntryPoint v0.7/v0.8 deploy *through* it (and SenderCreator v0.7 is created by the v0.7 constructor), so all three wait on it. **Use EntryPoint v0.6 for account abstraction today.**

> **Verify before you hardcode.** Confirm an address has code before relying on it: `cast code <addr> --rpc-url https://mainnet-rpc.gravity.xyz` (an empty `0x` means not live). The "not yet live" rows above will return `0x` until the Safe SF lands.

> **Addresses are load-bearing.** Copy these verbatim; never abbreviate or guess. Wrapped-G is the only Gravity-specific address here — the rest are the industry-standard cross-chain addresses you'll recognize from Ethereum, Base, Arbitrum, etc.
