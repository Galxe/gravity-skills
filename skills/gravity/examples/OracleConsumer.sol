// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Example: consume the Gravity native oracle (0x1625F4000) two ways —
//   (A) pull: read a record on demand
//   (B) push: receive a callback the instant new data is recorded
//
// See references/native-oracle.md for the full ABI and semantics.

interface INativeOracle {
    struct DataRecord {
        uint64  recordedAt;   // 0 = record does not exist
        uint256 blockNumber;
        bytes   data;
    }
    function getRecord(uint32 sourceType, uint256 sourceId, uint128 nonce)
        external view returns (DataRecord memory);
    function getLatestNonce(uint32 sourceType, uint256 sourceId)
        external view returns (uint128);
    function isSyncedPast(uint32 sourceType, uint256 sourceId, uint128 nonce)
        external view returns (bool);
}

interface IOracleCallback {
    function onOracleEvent(
        uint32 sourceType,
        uint256 sourceId,
        uint128 nonce,
        bytes calldata payload
    ) external returns (bool shouldStore);
}

contract OracleConsumer is IOracleCallback {
    // Full 20-byte form of 0x1625F4000.
    INativeOracle constant ORACLE =
        INativeOracle(0x0000000000000000000000000001625f4000);

    // Source we care about. Example: PRICE_FEED type, some source id.
    uint32  constant SOURCE_TYPE = 3;       // 0=BLOCKCHAIN 1=JWK 2=DNS 3=PRICE_FEED
    uint256 constant SOURCE_ID   = 1;

    // NativeOracle is the only address allowed to invoke onOracleEvent.
    address constant SYSTEM_ORACLE = 0x0000000000000000000000000001625F4000;

    event LatestPayload(uint128 nonce, bytes data);

    // ----- (A) PULL: read the most recent record on demand --------------------
    function readLatest() external view returns (uint128 nonce, bytes memory data) {
        nonce = ORACLE.getLatestNonce(SOURCE_TYPE, SOURCE_ID);
        require(nonce != 0, "no records yet");
        INativeOracle.DataRecord memory r = ORACLE.getRecord(SOURCE_TYPE, SOURCE_ID, nonce);
        require(r.recordedAt != 0, "record missing");
        return (nonce, r.data);
    }

    // Guard: only act once the oracle has synced past a known checkpoint.
    function isFresh(uint128 atLeast) external view returns (bool) {
        return ORACLE.isSyncedPast(SOURCE_TYPE, SOURCE_ID, atLeast);
    }

    // ----- (B) PUSH: NativeOracle calls this when a matching record lands ------
    // Registered by Governance via setCallback(SOURCE_TYPE, SOURCE_ID, address(this)).
    // IMPORTANT:
    //   * keep this cheap & bounded — it runs under a fixed gas limit; gasLimit 0 = skipped.
    //   * a revert here is CAUGHT (emits CallbackFailed) and does NOT undo the oracle write,
    //     so never rely on revert to abort recording.
    function onOracleEvent(
        uint32 sourceType,
        uint256 sourceId,
        uint128 nonce,
        bytes calldata payload
    ) external returns (bool shouldStore) {
        require(msg.sender == SYSTEM_ORACLE, "only NativeOracle");
        require(sourceType == SOURCE_TYPE && sourceId == SOURCE_ID, "wrong source");

        emit LatestPayload(nonce, payload);
        // ... decode `payload` per the sourceType and update your own state here ...

        // return true  -> let NativeOracle also store the payload (default)
        // return false -> you've stored what you need; skip NativeOracle storage
        return true;
    }
}
