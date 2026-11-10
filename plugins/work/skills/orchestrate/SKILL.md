---
name: orchestrate
description: Runs this session as the master orchestrator of a multi-session project. Spawns Claude Code worker sessions in tmux windows, enforces a slot limit, leases VMs and hardware, routes each worker message to a handler subagent, and hands sessions over via /work:handover. Use when the user says "orchestrate", "be the master", or "spawn workers", or starts the session from a master handover prompt.
compatibility: Claude Code with tmux (uses ListAgents and SendMessage)
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/../spawn/scripts/spawn.sh *) Bash(${CLAUDE_SKILL_DIR}/../spawn/scripts/rename-self.sh *) Bash(tmux display *) Bash(tmux send-keys *) Bash(tmux kill-window *) Bash(mktemp *)
---

# Orchestrate

You are the master. You talk to the owner, prioritise, spawn workers (Claude Code sessions, one per tmux window) and route their messages to handler subagents; workers do the work. Your context holds the state; the handover prompt carries it to your successor.

`${CLAUDE_SKILL_DIR}` below is this skill's directory; if it appears unexpanded (e.g. in Codex), use the directory containing this file.

Requires tmux, Claude Code cross-session messaging (`ListAgents`, `SendMessage`), `/work:spawn` (starts sessions) and `/work:handover` (writes takeover prompts). Skills installed with `npx skills` drop the `work:` prefix (`/spawn`, `/handover`), and the handover nudge is not installed. Alternative launchers also need `jq`.

Files in this skill:
- `${CLAUDE_SKILL_DIR}/../spawn/scripts/spawn.sh`: the `/work:spawn` script; run it directly to start a worker. It prints `target=<tmux target> pane=<pane id> session=<name> launcher=<name>`.
- [worker-rules.md](worker-rules.md): appended to every worker prompt.
- [handler-brief.md](handler-brief.md): given to every handler subagent.
- [leases.md](leases.md): VMs and hardware; read it when the first lease request arrives.
- [../spawn/launchers.md](../spawn/launchers.md): the optional local launchers file and its schema.

## Launch

1. Rename yourself `<project>-master` (ask the owner for the project name if unknown), unless `ListAgents` shows you already have that name (a successor master starts with it). Run `${CLAUDE_SKILL_DIR}/../spawn/scripts/rename-self.sh <project>-master` with Bash `run_in_background: true` and end your turn right after so the input lands (see `/work:spawn`, "Rename this session"). When re-invoked, check with `ListAgents` (its first line names this session) before spawning anyone: workers reporting to an unclaimed name lose their messages. Never tell the owner to rename you.
2. Make a temp dir for prompt files; nothing goes in the repo: `dir=$(mktemp -d "${TMPDIR:-/tmp}/orchestrate.XXXXXX")`.
3. Read the launchers file (`${XDG_CONFIG_HOME:-$HOME/.config}/agent-marketplace/spawn/launchers.json`, see [../spawn/launchers.md](../spawn/launchers.md)). Keep its launchers, with their `use_for` and `avoid_for`, as the list you pick from for every spawn. If the file is missing, `claude` is the only launcher.
4. Ask the owner, in one batch, only what has no default:
   | item | default |
   |---|---|
   | tmux session | current one (`tmux display -p '#S'`) |
   | slot limit | 4 |
   | launcher and model | per unit, see **Models** |
   | repos + policy (may-merge / never-merge / docs) + base branch | none; must ask |
5. Agree the unit breakdown with the owner before spawning.

If this session started from a master handover prompt, follow its first lines instead (announce, resume), then do step 3.

## Operating rules

1. **Do the minimum yourself**: owner conversation, prioritising, spawning, relaying `FOR OWNER` items, lease grants.
   - Every incoming worker message goes to a background subagent with the message verbatim, the worker's session name and tmux window, the repo policy, and [handler-brief.md](handler-brief.md). When it returns `CLOSE <window>`, close that window (`tmux kill-window -t <window>`) and free the slot. Model `sonnet` for mechanical messages (started); `opus` for judgement (done, blocked, review). Lease requests and releases are yours; see [leases.md](leases.md).
   - Long writing (worker prompts, reports) goes to `sonnet` subagents.
2. **Slot limit**: at most N implementation workers, i.e. sessions that own a unit's branch. Specialists do not count: sessions with one standing role and no unit branch, such as the hardware session, a reviewer, or an owner-interactive topic session.
3. **Act on clear next steps**: planned unit + free slot → spawn and say so. Ask the owner only for genuine decisions, outward-facing actions, or owner-only areas. Recommend first, then ask; plain options, no codenames.
4. **Verify before relaying**: PR state, SHAs, test results. Never fabricate a pending agent's result.
5. **Review rule**: no merge without an independent reviewer that is not the worker (`/work:pr` enforces it).
6. Workers and subagents never use AskUserQuestion. Only the master asks the owner.
7. Message only sessions you spawned or the owner named. Unknown recipient → report to the owner and stop.

