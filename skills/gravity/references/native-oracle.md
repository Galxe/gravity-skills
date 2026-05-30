# Native Oracle (`0x1625F4000`)

A protocol-native data store. After validators reach consensus on an external fact, the consensus engine writes it on-chain. Dapps **read** it or get a **push callback**. The [G token bridge](token-bridge.md) is built on it. Source: `gravity_chain_core_contracts/src/oracle/INativeOracle.sol`.

## Data model

Records are keyed by **`(sourceType, sourceId, nonce)`**:

- `sourceType` (`uint32`) — class of data, by convention: `0` BLOCKCHAIN (cross-chain EVM events), `1` JWK (OAuth keys), `2` DNS, `3` PRICE_FEED. New types need no upgrade.
- `sourceId` (`uint256`) — id within the type (e.g. source chain ID for BLOCKCHAIN).
- `nonce` (`uint128`) — starts at 1, strictly increases per source.

```solidity
struct DataRecord {
    uint64  recordedAt;   // 0 = record does not exist
    uint256 blockNumber;
    bytes   data;         // payload; encoding depends on sourceType
}
```

## Read

```solidity
interface INativeOracle {
    function getRecord(uint32 sourceType, uint256 sourceId, uint128 nonce)
        external view returns (DataRecord memory);
    function getLatestNonce(uint32 sourceType, uint256 sourceId) external view returns (uint128);
    function isSyncedPast(uint32 sourceType, uint256 sourceId, uint128 nonce) external view returns (bool);
}
```
Flow: `getLatestNonce` → `getRecord` → decode `record.data` per `sourceType`. `getRecord` returns `recordedAt == 0` if missing.

## Callbacks (get pushed instead of polling)

Implement `IOracleCallback`; **Governance** registers your contract for a source. NativeOracle then calls you the instant a matching record lands.

```solidity
interface IOracleCallback {
    function onOracleEvent(uint32 sourceType, uint256 sourceId, uint128 nonce, bytes calldata payload)
        external returns (bool shouldStore); // true = let NativeOracle store payload; false = you stored it
}
```

Rules to respect:
- Runs under a **fixed gas limit** (0 ⇒ skipped). Keep it cheap and bounded.
- A **revert is caught** — it does *not* undo the oracle write (emits `CallbackFailed`). Never rely on revert to abort.
- Resolution is 2-layer: a specialized callback per `(sourceType, sourceId)` overrides a default per `sourceType` (`setCallback` / `setDefaultCallback`, Governance-only).

Off-chain listeners can watch `DataRecorded(sourceType, sourceId, nonce, dataLength)`.

## On-demand requests — `OracleRequestQueue` (`0x1625F4002`)

For data the network isn't already streaming, pay for a one-off request; validators fulfill it and the result lands in NativeOracle.

```solidity
interface IOracleRequestQueue {
    function request(uint32 sourceType, uint256 sourceId, bytes calldata requestData)
        external payable returns (uint256 requestId); // requestData = type-specific param, e.g. a ticker
    function refund(uint256 requestId) external;       // reclaim fee after expiry if unfulfilled
}
```
`(sourceType, sourceId)` must be registered in `OnDemandOracleTaskConfig` (`0x1625F100A`).

> `record` / `recordBatch` are `SystemCaller`-only (the consensus engine writes data) — dapps can't call them.

See [`../examples/OracleConsumer.sol`](../examples/OracleConsumer.sol) for a worked read + callback consumer.
