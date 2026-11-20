---
name: handover
description: Writes a self-contained takeover prompt so a fresh Claude session can continue the current work. Use when the user asks to hand over, hand off, or continue in a new session, or when context is nearly full.
argument-hint: "[--continue | --auto] [task to hand over]"
allowed-tools: Bash(printenv ORCH_ROLE) Bash(mktemp *) Bash(git status *) Bash(git log *) Bash(git branch *) Bash(git rev-parse *) Bash(tmux kill-pane *)
---

Write a takeover prompt for a fresh Claude session that has no access to this conversation. Scope: $ARGUMENTS, minus a leading `--continue` or `--auto` and minus any request for a fresh session (if empty, the current conversation's work). With `--auto`, start at **Auto** below.

1. Create the file. Use a directory with an explicit template, because `mktemp -t name.md` mangles the extension and `-t` without a template fails on Linux:
   `out="$(mktemp -d "${TMPDIR:-/tmp}/handover.XXXXXX")/handover.md"`
2. Write the prompt to `$out` with these sections:
   - `## Context`: the user's goal and why, not just the technical task; how they want to work (preferences, constraints, instructions they gave).
   - `## Done`: what is implemented, decided, or verified.
   - `## Remaining`: open work, in order.
   - `## Troubleshooting`: gotchas from this session that are non-obvious and likely to recur, including failed approaches and why they failed.
   - `## Pointers`: exact file paths, branch, commit SHAs, PR numbers, ticket IDs, design docs, sources.
   - `## Verification`: what was tested and how, what was not tested, and the commands to re-check.
3. Decide whether to continue. Continue when any of these holds, unless `ORCH_ROLE=worker` (a worker sends its path to the master instead):
   - the arguments start with `--continue`;
   - the user asked for a fresh or new session to take over (for example "hand over to a fresh session", "continue in a new session") and `$TMUX_PANE` is set.

   Otherwise print the path and suggest `claude "$(cat <path>)"` or pasting the file into a new session. When the user asked for a fresh session but `$TMUX_PANE` is unset, say that no tmux pane exists to replace.
4. To continue: first finish everything else, including notes, messages and background tasks (wait for them or stop them). Then run `/work:spawn --replace <path>` (`/spawn` when installed with `npx skills`) so a fresh session starts beside this pane, and run the `close:` command it prints as your final tool call, with nothing after it. That ends this session mid-turn: this turn's Stop hooks do not run, and SessionEnd hooks do. Leave pane-closing steps out of the prompt, because the successor must leave this pane alone.

The reader starts cold, so name things exactly ("`src/auth.ts`", "PR #412") instead of "the file we edited". Get SHAs and branch state from git rather than memory. Keep it short: facts and next steps, with no session narrative.

## Auto

`--auto` comes from the context nudge (the `work` plugin's hook, in Claude Code). Finish the current step and stop at a safe point first. Then act by role, checking `printenv ORCH_ROLE` when unsure:

| role | action |
|---|---|
| orchestrate master (you ran `/work:orchestrate`, or `ORCH_ROLE=master`) | follow `/work:orchestrate`'s "Handover → Master (this session)" steps instead of this skill |
| orchestrate worker (`ORCH_ROLE=worker`) | write the prompt (steps 1 and 2, including your worker rules), then SendMessage its path to your master; leave the successor to the master |
| any other session inside tmux (`$TMUX_PANE` set) | as `--continue` |
| any other session | as without flags, and tell the user context is at the threshold |
