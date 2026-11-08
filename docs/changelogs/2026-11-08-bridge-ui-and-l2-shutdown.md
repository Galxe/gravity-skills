# docs(gravity): link the bridge UI; mark Alpha L2 as shut down

The Gravity Mainnet Bridge UI (https://bridge.gravity.xyz) is live for both
directions, and Gravity Alpha Mainnet (L2, chain 1625) has been shut down.

- SKILL.md: add the bridge UI to the Connect table; state the L2 is shut down.
- network-params.md: L2 is shut down, do not target 1625; remove "migrate from
  Alpha Mainnet" as a way to get G; link the bridge UI.
- token-bridge.md, bridge-g-to-ethereum.md, examples/bridge-g-to-ethereum.md:
  point end users to the UI; scripts/contracts keep the existing recipes.

Verification: tests/check_examples.py passes. The UI was confirmed to call
GravityGSender 0x40011DF49B772a70b171712f36AA59E1FCdCE62F (L1 → Ethereum) and
GBridgeSender 0xE82c61Ac9Ec2041b493118051afa4F18a55dC876 (Ethereum → L1).
