# Bridge G from Ethereum → Gravity L1

Lock G on **Ethereum mainnet** via `GBridgeSender`; native G is minted to your recipient on **Gravity L1** once consensus relays the message. Addresses + interface: [`../references/token-bridge.md`](../references/token-bridge.md).

> **One-way (Ethereum → Gravity only)** for now — bridged G is locked on Ethereum with no return path yet, so treat it as burned on the Ethereum side. **Minting on Gravity waits for Ethereum finality (~13 min)**, not just for your tx to be mined.

```
GBridgeSender  0xE82c61Ac9Ec2041b493118051afa4F18a55dC876   (Ethereum)
G token        0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649   (Ethereum ERC-20, 18 decimals)
```

Every path is the same 3 steps: **(1)** quote the ETH fee, **(2)** approve the sender to spend your G, **(3)** call `bridgeToGravity{value: fee}(amount, recipient)`.

> **Gas tip:** if your client can sign an ERC-2612 permit, use **`bridgeToGravityWithPermit`** instead — it folds the approval into the bridge call, so you send **one** transaction instead of two (skip step 2). The `cast`/wallet flows below use the explicit `approve` for clarity.

## With `cast` (Foundry CLI)

```bash
SENDER=0xE82c61Ac9Ec2041b493118051afa4F18a55dC876
G=0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649
RPC=https://eth.llamarpc.com           # any Ethereum mainnet RPC
AMOUNT=$(cast to-wei 100)              # 100 G
TO=0xYourGravityAddress                # recipient on Gravity L1
ACCT=--account my-keystore             # or: --private-key $PK / --ledger

# 1. Quote the ETH portal fee
FEE=$(cast call $SENDER "calculateBridgeFee(uint256,address)(uint256)" $AMOUNT $TO --rpc-url $RPC)

# 2. Approve the sender to pull your G
cast send $G "approve(address,uint256)" $SENDER $AMOUNT --rpc-url $RPC $ACCT

# 3. Bridge (send the fee as msg.value)
cast send $SENDER "bridgeToGravity(uint256,address)(uint128)" $AMOUNT $TO \
  --value $FEE --rpc-url $RPC $ACCT
```
Native G appears at the recipient on Gravity (`https://mainnet-explorer.gravity.xyz`) after the Ethereum tx **finalizes** (~13 min) and consensus relays it — not immediately after step 3.

## With a wallet (MetaMask / Rabby / etc.)

On a block explorer's "Write Contract" tab for the Ethereum contracts (or the official bridge UI):
1. On the **G token** (`0x9C7B…0649`): `approve(spender = 0xE82c…C876, amount)`.
2. On **GBridgeSender** (`0xE82c…C876`): read `calculateBridgeFee(amount, recipient)` to get the fee, then call `bridgeToGravity(amount, recipient)` and set the transaction's **ETH value** to that fee.

Make sure your wallet is on **Ethereum mainnet** for these calls. The native G arrives on **Gravity (127001)** — add that network to your wallet (https://chainlist.org/chain/127001) to see the balance.

## From a contract

```solidity
interface IERC20 { function approve(address s, uint256 v) external returns (bool); }
interface IGBridgeSender {
    function calculateBridgeFee(uint256 amount, address recipient) external view returns (uint256);
    function bridgeToGravity(uint256 amount, address recipient) external payable returns (uint128);
}

contract BridgeHelper {
    IERC20 constant G = IERC20(0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649);
    IGBridgeSender constant SENDER = IGBridgeSender(0xE82c61Ac9Ec2041b493118051afa4F18a55dC876);

    /// Caller must have transferred `amount` G to this contract first.
    function bridge(uint256 amount, address recipient) external payable returns (uint128) {
        uint256 fee = SENDER.calculateBridgeFee(amount, recipient);
        require(msg.value >= fee, "insufficient ETH fee");
        G.approve(address(SENDER), amount);
        return SENDER.bridgeToGravity{value: fee}(amount, recipient);
    }
}
```

## Notes
- **Fee bounds**: `bridgeToGravity` reverts `InsufficientFee` if you underpay and `ExcessiveFee` if `msg.value > 2× fee`.
- **One-tx approve**: use `bridgeToGravityWithPermit(amount, recipient, deadline, v, r, s)` to skip the separate `approve`.
- **Timing**: minting waits for Ethereum *finality* (~2 epochs, ≈13 min), not just inclusion — see [`../references/token-bridge.md`](../references/token-bridge.md).
- **Direction**: Ethereum → Gravity only today; bridged G is effectively burned on Ethereum until the planned Chainlink-based return path. For other assets/routes see [How to Get G](https://docs.gravity.xyz).