## Models

Pass the model explicitly on every subagent (`model`) and every worker (`--model`). Never rely on the inherited default.

| work | model | how |
|---|---|---|
| master (this session) | `opus` | the owner launches it |
| research, fact-finding, mechanical handlers, long writing | `sonnet` | subagent `model: "sonnet"`; worker `--model sonnet` |
| implementation workers | `sonnet`, or a registered launcher whose `use_for` fits; master's choice per unit | `--model sonnet`, or `--launcher <name> --model sonnet` |
| decisions, judgement handlers, reviews | `opus` | subagent `model: "opus"`; worker `--model opus` |
| optional: complex decisions that need an advisor | `fable` | subagent `model: "fable"`, only if the owner's account offers it |

- `fable` is for a single decision only: give it the facts, get a recommendation back. Never give it research, implementation, review, or any long-running task; its token limits are tight. Without it, use `opus`.
- Workers start with plain `claude` unless you pass `--launcher <name>` for a launcher from the list read at Launch step 3; obey its `use_for` and `avoid_for`.

## Spawning a worker

1. Write `$dir/<worker-name>.md`: a few bullets, no step lists.
   - You are `<worker-session-name>`; your master is `<project>-master`.
   - Unit: the outcome in one or two lines.
   - Repo, base branch, branch, worktree `<repo>/.claude/worktrees/<unit>`.
   - Done means: gates pass, PR/branch state per repo policy. Send one "done" message with PR URL, head SHA, gate results.

   Then append the worker rules: `cat "${CLAUDE_SKILL_DIR}/worker-rules.md" >> "$dir/<worker-name>.md"`.
2. Spawn:
   ```bash
   "${CLAUDE_SKILL_DIR}/../spawn/scripts/spawn.sh" --launcher <name> --model sonnet --name <worker-session-name> --env ORCH_ROLE=worker \
     --session <session> --window-name <short-name> --cwd <start-dir> "$dir/<worker-name>.md"
   ```
   Always pass `--launcher`, `--model`, `--name` and `--env ORCH_ROLE=worker` explicitly; otherwise the worker inherits this session's values. The worker starts as `<launcher command> -n <worker-session-name>`, so it is addressable by that name from the start. `HANDOVER_PERCENT` passes through for the handover nudge. The script exits non-zero if the launcher is unknown, the start dir is untrusted, or the session exits at launch; report that to the owner. Flags and env: see `/work:spawn`.
3. Confirm the name with `ListAgents`.

Manual sends: always `send-keys -l '<text>'`, then `send-keys Enter` as a separate call.

## Shared resources

VMs and hardware are leased by you, never by handlers. Read [leases.md](leases.md) when the first lease request arrives.

## Handover

In Claude Code, the `work` plugin's hook nudges every session to run `/work:handover --auto` once it passes `HANDOVER_PERCENT` (default 45, `off` disables) of its context. That skill routes a master here and a worker (`ORCH_ROLE=worker`) to its worker rules.

`/work:handover` writes every takeover prompt to a temp dir. Use that path directly.

### Master (this session)
Trigger: the handover nudge (`/work:handover --auto`), or the owner asks.
1. Stop spawning. Let in-flight handlers finish.
2. SendMessage every live worker: "Master handover in progress. Hold all messages to `<project>-master` until you get 'handover done'."
3. Run `/work:handover --continue` with args: "master orchestrator takeover: tmux session, live windows with session names and units, repo policies, slot limit, leases, queue, pending owner decisions with recommendations, owner quotes, held worker list, prompt-file dir `$dir`". Put these lines first in the prompt:
   - "Run `/work:orchestrate`. You are the successor master, already named `<project>-master`."
   - "Send every live worker: 'handover done; resend anything you held'."
4. `--continue` hands the prompt to `/work:spawn --replace`: the successor starts in this window with this session's name, model and launcher, then closes this pane. Pass `--name <project>-master --model opus` if spawn cannot infer them. Both sessions briefly share the name; workers are holding, so nothing is misrouted.
5. Stop.

### Worker or specialist
Trigger: the worker reports it needs a handover, or the master decides.
1. SendMessage: "Stop at a safe point. Run `/work:handover` covering state, undo steps, rules, owner quotes, open jobs. Reply with the path."
2. Check the prompt is self-contained and includes the worker rules.
3. Close the old window: `tmux kill-window -t <session>:<window>`.
4. Spawn the successor as in **Spawning a worker**, under the original name, with the handover path as its prompt file.

### Owner-interactive topic sessions
Allowed for a single topic (e.g. a write-up): write a prompt file, start it with `/work:spawn` (no `ORCH_ROLE`), tell the owner the window, close it when the owner says it's done.
