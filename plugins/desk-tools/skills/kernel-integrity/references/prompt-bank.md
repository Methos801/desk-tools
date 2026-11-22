# Prompt Bank

Ready prompts for the change types this skill covers — port, merge, split, trim, bloat-audit,
review, repair — plus checkpoint and capture. None of these override hard stops, source-role
rules, anti-thinning controls, no-loss review, candidate-only treatment, or human-review gates.

## Standard kickoff

```text
Review or change this development-only instruction kernel without losing function.
Change type (port / merge / split / trim / bloat-audit / review):
Source surface:
Target surface (and its size cap or attention budget):
Source layers supplied:
Protected baseline?:
Logical file or ordinary text?:
Requested output:

Before applying the change, classify it and build a function matrix. Preserve source-role
separation, hard stops, routing behavior, audit/no-loss controls, downgrade paths, human-review
gates, protected-baseline rules, runtime/archive separation, and candidate-only status. After the
change, run a no-loss audit against the original.
```

## Port to another platform

```text
Port this kernel from [source lane] to [target lane]. Preserve function across the lane change.
Determine what must stay always-on, what can move to reference/knowledge files, and what must stay
a separate task/fact source. Flag every control that would cross from enforced instruction to
retrieved grounding. Return a target-lane analysis, retained vs. moved controls, source-role map,
grounding/truncation/permission risks, no-loss table, and readiness label. Do not imply deployment
readiness.
```

## Merge two kernels

```text
Merge these two kernels into one. Inventory both by function first. Surface any conflicting hard
stops, source-role rules, or routing behavior rather than silently choosing one. Return a combined
candidate, a conflict list with proposed resolutions, a relocation map, a no-loss table covering
both originals, and a readiness label. Do not overwrite either source.
```

## Split one kernel into several

```text
Split this kernel into [N] skills/kernels along [boundary]. Keep each shard's always-on controls
intact — do not assume a sibling shard carries a hard stop, gate, or source-role rule. Return the
per-shard candidates, a map of which functions went where, a check that no shard lost an always-on
control, a no-loss table against the original, and a readiness label.
```

## Bloat / drift audit (fits but too long to obey)

```text
This kernel fits its surface but may be too long to be reliably followed. Audit it for
attention-budget loss and drift: identify controls buried deep, duplicated, or contradicted, and
any guardrail that is present but unlikely to be obeyed in practice. Treat degraded obedience as a
real loss even though nothing overflows. Return findings by severity, a tightening plan that moves
detail to references without dropping function, a no-loss table, and a readiness label.
```

## Function matrix first

```text
Inventory the functions in this kernel before compressing it. Do not inventory by paragraph only.
For each function, identify the original source, protected-function status, decision type,
destination, no-loss status, and any HOLD.
```

## Platform-limited compression

```text
Compress this development-only kernel for a smaller instruction field.
Target platform:
Maximum practical length:
Companion/source files available:
Prompt bank available:
Validation/audit files available:

Keep universal always-on controls in the kernel. Move long operational detail to the proper
companion, prompt-bank, audit, deployment, validation, or archive layer. Return a relocation map
and no-loss table.
```

## Protected-baseline review

```text
Review this proposed compressed kernel against the protected baseline. Do not overwrite or
promote. Identify any function that was removed, weakened, moved to the wrong layer, or converted
from always-on to optional. Return PASS, PASS-WITH-NOTES, SOFT HOLD, HARD HOLD, or FAIL.
```

## Logical-file compression

```text
This source is a logical .json.txt or wrapped logical file. Parse from the first BEGIN_JSON to the
last END_JSON. Extract manifest, source-role lock, retrieval index, fixed mapping index,
summary/truncation controls, source-scope controls, anti-recursion controls, human gates, and
validation/promotion controls before compression. Do not compress from title summaries. Logical
parse success does not authorize replacement.
```

## Prompt-bank preservation audit

```text
Audit whether the compressed kernel and relocation map preserve prompt-bank behavior. Identify
any lost user-facing kickoff, route, repair, validation, checkpoint, or restart prompt. If a
prompt route was moved, identify its destination and no-loss status.
```

## No-loss preservation audit

```text
Compare the original kernel and candidate function-by-function. Identify preserved, compressed,
moved, archived, omitted, and HOLD items. Treat a function as lost if the user would no longer
receive the same guardrail, route, audit, downgrade, stop, or human-review behavior.
```

## Overcompression refusal / HOLD

```text
The user asks to remove or weaken guardrails to save space. Apply hard stops. Refuse or assign
HOLD unless an approved substitute always-on control preserves the same function. Return a
repair-safe alternative.
```

## Runtime / archive split review

```text
Review this source stack for runtime/archive separation. Identify runtime files, validation
files, setup-only files, maintainer/archive files, duplicates, stale files, and files that should
not be loaded into ordinary runtime knowledge.
```

## Candidate promotion check

```text
Review whether this candidate can be promoted. Do not promote it. Identify required human
approvals, validation results, no-loss status, protected-baseline comparison, source-role risks,
and remaining holds.
```

## Continue from checkpoint

```text
Resume kernel compression from the checkpoint below. Preserve function, source-role rules,
prompt-bank behavior, audit controls, logical-file parse discipline, runtime/archive separation,
candidate-only treatment, and human-review gates. Treat all generated drafts as candidate-only.

Checkpoint:
[paste checkpoint]
```

## Repair prompt

```text
Repair the compressed kernel candidate where any function was lost, weakened, moved to the wrong
layer, or left without an equivalent control. Do not overwrite the source kernel. Return only the
repaired candidate sections, updated relocation map, updated no-loss rows, and revised readiness
label.
```

## Result capture

```text
Capture this test result. Include source basis, tested kernel, function-matrix completeness,
relocation-map completeness, no-loss status, hard stops, holds, defects, readiness label, and the
exact next prompt.
```
