# Bridge G from Gravity L1 to Ethereum (Chainlink CCIP)

Turns **native G on Gravity L1** into **ERC-20 G on Ethereum**, 1:1. One transaction on Gravity; the CCIP fee is paid in native G; nothing to do on Ethereum. The reverse of the canonical bridge in [`token-bridge.md`](token-bridge.md) (Ethereum → Gravity, native oracle).

```
Gravity L1                                     Chainlink CCIP              Ethereum
caller ──bridge(recipient, amount){value}──► GravityGSender
                                               ├─ amount ──► 0x…dEaD
                                               └─ fee ─────► Router → OnRamp ──► OffRamp → Router → EthereumGMinter
                                                                                                └─ G.mint(recipient, amount)
```

**Using it as a user/script?** See [`../examples/bridge-g-to-ethereum.md`](../examples/bridge-g-to-ethereum.md) (cast, viem, Solidity).

## Addresses

| Chain | Contract | Address |
| --- | --- | --- |
| Gravity L1 (`127001`) | `GravityGSender` — call this | `0x40011DF49B772a70b171712f36AA59E1FCdCE62F` |
| Ethereum (`1`) | `EthereumGMinter` — mints on delivery | `0xE0a7F6938a1748a715302480668BaB90de7d90a6` |
| Ethereum (`1`) | G ERC-20 | `0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649` |

Both are verified (Gravity Blockscout / Sourcify, Etherscan).

## Interface (`GravityGSender`)

```solidity
interface IGravityGSender {
    /// CCIP fee in wei of native G for this exact deposit. Does not check pause state.
    function quoteBridge(address recipient, uint256 amount) external view returns (uint256 fee);

    /// Send msg.value >= amount + fee. `amount` goes to 0x…dEaD, `fee` to CCIP,
    /// the rest is refunded to msg.sender in the same tx. Reverts as a whole on any failure.
    function bridge(address recipient, uint256 amount) external payable returns (bytes32 messageId);

    // read-only state
    function totalDeposited() external view returns (uint256);
    function totalDepositLimit() external view returns (uint256);
    function lastDepositId() external view returns (uint256);
    function paused() external view returns (bool);

    event GDeposited(uint256 indexed depositId, address indexed depositor, address indexed recipient,
                     uint256 amount, bytes32 messageId, uint256 fee);
    event GTransferredToDead(uint256 indexed depositId, uint256 amount);
}
```

On Ethereum, `EthereumGMinter` emits `GCredited(uint256 indexed depositId, address indexed recipient, uint256 amount, bytes32 indexed messageId)` (topic0 `0x9e0eaf472b1f905a4405cdb324b14e7a5c35e96e6722b6d178316d4b42230d80`) when the G is minted. `credited(depositId)` returns `true` afterwards.

`GDeposited` topic0: `0x66cf7b5ac550957863596635ebc11e5ea5577f4a9296d7cc3fe4487a2a595351`.

## Reverts (nothing is sent when these happen)

| Selector | Error | Meaning |
| --- | --- | --- |
| `0x7040b58c` | `InsufficientValue(provided, required)` | `msg.value < amount + fee`; re-quote and add a buffer |
| `0x1d3eb3de` | `TotalDepositLimitExceeded(remaining, requested)` | the bridge's cumulative limit has less room than `amount` |
| `0xd93c0665` | `EnforcedPause()` | bridge paused by its owner |
| `0x2c5211c6` | `InvalidAmount()` | `amount == 0` |
| `0x8e4c8aa6` | `InvalidAddress(recipient)` | `recipient == address(0)` |
| `0xaf73b0b2` | `RefundFailed(caller, refund)` | caller is a contract that cannot receive native G; overpaid amount could not be refunded. Send exactly `amount + fee` or add `receive()` |

Limits are adjustable by the owner and change over time — read `totalDepositLimit() - totalDeposited()` on-chain instead of hardcoding a number.

## Fees, gas, timing

- **CCIP fee** is in native G and independent of `amount`; it mostly pays for execution on Ethereum, so it follows Ethereum gas prices. Always call `quoteBridge` just before sending and add a buffer (e.g. +10%); the excess is refunded.
- **Gas on Gravity:** about **370k** for a direct EOA call (more when called through a Safe or another contract).
- **Latency:** CCIP waits for Gravity finality (fast BFT) then executes on Ethereum. Usually seconds to a few minutes; the first mainnet transfer was minted 11 s after the Gravity tx.
- **Tracking:** take `messageId` from the return value or `GDeposited`, then `https://ccip.chain.link/msg/<messageId>`. Done when `GCredited` appears on Ethereum.

## Things to get right

- **Irreversible.** After a successful `bridge`, the G is at `0x…dEaD`; there is no refund or cancel.
- **`recipient` is an Ethereum address.** Default to the user's own EOA. A contract wallet (Safe, AA account) on Gravity is not necessarily deployed or owned by the same party at the same address on Ethereum — ask for an explicit Ethereum recipient.
- **Delivery failures are retried, not lost.** If minting fails on Ethereum (pause, limits), CCIP marks the message failed; it is re-executed once the cause is fixed and is credited exactly once. Do not bridge again to "retry" — that sends a second, separate deposit.
- **Calling from a contract:** `msg.sender` is your contract; it receives the refund (needs `receive()`), and the CCIP message records `GravityGSender` as the sender, not your contract.

## Using Chainlink CCIP directly (Gravity → Ethereum)

For your own cross-chain messages (not G bridging), Gravity is a standard CCIP chain. Ethereum → Gravity G bridging is the native oracle, not CCIP.

| Network | EVM chain ID | CCIP chain selector | CCIP Router |
| --- | ---: | ---: | --- |
| Gravity Mainnet | `127001` | `2988178761202034333` | `0x492641F648a4986844848E0beFE66D14817bCE34` |
| Ethereum | `1` | `5009297550715157269` | `0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D` |

- On Gravity: build a `Client.EVM2AnyMessage` with `receiver = abi.encode(ethereumReceiver)`, `feeToken = address(0)` to pay in native G (the Router wraps it into wG `0xBB859E225ac8Fb6BE1C7e38D87b767e95Fef0EbD`), and `extraArgs` with an explicit `gasLimit` for your receiver. Call `router.getFee(selector, msg)` then `router.ccipSend{value: fee}(selector, msg)`. **Send exactly `fee`:** with native fees the Router keeps the whole `msg.value`.
- On Ethereum: inherit `CCIPReceiver(router)` and check `message.sourceChainSelector == 2988178761202034333` and `abi.decode(message.sender, (address))` equals your Gravity sender.
- A **chain selector is not a chain ID.** Source of truth: the [Chainlink CCIP directory for Gravity](https://docs.chain.link/ccip/directory/mainnet/chain/gravity-mainnet).
- USDC.e / USDT.e / WETH.e on Gravity are not CCIP-live yet (see [`preinstalls.md`](preinstalls.md)); only arbitrary messages are.
