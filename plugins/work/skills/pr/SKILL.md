---
name: pr
description: Checks that a pull request reported as done really is, gets it an independent review, and finishes it by the repo's policy (squash merge, leave as draft, or push docs). Use when asked to check, review and land, or wrap up a PR or branch, especially work done by another session or agent.
argument-hint: "<PR URL or number> [may-merge | never-merge | docs]"
allowed-tools: Bash(gh pr view *) Bash(gh pr checks *) Bash(git status *) Bash(git log *) Bash(git rev-parse *) Bash(git fetch *)
---

# PR

Finish the PR in `$ARGUMENTS`. The second argument is the policy. When it is missing, ask the user, or return the question when you run as a subagent.

1. **Verify every claim** against the source instead of the report: `gh pr view` (state, draft, base, head SHA), `gh pr checks`, gate results, files on disk. A claim that does not match is a finding: stop and report it.
2. **Get an independent review** before any merge, from a reviewer who is not the author (`/code-review`, or a separate subagent that gets the diff and not the author's summary). Blocking findings go back to the author, and you stop.
3. **Finish by policy**:
   | policy | steps |
   |---|---|
   | may-merge | update the branch from the base if it is behind, re-run the gates, then squash-merge with `gh pr merge <n> --squash --delete-branch` and remove its worktree |
   | never-merge | confirm the PR is open, a draft and unmerged, and leave it that way |
   | docs | commit and push the working branch, and leave its PR unmerged |
4. **Report** what you verified (PR, SHA, checks), the review result, what you did, and what is left for the user, with a recommendation.

Merge with no `--subject` or `--body`, so GitHub appends `(#NNN)` to the squashed subject and the history on the protected branch keeps its format. Push to a protected branch only through that merge, push to other branches without force, and keep secrets out of all output.
