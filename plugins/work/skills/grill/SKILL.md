---
name: grill
description: Interviews the user about the current plan, idea or document until every open question has an answer. Each round, fresh subagents look for questions nobody has asked yet, and the user gets them in batches with a recommendation on each. Use when the user wants a plan stress-tested, ambiguities found, or says "grill me" or "grill this".
---

# Grill

Question the subject in context (a plan, a design, a document, a half-formed idea) until you and the user share one understanding. Every open decision ends up answered by the user, answered by research, or deferred on purpose. Research answers what research can, so ask the user only about judgment calls. Run the interview in the main session, because subagents and workflows cannot reach the user.

## Args

One of:
- nothing: grill the plan or ideas already in the conversation.
- `<path>`: a file or directory to grill (a spec, README, proposal, design doc, area of the codebase). Read it first. Step 4 says when to write answers back into it.
- free text: a topic or plan stated inline. Treat it as the subject.

## Workflow

Keep a list of every question asked so far with its answer, or "deferred" or "open". Give the whole list to every discovery subagent, so each round builds on settled ground instead of rediscovering it.

Each round:

1. **Discover.** Start one or two `general-purpose` subagents to find open questions with fresh eyes, in parallel in one message when using two. Subagents cannot see this conversation, so each prompt holds:
   - the subject: the plan text, the file contents, or a faithful summary of the discussion;
   - the full list of questions and answers, marked as settled, with the instruction to find what it missed and leave those and their variants alone;
   - the request: return a list of `{ question, why it matters, recommended answer with reasoning, real alternatives }`, looking for unstated goals, hidden assumptions, alternatives rejected without comment, what breaks the plan, scope boundaries, edge cases, success criteria, and contradictions with earlier decisions.
   - With two subagents, give each a different lens, for example one adversarial ("what breaks this, what is missing") and one clarifying ("what is ambiguous or underspecified"), so their findings differ.
2. **Triage.** Resolve a question yourself when files, the web or a quick check can answer it, and record it as answered by research. Queue the genuine judgment calls for the user. Drop duplicates of earlier questions. Put upstream decisions first, ahead of the questions they gate.
3. **Interview.** Ask the queued questions in batches of up to four, in dependency order, using whatever way of asking the user your environment offers. Write each question so the user can answer it without having read anything else: say what is being decided and why it matters, then give your recommendation first with the reason, then the real alternatives. Every question carries a recommendation, and the user can always answer in their own words.
4. **Record.** Add each answer to the list. When the subject is a file the user owns and the answers change it, update the file and cite the user's answer as the source. Otherwise keep a running list of decisions in your reply.
5. **Loop.** Answers can open new questions, so start the next round with the updated list.

## Finishing

- Done: a discovery round that received the full list finds no new questions and nothing is deferred. Write the summary below.
- After 5 rounds with questions still open, ask the user whether to continue.
- When the user says stop, write the summary with the open items marked.

## Summary

- Decisions, one per line, in the order resolved: question, answer, reason.
- Items answered by research, one line each, with what settled them.
- Open or deferred items.
- Files changed, if any.

## Boundaries

- Subagents only discover. The interview happens in the main session.
- Explore before asking: a question that the repo, the web or the subject answers costs the user a turn for nothing.
- Change only the subject the user pointed at.

$ARGUMENTS
