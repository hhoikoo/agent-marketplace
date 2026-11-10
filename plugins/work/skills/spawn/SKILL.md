---
name: spawn
description: Starts a fresh Claude Code session in tmux and hands it a prompt file, either in a new window or replacing this session in place (the new session closes this pane). Handles how a session starts, not what it is told. Use when asked to spawn, start or relaunch a session from a prompt file, or when another skill (handover --continue, orchestrate) needs a session started.
argument-hint: "[--replace] [options] <prompt-file>"
compatibility: Claude Code with tmux
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/spawn.sh *) Bash(${CLAUDE_SKILL_DIR}/scripts/rename-self.sh *) Bash(tmux display *) Bash(tmux capture-pane *)
---

# Spawn

`${CLAUDE_SKILL_DIR}` below is this skill's directory; if it appears unexpanded (e.g. in Codex), use the directory containing this file.

Start a session with `${CLAUDE_SKILL_DIR}/scripts/spawn.sh` from `$ARGUMENTS`. The prompt file holds what the session should do; this skill only decides how it starts. Requires tmux; launchers other than `claude` also need `jq`.

| mode | flag | what happens |
|---|---|---|
| new window | (default) | new window in the current tmux session (`--session`, `--window-name` to change) |
| replace | `--replace` | splits this pane (`$TMUX_PANE`, or `--pane`); the new session closes this pane first, then reads the prompt file |

## Inheritance

The new session copies this one unless a flag overrides it:

| what | default | override |
|---|---|---|
| name (`-n`) | `$SPAWN_NAME`; pass `--name` from `ListAgents` (its first line names this session) when this session has a name | `--name` |
| model | `$SPAWN_MODEL`; if unset and the launcher is `claude`, pass your own model ID | `--model` |
| launcher | `$SPAWN_LAUNCHER`, else `claude` | `--launcher`, see [launchers.md](launchers.md) |
| start dir | this pane's directory | `--cwd` |
| env | `ORCH_ROLE`, `HANDOVER_PERCENT` when set | `--env K=V` (repeatable) |

The script exports `SPAWN_NAME`, `SPAWN_MODEL` and `SPAWN_LAUNCHER` to the new session, so its own successor inherits them. Pass only what the user asked to change.

## Steps

1. Work out the flags (above). Check the prompt file exists and is self-contained: the new session starts cold.
2. Run the script. It passes the kickoff line ("Read <prompt-file> and follow it exactly.") as the launcher's positional prompt, so the session starts with it already submitted and nothing is typed into the pane. It then watches the pane for a few seconds for an early exit or the folder-trust dialog, and prints `target=<tmux target> pane=<pane id> session=<name> launcher=<name>`.
3. On a non-zero exit (unknown launcher, untrusted start dir, session exited at launch), report the message and stop. Never answer a folder-trust prompt for the user.
4. New window: confirm with `ListAgents` that the name is listed (a session held by a dialog never registers; if it is missing, look at the pane with `tmux capture-pane -p -t <pane>`), then tell the user the target. Replace: end your turn right away with one line saying the successor is taking over; it closes this pane.

Start-up check env: `SPAWN_SETTLE`, seconds to watch the pane (default 6).

## Rename this session

Sessions started here are named at launch. To rename the current session (e.g. one the user started), run `${CLAUDE_SKILL_DIR}/scripts/rename-self.sh <name>` with Bash `run_in_background: true`, then end your turn right away: it types `/rename <name>` into this pane after `SPAWN_RENAME_DELAY` seconds (default 8), which only lands while you are idle. When re-invoked, confirm the name with `ListAgents`. Never ask the user to rename you.
