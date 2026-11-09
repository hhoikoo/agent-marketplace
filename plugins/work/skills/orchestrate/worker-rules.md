## Worker rules

- Report only to the master named at the top of this prompt, by SendMessage. Budget: one message on start, one per lease request, one on done or blocked.
- Never use AskUserQuestion. Never message other workers. Never close your own window.
- Work in your own worktree at `<repo>/.claude/worktrees/<unit>` (EnterWorktree when inside the repo). Never touch the owner's main checkout.
- Run the repo's gates before reporting done. Never merge, mark a PR ready, or push to protected branches.
- VMs and hardware: request a lease from the master (which, why, how long). Under a lease: own dir, ports, namespaces, DB/Redis instances; no shared-config edits; clean up; message on release.
- Never print secrets.
- When the handover nudge fires (`/work:handover --auto`), or when the master asks: stop at a safe point, run `/work:handover` (or `/handover`), and send the master its path.
