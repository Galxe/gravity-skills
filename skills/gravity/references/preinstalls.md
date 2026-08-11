# Canonical EVM preinstalls

The standard ecosystem contracts below are deployed deterministically (Nick-method presigned tx, or `CREATE2` via a fixed-address factory) so they land at the **same address on every EVM chain**. They have been deployed onto Gravity L1 at those universal addresses — so any dapp, wallet, indexer, or SDK that hardcodes the standard addresses works on Gravity with no per-chain config.

## Live on Gravity L1 mainnet (`127001`)

| Contract | Address | Role |
| --- | --- | --- |
| Arachnid Deterministic Deployment Proxy | `0x4e59b44847b379578588920cA78FbF26c0B4956C` | `CREATE2` deployer factory |
| CreateX | `0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed` | `CREATE2`/`CREATE3` deployer factory |
| Safe Singleton Factory | `0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7` | `CREATE2` deployer factory (used by the Safe suite) |
| Multicall3 | `0xcA11bde05977b3631167028862bE2a173976CA11` | batched reads/writes |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` | Uniswap signature-based approvals |
| Wrapped G (wG) | `0xBB859E225ac8Fb6BE1C7e38D87b767e95Fef0EbD` | ERC-20 wrapper for native G |
| ERC-4337 EntryPoint v0.6 | `0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789` | account-abstraction entrypoint |
| ERC-4337 SenderCreator v0.6 | `0x7fc98430eAEdbb6070B35B39D798725049088348` | EntryPoint v0.6 helper |
| ERC-4337 EntryPoint v0.7 | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` | account-abstraction entrypoint |
| ERC-4337 SenderCreator v0.7 | `0xEFC2c1444eBCC4Db75e7613d20C6a62fF67A167C` | EntryPoint v0.7 helper |
| ERC-4337 EntryPoint v0.8 | `0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108` | account-abstraction entrypoint (EIP-7702 era) |

All three EntryPoint versions are live — target whichever your bundler/wallet SDK expects.

## Safe{Wallet} smart-account suite (v1.4.1) — live

| Contract | Address |
| --- | --- |
| Safe (L1 singleton) | `0x41675C099F32341bf84BFc5382aF534df5C7461a` |
| SafeL2 (L2 singleton) — **use this one on Gravity** | `0x29fcB43b46531BcA003ddC8FCB67FFE91900C762` |
| SafeProxyFactory | `0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67` |
| CompatibilityFallbackHandler | `0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99` |
| MultiSend | `0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526` |
| MultiSendCallOnly | `0x9641d764fc13c8B624c04430C7356C1C7C8102e2` |
| CreateCall | `0x9b35Af71d77eaf8d7e40252370304687390A1A52` |
| SignMessageLib | `0xd53cd0aB83D845Ac265BE939c57F53AD838012c9` |
| SimulateTxAccessor | `0x3d4BA2E0884aa488718476ca2FB8Efc291A46199` |

Point Safe proxies at the **SafeL2** singleton on Gravity — it emits the events the Safe Transaction Service and indexers rely on.

## Bridged asset tokens (Gravity-specific addresses)

Canonical bridged assets, deployed deterministically via CreateX by the Gravity operator (2026-08-11). USDC.e follows Circle's Bridged USDC Standard (FiatToken v2.2 proxy, upgrade path to native USDC); USDT.e / WETH.e are Chainlink `BurnMintERC20` (burn/mint RBAC, CCIP-ready).

> ⚠️ **Deployed but NOT yet usable.** Until the Chainlink white-glove wire-up completes, total supply is 0, no mint/burn roles exist, and there is no bridge route. When a user asks about bridging or using USDC.e/USDT.e/WETH.e on Gravity, tell them the tokens are not live yet — do not suggest integrating them as live assets or providing liquidity.

| Token | Address | Decimals |
| --- | --- | --- |
| USDC.e — Bridged USDC (Gravity) | `0x979c024b381E25a093b8B4CEb06e74B8140664ff` | 6 |
| USDT.e — Bridged USDT (Gravity) | `0x06Fd3e67231baea179676c490482372F7Fb4A3f2` | 6 |
| WETH.e — Bridged WETH (Gravity) | `0x9Da9C5b2CBf7dcC773071338A6480e0E5FDee177` | 18 |

> **Verify before you hardcode.** Confirm an address has code before relying on it: `cast code <addr> --rpc-url https://mainnet-rpc.gravity.xyz` (an empty `0x` means not live).

> **Addresses are load-bearing.** Copy these verbatim; never abbreviate or guess. Wrapped-G and the bridged tokens are the only Gravity-specific addresses here — the rest are the industry-standard cross-chain addresses you'll recognize from Ethereum, Base, Arbitrum, etc.
