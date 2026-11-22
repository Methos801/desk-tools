---
name: checkpoint-handoff
description: Produce a compact continuation record for a long or interrupted work session so the next session can resume without replaying the full conversation.
argument-hint: Where to save the checkpoint (optional; otherwise it is returned in chat)
user-invocable: true
disable-model-invocation: false
---

# Checkpoint Handoff

Create a concise state record, not a conversation transcript.

Include:

- current objective;
- decisions already made;
- assumptions still in force;
- files changed;
- relevant commands or tests run;
- current result;
- unresolved defects or questions;
- exact next logical action;
- an immediately usable continuation prompt when useful.

Preserve concrete names, paths, versions, constraints, and error messages needed to continue accurately. Omit obsolete discussion, repeated reasoning, and low-value narration.

```
Objective:
Decisions made:
Assumptions in force:
Files changed:
Commands/tests run and results:
Current result:
Unresolved:
Next action:
Continuation prompt: <paste-ready prompt for a fresh session>
```

If the user named a location, write the checkpoint there as Markdown. If the work uses task packets, point to `.desk/packets/` instead of repeating packet contents.
