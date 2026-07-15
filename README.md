# Gravity Skills

Official [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills) for building on **Gravity** — an EVM-compatible Layer 1 (chain ID `127001`, native token `G`) powered by the [Gravity SDK](https://github.com/Galxe/gravity-sdk): AptosBFT consensus, parallel EVM execution (Grevm on Gravity Reth), and a native on-chain oracle.

It's written in the standard [Agent Skills](https://github.com/anthropics/agent-skills) (`SKILL.md`) format, so any agent that understands skills — **Claude Code, Cursor, Codex, and 50+ others** — can load Gravity's chain knowledge on demand.

## Skills

| Skill | What it covers |
| --- | --- |
| [`gravity`](skills/gravity/SKILL.md) | Core reference for writing, deploying, and integrating smart contracts on Gravity L1: network params, the system-contract address map, the native oracle ABI, the cross-chain G token bridge, safe on-chain randomness, and canonical EVM preinstalls (Multicall3, Permit2, CreateX, ERC-4337). |

Each skill is progressive-disclosure: a short `SKILL.md` entry point that links into focused `references/` docs and runnable `examples/`.

## Install

The easiest way — the [`skills`](https://github.com/vercel-labs/skills) CLI installs into whichever agent you use (Claude Code, Cursor, Codex, OpenCode, Cline, Copilot, and 50+ more):

```
npx skills add https://github.com/Galxe/gravity-skills
```

Then ask your agent anything about building on Gravity and it loads the skill on demand. Re-run `npx skills update` to pull the latest.

<details>
<summary>Alternatives</summary>

**Claude Code plugin** — add the marketplace and install:

```
/plugin marketplace add Galxe/gravity-skills
/plugin install gravity@gravity-skills
```

**Codex plugin** — register this repo as a plugin marketplace (a clone works too) and install:

```
codex plugin marketplace add Galxe/gravity-skills
codex plugin add gravity@gravity-skills
```

**Manual** — point any `SKILL.md`-aware agent directly at [`skills/gravity/`](skills/gravity/), or copy that directory into your agent's skills folder.

</details>

## Layout

```
.claude-plugin/
  marketplace.json     # Claude Code marketplace manifest (plugin: gravity)
  plugin.json          # Claude Code plugin manifest
.agents/plugins/
  marketplace.json     # Codex marketplace manifest
.codex-plugin/
  plugin.json          # Codex plugin manifest
skills/
  gravity/
    SKILL.md           # entry point — quick facts + system-contract map
    references/        # network-params, system-contracts, native-oracle,
                       # token-bridge, randomness, preinstalls
    examples/          # OracleConsumer.sol, bridge-g-from-ethereum.md,
                       # RandomnessConsumer.sol
```

## Sources of truth

Addresses and ABIs here are distilled from the canonical Gravity repos. When in doubt, defer to:

- Core system contracts: https://github.com/Galxe/gravity_chain_core_contracts
- Docs: https://docs.gravity.xyz

> Addresses are load-bearing. The skill instructs agents to copy hex addresses verbatim and to surface `TBA`/`blocked` statuses rather than inventing values.

## License

MIT — see [LICENSE](LICENSE).
