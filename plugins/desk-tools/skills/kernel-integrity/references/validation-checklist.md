# Validation / Audit Checklist

## PASS requires

Intake classification completed; original kernel inventoried by function; function matrix
completed before drafting; protected functions identified; compression decisions assigned;
revised candidate drafted; relocation map completed; no-loss table completed; hard stops
preserved in always-on control; prompt-bank behavior preserved or properly relocated;
audit/no-loss behavior preserved; logical-file parse rule applied when triggered; runtime/archive
split preserved; candidate-only rule preserved; human-review gates preserved; defects and holds
identified; repair prompts supplied; readiness label assigned; Next Prompt Block supplied.

## Automatic HARD HOLD

Assign HARD HOLD if the task asks or requires: protected-baseline overwrite; live/production use;
publication; connector enablement; production/canonical promotion; deleting guardrails silently;
removing human-review gates; removing source-role separation; removing audit or prompt-bank
behavior; treating a candidate as canonical; or using a logical-file title summary as source basis.

## FAIL conditions

Function matrix skipped; a guardrail silently removed; source-role rules weakened; hard stops
moved out of always-on control without substitute wording; prompt-bank behavior disappears;
audit/no-loss behavior disappears; logical-file controls ignored; generated candidate treated as
source authority; no-loss table falsely marks weakened behavior as preserved; runtime/archive
separation collapses; a human-review gate removed.

## Severity classification

| Severity | Examples | Required result |
|---|---|---|
| Critical | Hard stops, candidate-only rule, protected baseline, live-material bar, human gate, source-role lock, logical parse rule | HARD HOLD / FAIL |
| Major | Function matrix, relocation map, no-loss table, prompt routes, audit behavior, runtime/archive split | SOFT HOLD or FAIL until repaired |
| Moderate | Examples, long explanation, redundant setup prose, optional prompt variants | PASS-WITH-NOTES or repair |
| Minor | Typo, formatting, nonfunctional duplication | PASS-WITH-NOTES |

## Readiness labels

- **PASS** — function preserved; no critical or major loss; candidate ready for human review.
- **PASS-WITH-NOTES** — function preserved with minor caveats or moderate nonfunctional losses.
- **SOFT HOLD** — repair or human decision required before use.
- **HARD HOLD** — protected-baseline, live-material, promotion, publication, connector, or
  guardrail-removal issue.
- **FAIL** — function loss, source-role collapse, or unsafe candidate that cannot be repaired
  within scope.

A PASS never means canonical promotion or production deployment unless separately human-approved.

## Final audit questions

1. Does the candidate preserve the same operating behavior?
2. Are all moved functions relocated to the right layer?
3. Would a user still receive the same stop/downgrade behavior?
4. Would a user still receive the same prompt-bank routes?
5. Would a user still receive audit/no-loss/human-review controls?
6. Are setup, runtime, validation, and archive sources separated?
7. Is the candidate clearly not canonical?
8. Is human review required before promotion?
