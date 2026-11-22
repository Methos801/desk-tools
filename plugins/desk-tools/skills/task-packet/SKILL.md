---
name: task-packet
description: "ONLY for the desk task-packet workflow or an explicit task-packet request. Defines packet format, lifecycle, sizing, acceptance checks, and result recording for desk-packet-planner, desk-local-worker, and desk-reviewer. Never use as a fallback for missing tools."
argument-hint: Packet id, or the work to package
user-invocable: true
disable-model-invocation: false
---

# Task Packet

A task packet is one Markdown file that lets a local model finish one piece of work in a fresh session with no memory of the planning conversation.

## Location and naming

- Folder: `.desk/packets/` at the workspace root. Packets are meant to be committed with the work they describe.
- File name: `P###-short-slug.md` (for example `P004-fix-date-parser.md`). Numbers only increase; never renumber or reuse.
- `README.md` in the same folder holds the index and any `NEEDS-STRONG-MODEL` notes.

## Template

````markdown
---
id: P004
title: Fix ISO date parsing in the importer
status: OPEN
depends_on: []
budget: 32K
est_tokens: 7400
---

## Objective
<One sentence. What is true when this packet is done.>

## Files in scope
- `src/importer/dates.py` — edit
- `tests/test_dates.py` — edit
- `src/importer/README.md` — read

## Out of scope
- <Things the worker must not touch or attempt.>

## Facts the worker needs
- <Every fact from planning the worker would otherwise have to rediscover, each with its source.>

## Steps
1. <At most 5 concrete steps.>

## Acceptance checks
- [ ] `python -m pytest tests/test_dates.py -q` → all tests pass
- [ ] <Observable condition, never "looks good".>

## Stop conditions
- The same step fails twice.
- A file not listed as `edit` needs to change.
- A fact above turns out to be wrong, or ambiguity would change the result.

## Escalation
desk-code-builder on a strong model

## Result
<Filled in by desk-local-worker: status set, files changed, each check and its result, notes.>

## Verification
<Filled in by desk-packet-planner from desk-reviewer's verdict.>
````

## Status lifecycle

| Status | Set by | Meaning |
|---|---|---|
| `OPEN` | planner | Ready to run once every `depends_on` packet is `DONE` or `VERIFIED`. |
| `IN-PROGRESS` | worker | Worker has started. |
| `DONE` | worker | Every acceptance check passed. |
| `BLOCKED` | worker | A stop condition fired; `## Result` says which. |
| `ESCALATED` | worker | Needs a stronger model or wider scope. |
| `VERIFIED` | planner | Reviewer re-ran the checks and passed it. |
| `REJECTED` | planner | Reviewer found defects; a fix packet follows. |

Only the planner writes `VERIFIED` or `REJECTED`, and only from a reviewer verdict. The worker only edits its own packet's `status:` and `## Result`.

## Sizing

- Estimate tokens as characters ÷ 4 for the packet plus every in-scope file.
- 32K session: at most about 12K tokens. 64K: at most about 24K. The rest of the context goes to Copilot's own instructions, tool definitions, reasoning, and output.
- At most 5 files and 5 steps. If it does not fit, split it; if it cannot be split without a design decision, it is not a packet — note it as `NEEDS-STRONG-MODEL` in `README.md`.

## Good packets

- One objective a reviewer can check mechanically.
- Acceptance checks that are commands with expected results, or conditions anyone could confirm.
- No hidden dependencies on the planning conversation.
- Judgment-light: classification, summarization, narrow edits, test repairs, mechanical refactors, data transformations.
