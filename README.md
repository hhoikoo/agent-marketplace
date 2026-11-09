# Agent plugins

Personal plugin marketplace for Claude Code and Codex.

| Plugin | Claude Code | Codex | What it does |
|---|---|---|---|
| `work` | yes | skills only | Skills `grill` (interview the user until a plan has no open questions), `handover` (write a takeover prompt for a fresh session) and `orchestrate` (run a master session that drives worker sessions in tmux). In Claude Code it also nudges orchestrated sessions to hand over when their context fills up. |
| `slash-menu` | yes | no | Replaces the `/` command list with a grouped menu above the prompt, with descriptions beside it. |

## Install

Claude Code:

```sh
claude plugin marketplace add hhoikoo/agent-marketplace
claude plugin install work@hhoikoo
claude plugin install slash-menu@hhoikoo
```

Skills run as `/work:grill`, `/work:handover` and `/work:orchestrate`.

Codex:

```sh
codex plugin marketplace add hhoikoo/agent-marketplace
codex plugin add work@hhoikoo
```

## Layout

```
.claude-plugin/marketplace.json     Claude Code catalog
.agents/plugins/marketplace.json    Codex catalog (work only)
plugins/work/
  .claude-plugin/plugin.json        Claude Code manifest
  .codex-plugin/plugin.json         Codex manifest
  skills/                           shared by both tools
  hooks/claude-hooks.json           Claude Code hooks module (not hooks.json, which Codex loads)
plugins/slash-menu/                 Claude Code hooks module
```

## Orchestrate launchers

`orchestrate` starts workers with `claude`. Other launchers, such as a wrapper that points Claude Code at another model provider, go in the optional, untracked `~/.config/agent-marketplace/orchestrate/launchers.json`. See `plugins/work/skills/orchestrate/launchers.md`.

## Development

```sh
claude plugin validate .
claude plugin test plugins/work
claude plugin test plugins/slash-menu
```

## License

Apache-2.0
