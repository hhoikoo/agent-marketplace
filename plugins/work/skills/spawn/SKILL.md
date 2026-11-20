---
name: spawn
description: Starts a fresh Claude Code session in tmux and hands it a prompt file, either in a new window or replacing this session in place (this session then closes its own pane). Handles how a session starts, not what it is told. Use when asked to spawn, start or relaunch a session from a prompt file, or when another skill (handover --continue, orchestrate) needs a session started.
argument-hint: "[--replace] [options] <prompt-file>"
compatibility: Claude Code with tmux
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/spawn.sh *) Bash(${CLAUDE_SKILL_DIR}/scripts/rename-self.sh *) Bash(tmux display *) Bash(tmux capture-pane *) Bash(tmux kill-pane *)
---

# Spawn

`${CLAUDE_SKILL_DIR}` below is this skill's directory. Where it appears unexpanded (for example in Codex), use the directory that holds this file.

Start a session with `${CLAUDE_SKILL_DIR}/scripts/spawn.sh` from `$ARGUMENTS`. The prompt file holds what the session should do; this skill only decides how it starts. It needs tmux, and launchers other than `claude` also need `jq`.

| mode | flag | what happens |
|---|---|---|
| new window | (default) | new window in the current tmux session (`--session`, `--window-name` to change) |
| replace | `--replace` | splits this pane (`$TMUX_PANE`, or `--pane`) and starts the new session there, which leaves this pane alone; this session closes the pane itself as its last step |

## Inheritance

The new session copies this one unless a flag overrides it:

| what | default | override |
|---|---|---|
| name (`-n`) | `$SPAWN_NAME`; pass `--name` from `ListAgents` (its first line names this session) when this session has a name | `--name` |
| model | `$SPAWN_MODEL`; if unset and the launcher is `claude`, pass your own model ID | `--model` |
| launcher | `$SPAWN_LAUNCHER`, else `claude` | `--launcher`, see [launchers.md](launchers.md) |
| start dir | this pane's directory | `--cwd` |
| env | `ORCH_ROLE`, `HANDOVER_PERCENT` when set | `--env K=V` (repeatable) |

The script exports `SPAWN_NAME`, `SPAWN_MODEL` and `SPAWN_LAUNCHER` to the new session, so its own successor inherits them. Pass a flag only for what the user asked to change.

## Steps

1. Work out the flags (above). Check that the prompt file exists and is self-contained, because the new session starts cold. In replace mode, first finish everything else this session still has to do: notes, messages, and background tasks (Bash `run_in_background`; wait for them or stop them).
2. Run the script. It passes the kickoff line ("Read <prompt-file> and follow it exactly.") as the launcher's positional prompt, so the session starts with it already submitted and nothing is typed into the pane. It then watches the pane for a few seconds for an early exit or the folder-trust dialog, and prints `target=<tmux target> pane=<pane id> session=<name> launcher=<name>`, and in replace mode a second line `close: tmux kill-pane -t <pane>`.
3. On a non-zero exit (unknown launcher, untrusted start dir, session exited at launch), report the message and stop. The user answers any folder-trust prompt. In replace mode, the trust stop also starts a background watcher that closes the replaced pane once the user accepts the dialog (it gives up after `SPAWN_TRUST_WAIT` seconds, default 30 minutes), so end your turn without running the close command.
4. New window: confirm with `ListAgents` that the name is listed (a session held by a dialog never registers; if it is missing, look at the pane with `tmux capture-pane -p -t <pane>`), then tell the user the target. Replace: write one line saying the successor is taking over, then run the `close:` command as your final tool call, with nothing after it.

Closing the pane ends this session in the middle of its turn: anything still running is killed and this turn's Stop hooks do not run, while SessionEnd hooks still run to completion. With `--pane` naming another pane, the `close:` command closes that other pane: the caller runs it, and the session in that pane is cut off mid-turn.

Start-up check env: `SPAWN_SETTLE`, seconds to watch the pane (default 6); `SPAWN_TRUST_WAIT`, seconds the trust-dialog watcher waits in replace mode (default 1800).

## Rename this session

Sessions started here are named at launch. To rename the current session (for example one the user started), run `${CLAUDE_SKILL_DIR}/scripts/rename-self.sh <name>` with Bash `run_in_background: true`, then end your turn right away: it types `/rename <name>` into this pane after `SPAWN_RENAME_DELAY` seconds (default 8), which only lands while you are idle. When re-invoked, confirm the name with `ListAgents`. Do the renaming yourself instead of asking the user.
