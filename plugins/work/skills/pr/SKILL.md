---
name: pr
description: Checks that a pull request someone reports as done really is, gets it an independent review, and finishes it according to the repo's policy (merge, leave as draft, or push docs). Use when asked to check, review and land, or wrap up a PR or branch, especially work done by another session or agent.
argument-hint: "<PR URL or number> [may-merge | never-merge | docs]"
allowed-tools: Bash(gh pr view *) Bash(gh pr checks *) Bash(git status *) Bash(git log *) Bash(git rev-parse *) Bash(git fetch *)
---

# PR

Finish the PR in `$ARGUMENTS`. The policy is the second argument; if missing, ask the user (when you run as a subagent, return the question instead of asking).

1. **Verify every claim** against the source, not the report: `gh pr view` (state, draft, base, head SHA), `gh pr checks`, gate results, files on disk. A claim that doesn't match is a finding; stop and report it.
2. **Independent review** before any merge: a reviewer that is not the author (`/code-review`, or a separate subagent given the diff, not the author's summary). Blocking findings go back to the author; stop.
3. **Finish by policy**:
   | policy | steps |
   |---|---|
   | may-merge | rebase onto the base branch → re-run the gates → fast-forward the base branch and push it → delete the branch and its worktree |
   | never-merge | confirm the PR is open, a draft and unmerged. Never mark it ready or merge it |
   | docs | commit and push the working branch. Never merge its PR |
4. Report: what you verified (PR, SHA, checks), the review result, what you did, and anything left for the user with a recommendation.

Never push to a protected branch except the may-merge fast-forward, never force-push, never print secrets.
