# Network connection parameters

| | Mainnet (L1) | Longevity Testnet (L1) |
| --- | --- | --- |
| Chain ID | `127001` | `7771625` |
| Native token | `G` (18 decimals) | `G` (18 decimals) |
| RPC | `https://mainnet-rpc.gravity.xyz` | — |
| Explorer | `https://mainnet-explorer.gravity.xyz` (Blockscout) | — |
| Add to wallet | https://chainlist.org/chain/127001 | — |

Standard Ethereum JSON-RPC (`eth`, `net`, `web3`). Block time ~250 ms; epoch 2 hours. Testnet has the same architecture and system-contract layout as mainnet — use it before deploying.

> **Legacy Alpha Mainnet (L2)** is the older 2024 Arbitrum Nitro rollup, chain ID `1625` — a different network. Only use `1625` if you're explicitly targeting the legacy L2.

## Tooling config

```toml
# foundry.toml
[rpc_endpoints]
gravity = "https://mainnet-rpc.gravity.xyz"
```
```ts
// hardhat.config.ts
networks: { gravity: { url: "https://mainnet-rpc.gravity.xyz", chainId: 127001 } }
```
```ts
// viem
import { defineChain } from "viem";
export const gravity = defineChain({
  id: 127001,
  name: "Gravity",
  nativeCurrency: { name: "Gravity", symbol: "G", decimals: 18 },
  rpcUrls: { default: { http: ["https://mainnet-rpc.gravity.xyz"] } },
  blockExplorers: { default: { name: "Blockscout", url: "https://mainnet-explorer.gravity.xyz" } },
});
```

## Getting G for gas

You need native **G** to pay gas. Bridge it from Ethereum (see [`token-bridge.md`](token-bridge.md)), withdraw from a CEX, or migrate from Alpha Mainnet (L2). The G ERC-20 on **Ethereum mainnet** is `0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649`.
