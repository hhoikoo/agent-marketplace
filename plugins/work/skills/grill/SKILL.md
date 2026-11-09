---
name: grill
description: Interview the user about the current plan, idea, or document until every open unknown is resolved. Spawns fresh-eyed discovery subagents each round to surface new questions, then batches them to the user via AskUserQuestion. Use when the user wants their plan stress-tested, ambiguities flushed out, or says "grill me" / "grill this".
---

# Grill

Interrogate the subject in context — a plan, a design, a document, a half-formed idea — until shared understanding: every open decision is either answered by the user, answered by research, or explicitly deferred. A question that research can answer is explored, not asked. Main-session only: `AskUserQuestion` does not exist inside subagents or Workflows.

## Args

One of:
- nothing: grill the plan/ideas already in the current context window.
- `<path>`: a file or directory to grill (a spec, README, proposal, design doc, codebase area). Read it first; resolutions may be applied back to it (see Record).
- free text: a topic or plan stated inline; treat it as the subject.

## Workflow

Maintain a **Q&A ledger** across the whole session: every question asked so far with its answer (or "deferred"/"open"). This ledger is the convergence mechanism — it is fed verbatim to every discovery agent so rounds don't rediscover settled ground.

Each round:

1. **Discover.** Spawn 1–2 subagents (`general-purpose`; run them in parallel in one message when using two) to find open unknowns with fresh eyes. Each prompt must contain:
   - the subject (the plan text, file contents, or a faithful summary of the in-context discussion — subagents cannot see this conversation);
   - the full Q&A ledger, with the instruction: *these are settled — do not re-raise them or minor variants of them; find what they missed*;
   - the ask: return a list of `{ question, why it matters, recommended answer + reasoning, real alternatives }`, probing for: unstated goals, hidden assumptions, rejected-but-unmentioned alternatives, "what breaks this", scope boundaries, edge cases, success criteria, and contradictions with what's already decided.
   - When using two agents, give them different lenses (e.g. one adversarial "what breaks this / what's missing", one clarifying "what's ambiguous / underspecified") so they don't duplicate each other.
2. **Triage.** For each candidate question: answerable by reading files, searching the web, or checking facts yourself → resolve it that way and record it in the ledger as research-answered; genuine judgment call → queue it for the user. Drop duplicates and near-duplicates of ledger entries. Order the queue so upstream decisions come before the questions they gate.
3. **Interview** via `AskUserQuestion`, batched up to 4 questions per call, in dependency order. Each question: header is the decision at stake; first option is the recommended answer with its description stating why it is recommended; remaining options are the real alternatives. No open-ended "what do you think" — every question ships a recommendation. Free text stays available to the user automatically.
4. **Record.** Append each answer to the Q&A ledger. If the subject is a file the user owns and the answers change it, apply the resolutions in place (cite the user's answer as the source); otherwise keep the ledger in the reply as a running `Decisions` list.
5. **Loop.** Answers may unlock downstream questions — go back to step 1 with the updated ledger.

## Convergence

- Done: a discovery round (with the full ledger fed in) produces no new non-duplicate questions and nothing is deferred. Emit the shared-understanding block.
- Cap: after 5 rounds with questions still open → `AskUserQuestion` whether to continue.
- User says stop at any point → emit the block with open items marked.

## Output

Shared-understanding block:
- decisions: `question → answer → rationale`, one per line, in the order resolved.
- research-answered items (one line each, with what settled them).
- open/deferred items.
- files modified, if any.

## Rules

- Never run this skill's interview inside a Workflow or subagent; `AskUserQuestion` is main-session only. Subagents are for discovery only.
- Explore before asking: a question the repo, the web, or the subject itself can answer is a wasted user turn.
- Always feed the complete Q&A ledger to every discovery agent — this is what makes rounds converge instead of oscillate.
- Read-only outside the subject: don't modify files other than the subject the user pointed at.

$ARGUMENTS
