# Function Classification Guide

Supports the Step 2 function inventory. Improves classification consistency without overriding
hard stops, source-role rules, no-loss review, HOLD requirements, or candidate-only treatment.

## Conservative path (default)

Classify each function by likely role and record: function class; presumptively protected?
(yes/no); likely destination; ambiguity note; HOLD required? (yes/no).

## Presumptively protected cues

Treat a function as presumptively protected if it appears to govern: identity and scope;
prohibitions or hard stops; human-review gates; source-role separation; source authority or
protected-baseline treatment; candidate-only treatment; logical-file parsing or extraction
discipline; runtime/archive separation; prompt-bank preservation or routing; audit/no-loss
behavior; or readiness labels where loss would weaken a stop or gate.

## Likely role classes

Use role-oriented classification, not paragraph labeling: 1. identity/scope; 2. source-role rule;
3. hard stop or prohibition; 4. stage-gating rule; 5. prompt-bank routing; 6. audit/no-loss
behavior; 7. logical-file control; 8. authority/baseline control; 9. runtime/archive separation;
10. output-contract requirement; 11. checkpoint/handoff behavior; 12. setup-only or archive-only
support detail.

## Likely destination cues

- **keep in kernel** — always-on controls, identity, hard stops, stage gates, required bounded outputs.
- **compress in kernel** — shorter equivalent always-on wording.
- **move to companion** — longer operational detail.
- **move to prompt bank** — user-facing kickoff, repair, validation, restart, continuation prompts.
- **move to audit/deployment** — testing, severity, validation, checklist, setup, promotion control.
- **archive/source-basis only** — historical, superseded, example-only, lineage-only content.
- **HOLD** — role, authority, or destination remains ambiguous.

## Enhanced classification (opt-in only)

Enhanced classification applies stronger role-pattern cues but may require extra user answers.
Consider it only when the source is: dense/repetitive enough that manual separation is unreliable;
mixed-role with several protected functions embedded together; logically wrapped or
controller-like; ambiguous enough that hidden protected behavior is likely; or when the user
explicitly requests a stronger pass.

**User-choice gate:** never switch automatically. If enhanced classification appears prudent,
pause and ask whether to stay on the conservative path (stricter, defaults to HOLD sooner) or use
enhanced classification. If the user opts in, ask only what is needed to continue safely — typical
questions: Is the source primarily for compression, review, repair, validation, or
promotion-check? Should ambiguous functions default to HOLD or best-effort with notes? Should
mixed-purpose sections be split into multiple functions or treated as protected composites? If a
function matches multiple protected classes, HOLD immediately or propose a primary class with
secondary tags?

**Guardrail:** enhanced classification may support the function matrix but never overrides hard
stops, source-role separation, no-loss review, HOLD requirements, candidate-only treatment, or
human-review gates.
