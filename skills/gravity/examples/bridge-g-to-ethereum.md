# Example: bridge G from Gravity L1 to Ethereum

Send native G on **Gravity L1** and receive ERC-20 G on **Ethereum**. Interface, reverts and caveats: [`../references/bridge-g-to-ethereum.md`](../references/bridge-g-to-ethereum.md).

```
GravityGSender   0x40011DF49B772a70b171712f36AA59E1FCdCE62F   (Gravity L1, chain 127001)
EthereumGMinter  0xE0a7F6938a1748a715302480668BaB90de7d90a6   (Ethereum)
G ERC-20         0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649   (Ethereum)
```

The pattern is always: **quote → send `amount + fee` (+ buffer) → track the CCIP message ID**. The buffer is refunded in the same transaction.

## With `cast`

```bash
GRAVITY_RPC=https://mainnet-rpc.gravity.xyz
SENDER=0x40011DF49B772a70b171712f36AA59E1FCdCE62F
RECIPIENT=0xYourEthereumAddress          # an address you control on Ethereum
AMOUNT=$(cast to-wei 10)                  # 10 G

# 1. Quote the CCIP fee (native G, wei).
FEE=$(cast call "$SENDER" 'quoteBridge(address,uint256)(uint256)' "$RECIPIENT" "$AMOUNT" \
  --rpc-url "$GRAVITY_RPC" | awk '{print $1}')

# 2. Send amount + fee + 10% fee buffer (refunded).
VALUE=$(echo "$AMOUNT + $FEE * 11 / 10" | bc)
cast send "$SENDER" 'bridge(address,uint256)' "$RECIPIENT" "$AMOUNT" \
  --value "$VALUE" --rpc-url "$GRAVITY_RPC" --account <your-keystore>

# 3. Read the CCIP message ID from the GDeposited event (5th field = messageId).
#    cast receipt <txHash> --rpc-url "$GRAVITY_RPC" --json | jq '.logs'
#    then open https://ccip.chain.link/msg/<messageId>
```

## With viem

```ts
import { createPublicClient, createWalletClient, http, parseEther, parseEventLogs, defineChain } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'

const gravity = defineChain({
  id: 127001,
  name: 'Gravity',
  nativeCurrency: { name: 'G', symbol: 'G', decimals: 18 },
  rpcUrls: { default: { http: ['https://mainnet-rpc.gravity.xyz'] } },
})

const SENDER = '0x40011DF49B772a70b171712f36AA59E1FCdCE62F'
const abi = [
  { type: 'function', name: 'quoteBridge', stateMutability: 'view',
    inputs: [{ name: 'recipient', type: 'address' }, { name: 'amount', type: 'uint256' }],
    outputs: [{ name: 'fee', type: 'uint256' }] },
  { type: 'function', name: 'bridge', stateMutability: 'payable',
    inputs: [{ name: 'recipient', type: 'address' }, { name: 'amount', type: 'uint256' }],
    outputs: [{ name: 'messageId', type: 'bytes32' }] },
  { type: 'event', name: 'GDeposited', inputs: [
    { name: 'depositId', type: 'uint256', indexed: true },
    { name: 'depositor', type: 'address', indexed: true },
    { name: 'recipient', type: 'address', indexed: true },
    { name: 'amount', type: 'uint256', indexed: false },
    { name: 'messageId', type: 'bytes32', indexed: false },
    { name: 'fee', type: 'uint256', indexed: false } ] },
] as const

const account = privateKeyToAccount(process.env.PRIVATE_KEY as `0x${string}`)
const publicClient = createPublicClient({ chain: gravity, transport: http() })
const walletClient = createWalletClient({ account, chain: gravity, transport: http() })

const recipient = account.address // or an explicit Ethereum address you control
const amount = parseEther('10')

const fee = await publicClient.readContract({ address: SENDER, abi, functionName: 'quoteBridge', args: [recipient, amount] })
const hash = await walletClient.writeContract({
  address: SENDER, abi, functionName: 'bridge', args: [recipient, amount],
  value: amount + (fee * 11n) / 10n, // 10% fee buffer, refunded
})
const receipt = await publicClient.waitForTransactionReceipt({ hash })
const [deposit] = parseEventLogs({ abi, eventName: 'GDeposited', logs: receipt.logs })
console.log('CCIP message:', `https://ccip.chain.link/msg/${deposit.args.messageId}`)
```

## From a Solidity contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IGravityGSender {
    function quoteBridge(address recipient, uint256 amount) external view returns (uint256 fee);
    function bridge(address recipient, uint256 amount) external payable returns (bytes32 messageId);
}

/// Forwards native G held by this contract to an Ethereum recipient.
contract GravityToEthereum {
    IGravityGSender public constant SENDER = IGravityGSender(0x40011DF49B772a70b171712f36AA59E1FCdCE62F);

    /// Pays amount + exact fee from this contract's balance. Exact payment means no refund leg.
    function bridgeOut(address ethereumRecipient, uint256 amount) external returns (bytes32 messageId) {
        uint256 fee = SENDER.quoteBridge(ethereumRecipient, amount);
        messageId = SENDER.bridge{value: amount + fee}(ethereumRecipient, amount);
    }

    /// Needed only if you overpay: GravityGSender refunds the excess to msg.sender (this contract).
    receive() external payable {}
}
```

Quote and send in the same transaction (as above) so the fee cannot move in between. Restrict `bridgeOut` to authorized callers in real code.

## Gotchas

- **Irreversible** once the Gravity tx succeeds; G cannot come back on Gravity.
- **Recipient must exist for you on Ethereum.** Do not reuse a Gravity contract-wallet address unless that wallet is deployed and controlled by you on Ethereum.
- **Don't re-bridge to retry.** A delayed or failed delivery is retried by CCIP for the same deposit; a new `bridge` call is a new deposit.
- **Fee moves with Ethereum gas.** Re-quote right before sending; keep a buffer.
