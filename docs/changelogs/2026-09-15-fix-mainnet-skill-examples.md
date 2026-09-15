# fix: make mainnet bridge and oracle examples usable

## 1. Background and Current State

The review at `491b1aa` found four issues: the programmable bridge helper spends
unattributed deposits and retains excess ETH; OracleRequestQueue is described as
usable despite having no mainnet code; OracleConsumer contains two incomplete
address literals; both Bash recipes mishandle wallet arguments and decoded
numeric output. Existing mainnet Oracle callback/storage behavior remains the
reference for this change.

Read-only mainnet checks returned `0x` for OracleRequestQueue and NativeOracle
code hash `0x30dd3888ce26735c0d6c5a036b48a1de668dd5506efa7588ce450f976da28255`.
The official [system-contract page](https://docs.gravity.xyz/developer-resources/mainnet)
already marks the request queue as reserved and not deployed. No docsite change
is needed for these four fixes.

## 2. Problem Model and End-to-End Behavior

- B1: A caller authorizes the helper, then bridges its own G in one atomic call.
  Pre-existing helper balances are never used to fund another caller's bridge.
- B2: The helper forwards exactly the quoted ETH fee and retains no fee surplus.
- B3: Both Bash recipes run with a keystore and preserve integer precision; the
  permit recipe signs for the same account that sends the transaction.
- B4: The Oracle example compiles; the undeployed request queue is omitted from
  the skill's references and examples.
- F1: Missing funds/approval, token failure, or bridge failure reverts the entire
  helper call, including token transfers and approvals.
- F2: An incorrect ETH fee reverts before collecting G.
- Non-goals: changes to deployed contracts, mainnet Oracle semantics, other
  review findings, network upgrades, or real-asset bridge transactions.

## 3. Research, Findings, and Architecture Decision

- D1: Keep the programmable example, as the user requested. Pull G from
  `msg.sender` within `bridge`, approve the canonical sender, and bridge it.
  This teaches contract integration without the unsafe pre-deposit step.
- D2: Require exact fee payment. Rejecting surplus is simpler than adding a
  refund interaction and prevents retaining ETH from successful calls.
- D3: Use Bash arrays for wallet arguments and raw ABI output followed by
  `cast to-dec` for fees/nonces. Use a temporary file for typed data.
- D4: Label Oracle references as current-mainnet behavior. Preserve callback
  handling and storage semantics; correct the address literals and remove the
  undeployed queue from the skill.
- Alternatives: removing the helper would lose the requested contract example;
  deposit bookkeeping and refunds add state/interactions unnecessary here.
- R1: Local token/bridge doubles verify the examples, not cross-chain delivery.
  Mainnet finality and validator operation are outside the changed boundary.
- R2: The helper is specific to the documented G ERC-20, which returns booleans
  and transfers exact amounts. It is not a generic arbitrary-token adapter.

## 4. Implementation Design

Only `gravity-skills` changes. Keep the helper in the Markdown recipe and extract
that exact block for tests. Add `transferFrom` to its ERC-20 interface, require
successful token operations, and reject `msg.value != fee` before transferring.
No balance ledger, persistent approvals beyond the bridge call, or refund path
is needed. Any downstream revert rolls back the complete call.

Update `examples/bridge-g-from-ethereum.md`, `examples/OracleConsumer.sol`,
`references/native-oracle.md`, and `references/system-contracts.md`. Explain
caller-funded programmable bridging and the distinction between the helper's
exact fee requirement and the canonical bridge's existing fee bounds.

### Serial Implementation Checklist

- [x] Fix the helper, Bash recipes, and their explanation.
- [x] Fix the Oracle address literals and remove the unavailable queue references.
- [x] Add focused regressions executing the actual documented examples.
- [x] Run verification and review the complete diff.

## 5. Verification and E2E Design

- `SOLC=/home/yxia/.local/share/svm/0.8.30/solc-0.8.30 python3 tests/check_examples.py`
  compiles all Solidity examples, runs Foundry helper behavior tests, and runs
  both extracted Bash recipes using real cast/keystore signing against local
  Anvil contract doubles. Temporary build outputs and keystores stay outside
  the repository. No production writes.
- `python3 /home/yxia/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/gravity`
  checks skill metadata subject to validator compatibility with existing fields.
- `git diff --check` checks whitespace.
- Lint: unavailable; this repository has no `make lint-fix` target.
- E2E Required: no. Production Ethereum-to-Gravity delivery is unchanged;
  local execution covers the modified example and CLI boundaries.

| Behavior | Evidence |
| --- | --- |
| B1, F1 | Caller-funded bridge, unrelated deposit isolation, rollback tests |
| B2, F2 | Exact-fee success; under/overpayment fails without collecting G |
| B3 | Both Bash recipes bridge locally; permit signature is verified on-chain |
| B4 | Solidity 0.8.30 compile; mainnet deployment evidence and reference review |

## 6. Human Decisions and Interaction

The user selected findings 1–4, explicitly excluded post-upgrade Oracle
behavior, agreed to the caller-funded programmable helper flow, and instructed
the agent to start fixing. Exact-fee rejection and test mechanics are local
implementation choices within the agreed scope. This record captures that
conversation approval; it does not introduce a new scope or approval gate.
The user subsequently requested deleting OracleRequestQueue from the skill
entirely and explicitly authorized pushing a PR. That replaces the earlier
choice to retain a reserved-address notice. The changelog retains the finding
as historical context for why the section was removed.

## 7. Outcome and Evidence

The four selected issues are fixed. The helper collects the caller's G within
the bridge transaction and rejects incorrect fees; the Bash examples execute
with quoted wallet arguments and exact integer values. OracleConsumer uses the
complete checksummed address. OracleRequestQueue and its request/refund recipe
are removed from the skill's references.
Mainnet Oracle callback and payload-storage behavior is preserved.

| Item | Result | Evidence |
| --- | --- | --- |
| B1 / D1 | DONE | Successful caller-funded flow, existing-deposit isolation, unauthorized caller and missing-approval tests |
| B2 / F2 / D2 | DONE | Exact fee forwarded; under/overpayment rejected with balances preserved |
| F1 | DONE | Token transfer/approval failures and bridge failure roll back balances and allowances |
| B3 / D3 | DONE | Both extracted Bash recipes executed against Anvil; recipient credit, token balance, nonce, and allowance checked |
| B4 / D4 | DONE | All Solidity examples compile; mainnet-only prose and reserved-address status reviewed |
| R1 / R2 | BOUNDED | Local doubles cover the changed boundary; no real assets or generic-token behavior claimed |

Verification from the `gravity-skills` root:

- `SOLC=/home/yxia/.local/share/svm/0.8.30/solc-0.8.30 python3 tests/check_examples.py`
  — exit 0. Solidity 0.8.30 compiled all examples. Eight Foundry tests passed.
  Both Bash recipes bridged 100 G on disposable Anvil, using real cast signing
  and an encrypted keystore whose path contains spaces. The permit used nonce
  `1000000000000000001` and was verified with EIP-712/ecrecover by the local token.
- Regression sensitivity: the original helper from `491b1aa` failed the
  caller-funded success and victim-deposit isolation tests when substituted
  into a temporary Foundry project. No baseline file was changed.
- `git diff --check` — exit 0. Local Markdown reference targets exist.
- The generic `quick_validate.py` rejects the pre-existing `compatibility`
  frontmatter field, which was not changed. Validation of a temporary copy
  excluding that field passed. The original metadata was preserved.
- Lint unavailable: no Makefile / `make lint-fix` target exists.
- No production E2E was required or executed. Production contracts and docsite
  content were not modified. Test artifacts and generated test keys were removed
  with the temporary workspaces.

Review covered the complete product diff, tests, scope, fund ownership,
transaction rollback, current-mainnet semantics, and documentation consistency.
No unresolved in-scope findings remain.

## 8. Remaining Work

None for the four requested fixes. Other audit findings remain outside this
change. Publication of `fix/mainnet-skill-examples` and PR checks are pending.
