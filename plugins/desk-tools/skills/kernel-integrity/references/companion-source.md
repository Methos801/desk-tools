# Companion Source — operational detail

This is the operational layer behind the always-on kernel in SKILL.md. Read it when you need
detail beyond the compact kernel: the full control hierarchy, source-role table, stage ladder,
and known failure modes.

## Control hierarchy

1. Current user instruction and requested deliverable.
2. Target platform, size limit, deployment surface, audience, downstream use, risk level.
3. Original kernel and current approved source basis.
4. Uploaded companion, prompt-bank, audit, router, logical-file, deployment, validation sources.
5. Generated outputs as workpapers only, unless human-reviewed and adopted.

## Out of scope

This skill does not: apply a workflow to live/production material; produce legal advice; verify
legal authority; publish or promote agents; enable connectors; overwrite protected baselines;
treat a compressed candidate as canonical; or collapse runtime, validation, setup, and archive
sources into one pile.

## Source-role table

| Source type | Role | Runtime treatment |
|---|---|---|
| Original kernel | Functions to preserve | Source basis; never overwritten by this skill |
| Companion source | Operational detail and moved controls | Reference knowledge |
| Prompt bank | User-facing kickoff, repair, restart, stage prompts | Reference knowledge |
| Audit / validation | Pass/fail checks, severity model, no-loss table, tests | Reference or validation-only |
| Deployment note | Setup, install/upload stack, promotion holds | Setup source |
| Checkpoint / resume | Continuity and restart state | State artifact |
| Maintainer / archive | Prior versions, adoption ledgers, superseded materials, examples | Archive only unless auditing lineage |
| Generated candidate | Draft only | Workpaper; not source authority |

Source-role rules: do not treat a generated candidate as source authority until human-approved;
do not replace the original kernel automatically; do not merge setup, runtime, validation, and
archive files merely to avoid loss; preserve source roles in every relocation map; if a role is
ambiguous, HOLD and ask.

## Function classes

Inventory every kernel by function. Common classes: identity/scope; source-role rules; intake
classification; hard stops; work-stage routing; prompt-bank routing; audit/lint behavior;
no-loss controls; human-review gates; deployment/promotion limits; runtime/archive separation;
restart/handoff/Next-Prompt behavior; logical-file parsing; protected-baseline rule;
candidate-only rule; platform-specific constraints; source-integrity/authority-audit triggers
where legal or high-stakes workflows are involved.

## Change decision types

For each function assign exactly one (which options apply depends on the change type — a merge adds
"reconcile with the other kernel's version," a split adds "assign to shard X"): **keep in kernel**
(always-on); **compress in kernel**
(shorter, same function); **move to companion** (long operational detail); **move to prompt bank**
(user-facing prompt); **move to audit/deployment** (validation, checklist, setup, promotion
control); **archive/source-basis only** (history, superseded, example, lineage); **omit with
reason** (duplicative/nonfunctional only — never a control); **HOLD** (human decision required).

## Protected functions (anti-thinning layer lock)

A change must preserve: identity and scope; source-role separation; hard stops; staged
workflow; prompt-bank routing; audit/no-loss checks; deployment/promotion limits; restart/handoff
prompts; runtime/archive separation; logical-file parse discipline; protected-baseline rule;
generated-candidate-only rule; human-review gates. If any protected function would be removed,
weakened, or moved out of always-on control without an equivalent substitute, assign HOLD or FAIL.

## Stage ladder

- **Stage 0 — Intake classification.** Collect platform, size limit, source layers, completeness,
  risk, live-material risk, protected-baseline status, logical-file status, requested deliverable,
  and whether the ask is a port / merge / split / trim / bloat-audit / review / repair / validation
  / setup / promotion. Output:
  classification, immediate hard stops, source gaps, safe next stage.
- **Stage 1 — Function inventory.** Break the kernel into functions (not paragraphs); identify
  what each rule does and which source supports it. Output: function matrix, source-basis map,
  protected-function flags.
- **Stage 2 — Change decision table.** Assign keep/relocate/compress/merge/split/archive/omit/HOLD
  to each function according to the change type. Do not draft before this table. On a merge, scan
  for conflicting controls across the two kernels; on a split, check each shard keeps its own
  always-on controls.
- **Stage 3 — Candidate draft.** Revised kernel that keeps always-on identity, scope, source-role
  rules, hard stops, intake, function-matrix requirement, no-loss, human gates, candidate-only
  status, and the output contract.
- **Stage 4 — Relocation map.** Map every moved function to its destination layer.
- **Stage 5 — No-loss review.** Compare original to candidate; classify preserved / compressed /
  moved / archived / omitted / HOLD.
- **Stage 6 — Repair loop.** Repair any weakening before labeling; if repair needs human
  judgment, HOLD.
- **Stage 7 — Readiness / handoff.** Readiness label + Next Prompt Block. Do not self-execute.

## Runtime / archive split

Runtime = only what ordinary operation needs. Validation = testing, preview, dry runs, audits.
Setup = human install guidance. Archive/source-basis = history, prior versions, adoption ledgers,
superseded materials, maintainer notes. Do not load archive/source-basis material into runtime
merely to avoid loss — preservation happens by manifesting and archiving, not by runtime overload.

## Known failure modes

1. Role drift into live/production work. 2. Kernel bloat. 3. Source-stack overloading.
4. Stale/duplicate source conflict. 5. Example contamination. 6. Source-integrity/authority-audit
dilution. 7. Router overreach. 8. No-loss failure. 9. Logical-file compression from summaries.
10. Runtime/archive collapse. 11. Candidate treated as canonical. 12. Protected baseline
overwritten. 13. Prompt-bank behavior lost. 14. Hard stops moved out of always-on control.
15. Human-review gates softened.

## Human-review gates

Human review is required before: promoting a candidate; replacing a source kernel; overwriting a
protected baseline; publishing or enabling connectors; using the skill on live/production
material; treating a validation PASS as deployment approval; merging runtime and archive stacks;
or removing/substituting hard stops, human gates, source-role rules, audit behavior, or
prompt-bank behavior.
