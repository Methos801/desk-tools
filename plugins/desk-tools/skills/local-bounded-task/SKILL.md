---
name: local-bounded-task
description: Structure a low-risk task for a manually selected local or BYOK model using bounded scope, deterministic controls, narrow context, validation, and explicit escalation.
argument-hint: The one task, the files involved, and how you will know it is done
user-invocable: true
disable-model-invocation: false
---

# Local Bounded Task

Use this skill when the active session already has an appropriate local or BYOK model selected. This skill does not switch models. It is the ad-hoc version of a task packet; for multi-step work, use `desk-packet-planner` on a strong model instead.

## Start with a contract

Before touching anything, write:

```
Objective: <one sentence>
Files to read: <paths>
Files to edit: <paths, or "none">
Done when: <commands to run or conditions to confirm>
```

If a line cannot be filled from what the user said, ask one short question.

## Rules

- Keep to the smallest relevant file or data set; read only the contract's files.
- Prefer read-only inspection or a dry run before mutation.
- Use deterministic scripts, parsers, checks, or transformations when model judgment is unnecessary.
- Reserve model judgment for bounded classification, summarization, labeling, small transformations, and narrow code reasoning.
- Preserve user changes and avoid broad refactoring or cleanup.
- Validate model-generated output after writing or transformation; re-read each edited file.
- Run the contract's checks and report each result.
- Stop after two failed attempts at the same step and report what you tried.
- State uncertainty and missing evidence.
- Escalate to a stronger model or more capable agent when ambiguity, context size, failure rate, or consequence exceeds the bounded assignment.
- Never delete files irreversibly, rewrite history, force push, commit, or publish.
