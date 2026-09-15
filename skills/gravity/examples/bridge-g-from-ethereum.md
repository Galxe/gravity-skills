# Bridge G from Ethereum → Gravity L1

Lock G on **Ethereum mainnet** via `GBridgeSender`; native G is minted to your recipient on **Gravity L1** once consensus relays the message. Addresses + interface: [`../references/token-bridge.md`](../references/token-bridge.md).

> **One-way (Ethereum → Gravity only)** for now — bridged G is locked on Ethereum with no return path yet, so treat it as burned on the Ethereum side. **Minting on Gravity waits for Ethereum finality (~13 min)**, not just for your tx to be mined.

```
GBridgeSender  0xE82c61Ac9Ec2041b493118051afa4F18a55dC876   (Ethereum)
G token        0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649   (Ethereum ERC-20, 18 decimals)
```

Every path is the same 3 steps: **(1)** quote the ETH fee, **(2)** approve the sender to spend your G, **(3)** call `bridgeToGravity{value: fee}(amount, recipient)`.

> **Gas tip (preferred):** if your client can sign an ERC-2612 permit, use **`bridgeToGravityWithPermit`** instead — it folds the approval into the bridge call, so you send **one** transaction instead of two (skip step 2). Full copy-paste recipe: [One transaction with `cast` (permit path)](#one-transaction-with-cast-permit-path-preferred). The 2-tx flow just below uses the explicit `approve` for simplicity.

## With `cast` (Foundry CLI)

Run these recipes as **Bash scripts** (they use arrays and Bash substring syntax).
Replace the recipient and keystore name before running. You need G and ETH on
Ethereum mainnet; the keystore must belong to the account holding the G.

```bash
set -euo pipefail

SENDER=0xE82c61Ac9Ec2041b493118051afa4F18a55dC876
G=0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649
RPC=https://ethereum-rpc.publicnode.com   # any Ethereum mainnet RPC (e.g. publicnode, your own node, Alchemy/Infura URL)
AMOUNT=$(cast to-wei 100)              # 100 G
TO=0xYourGravityAddress                # recipient on Gravity L1
ACCT=(--account my-keystore)           # or: ACCT=(--ledger)

# 1. Quote the ETH portal fee. Omit the return type to get raw ABI bytes,
# then convert to a plain integer (decoded cast output can include [1e18]).
FEE=$(cast call "$SENDER" "calculateBridgeFee(uint256,address)" "$AMOUNT" "$TO" --rpc-url "$RPC" | cast to-dec)

# 2. Approve the sender to pull your G
cast send "$G" "approve(address,uint256)" "$SENDER" "$AMOUNT" --rpc-url "$RPC" "${ACCT[@]}"

# 3. Bridge (send the fee as msg.value)
cast send "$SENDER" "bridgeToGravity(uint256,address)(uint128)" "$AMOUNT" "$TO" \
  --value "$FEE" --rpc-url "$RPC" "${ACCT[@]}"
```
Native G appears at the recipient on Gravity (`https://mainnet-explorer.gravity.xyz`) after the Ethereum tx **finalizes** (~13 min) and consensus relays it — not immediately after step 3.

## One transaction with `cast` (permit path, preferred)

`bridgeToGravityWithPermit` folds the approval into the bridge call via an [EIP-2612](https://eips.ethereum.org/EIPS/eip-2612) signature, so you send **one** tx. You sign `permit(owner = you, spender = GBridgeSender, value = amount, nonce, deadline)` against the G token's **fixed domain** — `name="Gravity"`, `version="1"`, `chainId=1`, `verifyingContract` = the G token.

```bash
set -euo pipefail

SENDER=0xE82c61Ac9Ec2041b493118051afa4F18a55dC876
G=0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649
RPC=https://ethereum-rpc.publicnode.com
AMOUNT=$(cast to-wei 100)
TO=0xYourGravityAddress                 # recipient on Gravity L1
ACCT=(--account my-keystore)            # or: ACCT=(--ledger)
OWNER=$(cast wallet address "${ACCT[@]}") # the same account signs and sends

FEE=$(cast call "$SENDER" "calculateBridgeFee(uint256,address)" "$AMOUNT" "$TO" --rpc-url "$RPC" | cast to-dec)
NONCE=$(cast call "$G" "nonces(address)" "$OWNER" --rpc-url "$RPC" | cast to-dec)
DEADLINE=$(( $(date +%s) + 3600 ))      # 1 hour out

# Build the EIP-712 permit and sign it (cast returns 0x{r}{s}{v}, 65 bytes)
PERMIT_FILE=$(mktemp)
trap 'rm -f "$PERMIT_FILE"' EXIT
cat > "$PERMIT_FILE" <<JSON
{
  "types": {
    "EIP712Domain": [{"name":"name","type":"string"},{"name":"version","type":"string"},{"name":"chainId","type":"uint256"},{"name":"verifyingContract","type":"address"}],
    "Permit": [{"name":"owner","type":"address"},{"name":"spender","type":"address"},{"name":"value","type":"uint256"},{"name":"nonce","type":"uint256"},{"name":"deadline","type":"uint256"}]
  },
  "primaryType": "Permit",
  "domain": {"name":"Gravity","version":"1","chainId":1,"verifyingContract":"$G"},
  "message": {"owner":"$OWNER","spender":"$SENDER","value":"$AMOUNT","nonce":"$NONCE","deadline":"$DEADLINE"}
}
JSON
SIG=$(cast wallet sign --data --from-file "$PERMIT_FILE" "${ACCT[@]}")
R=0x${SIG:2:64}; S=0x${SIG:66:64}; V=$((16#${SIG:130:2}))   # cast already yields 27/28

cast send "$SENDER" \
  "bridgeToGravityWithPermit(uint256,address,uint256,uint8,bytes32,bytes32)(uint128)" \
  "$AMOUNT" "$TO" "$DEADLINE" "$V" "$R" "$S" --value "$FEE" --rpc-url "$RPC" "${ACCT[@]}"
```

The permit reverts (taking the whole bridge tx with it) unless the domain reproduces the token's exactly. Watch for:
- **`version`** — the G token has no `version()` getter (it reverts); use `"1"` (per EIP-2612 default, confirmed via `eip712Domain()`).
- **`chainId` is `1`** — the permit is verified on Ethereum, not Gravity's `127001` — and `verifyingContract` is the G token, not the bridge.
- **`v` must be `27`/`28`** — `cast wallet sign` already returns that; signers that return `0`/`1` (ethers, viem) need `+27`.

## With a wallet (MetaMask / Rabby / etc.)

On a block explorer's "Write Contract" tab for the Ethereum contracts (or the official bridge UI):
1. On the **G token** (`0x9C7B…0649`): `approve(spender = 0xE82c…C876, amount)`.
2. On **GBridgeSender** (`0xE82c…C876`): read `calculateBridgeFee(amount, recipient)` to get the fee, then call `bridgeToGravity(amount, recipient)` and set the transaction's **ETH value** to that fee.

Make sure your wallet is on **Ethereum mainnet** for these calls. The native G arrives on **Gravity (127001)** — add that network to your wallet (https://chainlist.org/chain/127001) to see the balance.

## From a contract: bridge the caller's G

Use this pattern when an Ethereum application needs to bridge G on a user's
behalf. The user first calls `G.approve(helperAddress, amount)`, then calls
`helper.bridge(amount, recipient)` with the quoted ETH fee. Within that one
bridge transaction, the helper pulls G from the caller, approves the official
sender, and initiates the bridge. Any failure rolls back the whole transaction.

**Do not transfer G directly to the helper.** It has no deposit balances or
withdrawal function. Each call is funded from `msg.sender`'s wallet, so another
caller cannot spend G already at the helper's address.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}
interface IGBridgeSender {
    function calculateBridgeFee(uint256 amount, address recipient) external view returns (uint256);
    function bridgeToGravity(uint256 amount, address recipient) external payable returns (uint128);
}

contract BridgeHelper {
    IERC20 constant G = IERC20(0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649);
    IGBridgeSender constant SENDER = IGBridgeSender(0xE82c61Ac9Ec2041b493118051afa4F18a55dC876);

    /// Caller approves this helper for `amount` G before calling.
    function bridge(uint256 amount, address recipient) external payable returns (uint128) {
        uint256 fee = SENDER.calculateBridgeFee(amount, recipient);
        require(msg.value == fee, "send exact ETH fee");
        require(G.transferFrom(msg.sender, address(this), amount), "G transfer failed");
        require(G.approve(address(SENDER), amount), "G approval failed");
        return SENDER.bridgeToGravity{value: fee}(amount, recipient);
    }
}
```

The helper requires **exactly** `calculateBridgeFee(amount, recipient)` wei,
plus transaction gas paid separately. If the fee changes before execution,
re-quote and retry. Rejecting underpayment and overpayment before pulling G
prevents fee surplus from being retained. The ERC-20 calls here target the
documented G token, which returns booleans and transfers the specified amount.

## Notes
- **Fee bounds**: `bridgeToGravity` reverts `InsufficientFee` if you underpay and `ExcessiveFee` if `msg.value > 2× fee`.
- **One-tx approve**: use `bridgeToGravityWithPermit(amount, recipient, deadline, v, r, s)` to skip the separate `approve` — see the [permit recipe](#one-transaction-with-cast-permit-path-preferred).
- **Timing**: minting waits for Ethereum *finality* (~2 epochs, ≈13 min), not just inclusion — see [`../references/token-bridge.md`](../references/token-bridge.md).
- **Direction**: Ethereum → Gravity only today; bridged G is effectively burned on Ethereum until the planned Chainlink-based return path. For other assets/routes see [How to Get G](https://docs.gravity.xyz).
