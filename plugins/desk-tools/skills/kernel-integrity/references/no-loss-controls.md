# No-Loss Controls

## Core rule

No-loss is **function preservation, not word preservation**. A function is not preserved if the
user would no longer receive the same guardrail, routing, audit, downgrade, stop, or human-review
behavior.

## Required no-loss table

Maintain one row per function:

```text
Original function:
Original location:
Protected function? yes/no:
Candidate handling:
Candidate location:
Relocation destination if moved:
Risk:
Repair:
Status:
```

## Severity model

| Severity | Description | Result |
|---|---|---|
| Critical loss | Hard stop, human gate, source-role lock, candidate-only rule, protected-baseline rule, logical-file parse rule, live-material prohibition, or deployment/promotion limit removed or weakened. | HARD HOLD / FAIL |
| Major loss | Stage routing, function matrix, relocation map, prompt-bank route, audit/no-loss behavior, restart handoff, or runtime/archive split weakened. | SOFT HOLD or FAIL until repaired |
| Moderate loss | Examples, format guidance, prompt variants, setup clarity, optional dry-run specificity lost. | PASS-WITH-NOTES if nonfunctional; repair preferred |
| Permitted compression | Duplicative wording or long explanation compressed without functional loss. | PASS if the no-loss table confirms |

## Repair loop

When loss is found: 1. identify the lost or weakened function; 2. decide whether it must return
to the kernel or can be relocated; 3. repair the candidate or relocation map; 4. update the
no-loss table; 5. reassign the readiness label; 6. if repair requires human judgment, assign HOLD.

Never mark weakened behavior as "preserved" in the table — a false PASS row is itself a FAIL
condition.
