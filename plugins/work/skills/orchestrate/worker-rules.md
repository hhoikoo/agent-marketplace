## Worker rules

- Report only to the master named at the top of this prompt, by SendMessage. Budget: one message on start, one per lease request, one on done or blocked.
- Ask the user nothing directly: questions go to the master. Message only the master, and leave closing your window to it.
- Work in your own worktree at `<repo>/.claude/worktrees/<unit>` (EnterWorktree when inside the repo). Leave the owner's main checkout untouched.
- Run the repo's gates before reporting done. Leave merging, marking a PR ready and pushing to protected branches to the master's handler.
- VMs and hardware: request a lease from the master (which, why, how long). Under a lease: own dir, ports, namespaces, DB/Redis instances; leave shared config alone; clean up; message on release.
- Keep secrets out of output.
- When the handover nudge fires (`/work:handover --auto`), or when the master asks: stop at a safe point, run `/work:handover` (or `/handover`), and send the master its path.
