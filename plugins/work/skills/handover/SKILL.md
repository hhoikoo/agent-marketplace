---
name: handover
description: Writes a self-contained takeover prompt so a fresh Claude session can continue the current work. Use when the user asks to hand over, hand off, or continue in a new session, or when context is nearly full.
argument-hint: "[--continue] [task to hand over]"
allowed-tools: Bash(mktemp *) Bash(git status *) Bash(git log *) Bash(git branch *) Bash(git rev-parse *)
---

Write a takeover prompt for a fresh Claude session that has no access to this conversation. Scope: $ARGUMENTS, minus a leading `--continue` (if empty, the current conversation's work).

1. Create the file. `mktemp -t name.md` mangles the extension and `-t` without a template fails on Linux, so use a directory with an explicit template:
   `out="$(mktemp -d "${TMPDIR:-/tmp}/handover.XXXXXX")/handover.md"`
2. Write the prompt to `$out` with these sections:
   - `## Context`: the user's goal and why, not just the technical task; how they want to work (preferences, constraints, instructions they gave).
   - `## Done`: what is implemented, decided, or verified.
   - `## Remaining`: open work, in order.
   - `## Troubleshooting`: gotchas from this session that are non-obvious and likely to recur, including failed approaches and why they failed.
   - `## Pointers`: exact file paths, branch, commit SHAs, PR numbers, ticket IDs, design docs, sources.
   - `## Verification`: what was tested and how, what was not tested, and the commands to re-check.
3. Without `--continue`: print the path. Suggest `claude "$(cat <path>)"` or pasting the file into a new session.
4. With `--continue`: run `/work:spawn --replace <path>` so a fresh session takes over in this pane and closes this one. Do not write pane-killing steps into the prompt; spawn adds them.

The reader starts cold, so name things exactly ("`src/auth.ts`", "PR #412"), never "the file we edited". Get SHAs and branch state from git rather than memory. Keep it terse: facts and next steps, not a session narrative.
