# Agent plugins

Personal plugin marketplace for Claude Code and Codex; the skills also install with `npx skills`. Public repo: github.com/hhoikoo/agent-marketplace. See README.md for the layout and install commands.

## Commands

```sh
claude plugin validate .                 # manifests and catalog; "no version" warnings are expected
claude plugin test plugins/work          # hook tests (nudge)
claude plugin test plugins/slash-menu
shellcheck plugins/*/skills/*/scripts/*.sh
npx skills@latest add . --list           # skills discovery as npx skills sees it
```

## Rules

- Never set `version` in any manifest. With no version, the commit hash is the version, so every push is an update.
- The repo is public: no secrets, tokens, internal hostnames, or employer, team or product names. Machine-specific settings (like launchers) live in untracked files under `~/.config/agent-marketplace/`.
- Edit sources here, never the installed copies under `~/.claude/plugins/cache/`.
- One signed commit per topic, plain imperative subject. Never squash or force-push.
- Skill files follow the Agent Skills spec (https://agentskills.io/specification): frontmatter `name` matches the directory, `description` says what it does and when to use it.
- Skills that call each other use the plugin names (`/work:spawn`) and must keep working with the bare names `npx skills` installs (`/spawn`). Cross-skill files are referenced as siblings: `${CLAUDE_SKILL_DIR}/../<skill>/...`.
- Plugin descriptions stay generic; don't list skills in them.
- Codex auto-loads `hooks/hooks.json`, so Claude-only hooks go in `hooks/claude-hooks.json`.
- The handover nudge (`plugins/work/hooks/register.ts`) depends on `ORCH_ROLE`, `ORCH_HANDOVER_PERCENT`, the skill name `orchestrate` and the heading "Handover → Master (this session)" in orchestrate's SKILL.md. Changing any of them means updating the hook and `plugins/work/tests/nudge.test.ts`.
- Test tmux behaviour in a separate server (`tmux -L <name>`), never on the default one.
