# Agent plugins

Personal plugin marketplace for Claude Code and Codex.

| Plugin | Claude Code | Codex | What it does |
|---|---|---|---|
| `work` | yes | skills only | Skills `grill` (interview the user until a plan has no open questions), `handover` (write a takeover prompt for a fresh session; `--continue` also starts that session in place), `spawn` (start a Claude Code session in tmux from a prompt file, in a new window or replacing the current pane), `pr` (verify a finished PR, get it an independent review and land it per repo policy) and `orchestrate` (run a master session that drives worker sessions in tmux). In Claude Code it also nudges orchestrated sessions to hand over when their context fills up. |
| `slash-menu` | yes | no | Replaces the `/` command list with a grouped menu above the prompt, with descriptions beside it. |

## Install

Claude Code:

```sh
claude plugin marketplace add hhoikoo/agent-marketplace
claude plugin install work@hhoikoo
claude plugin install slash-menu@hhoikoo
```

Skills run as `/work:grill`, `/work:handover`, `/work:spawn`, `/work:pr` and `/work:orchestrate`.

Codex:

```sh
codex plugin marketplace add hhoikoo/agent-marketplace
codex plugin add work@hhoikoo
```

Any agent supported by [`npx skills`](https://github.com/vercel-labs/skills) (skills only):

```sh
npx skills@latest add hhoikoo/agent-marketplace --skill '*' -g -a claude-code codex
```

Installed this way, the skills run without the `work:` prefix (`/spawn`, `/handover`, ...), and the hooks (handover nudge, `slash-menu`) are not installed. Install all skills together: `orchestrate` and `handover --continue` call `spawn`.

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

## Spawn launchers

`spawn` (and so `orchestrate` and `handover --continue`) starts sessions with `claude`. Other launchers, such as a wrapper that points Claude Code at another model provider, go in the optional, untracked `~/.config/agent-marketplace/spawn/launchers.json`. See `plugins/work/skills/spawn/launchers.md`.

## Development

```sh
claude plugin validate .
claude plugin test plugins/work
claude plugin test plugins/slash-menu
```

## License

Apache-2.0
