# System contract addresses (L1)

Gravity's protocol runtime lives at **fixed addresses** in the `0x1625F0000`–`0x1625F5xxx` range, deployed at genesis (can't be redeployed; changes need a hardfork). Addresses are the full 20-byte form, e.g. `0x0000000000000000000000000001625F4000`; the short `0x1625F4000` is the same value. Source: [Galxe/gravity_chain_core_contracts](https://github.com/Galxe/gravity_chain_core_contracts) (`src/foundation/SystemAddresses.sol`).

## Contracts a dapp calls

| Address | Contract | Use it to… |
| --- | --- | --- |
| `0x1625F4000` | **NativeOracle** | Read verified cross-chain events / JWKs / DNS / prices, or register a callback — see [`native-oracle.md`](native-oracle.md) |
| `0x1625F4002` | **OracleRequestQueue** | Pay for an on-demand oracle data request |
| `0x1625F4001` | **JWKManager** | JWKs for keyless (OAuth) accounts |
| `0x1625F1000` | **Timestamp** | Microsecond-precision on-chain time |
| `0x1625F1003` | **RandomnessConfig** | Check whether randomness is enabled — see [`randomness.md`](randomness.md) |
| `0x1625F2000` | **Staking** | Stake G for governance (any holder) |
| `0x1625F3000` | **Governance** | Proposal lifecycle |
| `0x1625F5001` | **BlsPopVerifyPrecompile** | Verify BLS12-381 proof-of-possession (pubkey 48B + PoP 96B → bool) |

For safe randomness you don't call a contract at all — read `block.prevrandao`.

## Protocol-internal (you won't call these directly)

Driven by the consensus engine / governance; listed so you recognize them. Full purpose docs are in the source repo.

- **Consensus** `0x1625F0000` SystemCaller · `0x1625F0001` Genesis
- **Runtime config** `0x1625F1001` StakeConfig · `…1002` ValidatorConfig · `…1004` GovernanceConfig · `…1005` EpochConfig · `…1006` VersionConfig · `…1007` ConsensusConfig · `…1008` ExecutionConfig · `…1009` OracleTaskConfig · `…100A` OnDemandOracleTaskConfig
- **Staking/validator** `0x1625F2001` ValidatorManager · `…2002` DKG · `…2003` Reconfiguration · `…2004` Block · `…2005` PerformanceTracker
- **Precompile** `0x1625F5000` NativeMintPrecompile — authorized native G mint, callable only by system contracts like the [bridge receiver](token-bridge.md) (not by dapps)

## Importing in Solidity

```solidity
import { SystemAddresses } from "gravity-core/foundation/SystemAddresses.sol";
INativeOracle oracle = INativeOracle(SystemAddresses.NATIVE_ORACLE); // 0x1625F4000
```
Or hardcode the address — they're stable for the life of the chain.
