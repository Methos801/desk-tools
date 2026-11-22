# Routing — plain-language map, normalization, backend route index

**Core rule:** plain language may *start* the workflow; it does not *control* the workflow.
Map the request to the safest approved route. If the requested stage is premature, run the safe
nearest stage or HOLD. This routing layer never overrides hard stops, no-loss review, source-role
separation, human-review gates, or candidate-only treatment.

## Plain-language route table

The center of gravity is a kernel *change* proven not to lose function. Compression is one row
among many, not the headline.

| User request | Intended route | Safe nearest stage if blocked | Stop condition |
|---|---|---|---|
| "Port this to a Claude skill" / "prep for Copilot" | classify change (port) → function matrix → target-lane analysis → candidate → no-loss | intake classification | Do not assume deployment readiness; flag controls crossing enforced→grounding. |
| "Merge/combine these kernels" | classify change (merge) → function matrix of both → conflict scan → candidate → no-loss | intake classification | Surface conflicting hard stops / source-role rules; never silently pick one. |
| "Split this up" / "break into skills" | classify change (split) → function matrix → per-shard always-on check → no-loss | intake classification | Each shard keeps its own always-on controls; do not assume a sibling carries them. |
| "Is this still safe after I changed it?" / "audit for drift" | no-loss audit of changed vs. original | intake classification | Length that degrades obedience is a loss, not a style note. |
| "This is too long / trim this" | classify surface (hard cap vs. attention budget) → function matrix → trim plan → no-loss | intake classification | Never delete a control to fit; "it fits" is not "it's fine." |
| "Compress this" / "make it fit" | function matrix → decision table → candidate → no-loss | intake classification | Brevity is not authority to remove controls; draft after the matrix. |
| "Review this package" | intake → source review → inventory | intake classification | Do not imply promotion or replacement. |
| "What do we have?" / "Where are we?" | status / readiness / checkpoint review | same | Do not invent missing state. |
| "What's missing?" | gap / readiness review | intake classification | Do not proceed to a later stage silently. |
| "Inventory this" | function or source inventory | intake classification | Do not inventory by paragraph only when function inventory is required. |
| "Classify these functions" | inventory with conservative classification | intake classification | Enhanced classification only if the user opts in. |
| "Repair this" | no-loss review → repair loop | no-loss review | Do not overwrite the source kernel. |
| "Validate this" | validation / audit / no-loss review | intake classification | PASS does not equal promotion. |
| "Compare these" | comparison / delta / source-role comparison | intake classification | Do not treat a candidate as canonical. |
| "Continue" | resume from checkpoint / last safe stage | checkpoint reconstruction | Do not invent prior state. |
| "What's next?" | handoff / readiness / next prompt | checkpoint review | End with a bounded handoff only. |
| "Prepare this for Copilot" / "port to a Claude skill" | target-lane translation analysis | intake classification | Do not imply deployment readiness. |
| "Turn this into a logical file" | logical-file packaging analysis | intake classification | Do not treat the logical file as canonical by default. |
| "Replace the source" | HARD HOLD | HARD HOLD | Candidate-only output. |
| "Promote this" | promotion review only | HARD HOLD | Do not promote. |
| "Use this on live/production files" | HARD HOLD | HARD HOLD | Development-only limitation. |
| "Enable connectors" | HARD HOLD | HARD HOLD | Out of scope. |
| "Publish this" | HARD HOLD | HARD HOLD | Requires human review. |

**Safe-nearest-stage rule:** if the user asks for a later stage before prerequisites are met —
identify the intended route, identify the missing prerequisites, route to the safe nearest stage,
produce that stage's safe output, and end with a bounded Next Prompt Block.

## Prompt-normalization skeleton (internal)

Before substantial work, normalize the request internally. Do not expose this scaffolding unless
asked.

```text
User request:
Workflow family:
Target platform / deployment lane:
Intended stage:
Safe nearest stage:
Available source layers:
Missing prerequisites:
Source-role implications:
Logical-file mode triggered?:
Protected-baseline issue present?:
Candidate-only limitation:
Controlled route:
Required source-integrity controls:
Required anti-thinning / no-loss controls:
Required output artifacts:
Required HOLD / FAIL checks:
Required Next Prompt Block:
```

Workflow families: intake/readiness; function inventory; compression planning; candidate
drafting; no-loss review; repair loop; validation/audit; checkpoint/resume; target-lane
translation analysis; logical-file packaging analysis; promotion review only.

Normalize to HOLD or FAIL rather than proceed when the request implies source replacement,
protected-baseline overwrite, publication, connector enablement, live/production use, candidate
promotion, guardrail removal, source-role collapse, summary-only logical-file execution, or
runtime/archive collapse.

## Backend route-call index

A deterministic route map for when you want an explicit call table. Each call downgrades to its
fallback when prerequisites are missing.

| Call | Trigger phrases | Safe nearest stage | Required controls | Fallback | Human gate |
|---|---|---|---|---|---|
| intake_classification | "what do we have", "where are we", "review this", "start", "inventory this" | intake_classification | source-role separation; hard stops; candidate-only | next_prompt_handoff | no |
| function_inventory | "port this", "merge these", "split this", "trim this", "audit for drift", "compress this", "classify these functions" | function_inventory | function-matrix-first; conservative-by-default; enhanced opt-in | intake_classification | no |
| change_plan | "port this", "merge these", "split this", "make it fit", "restructure this kernel" | change_plan | anti-thinning lock; protected-function preservation; source-role preservation; conflict/orphan scan on merge/split | function_inventory | no |
| candidate_draft | "draft the candidate", "produce the revised kernel" | candidate_draft | candidate-only; protected-baseline; no source overwrite | change_plan | no |
| no_loss_review | "validate this", "review the candidate", "compare to baseline" | no_loss_review | functional no-loss rule; severity model; repair loop | intake_classification | no |
| repair_loop | "repair this", "fix the candidate", "restore lost function" | repair_loop | restore protected behavior; no source overwrite | no_loss_review | no |
| logical_file_mode | ".json.txt", "BEGIN_JSON", "logical file", "manifest", "retrieval index" | controller_extraction | parse first→last JSON; controller extraction before execution; summary-insufficiency; anti-recursion | next_prompt_handoff | no |
| translation_analysis | "prepare this for copilot", "port to a claude skill", "turn this into a logical file" | translation_analysis | builder/runtime split; source-role preservation; grounding limits; summary-insufficiency | intake_classification | **yes** |
| promotion_review_only | "promote this", "replace the source", "publish this" | hard_hold | candidate-only; protected-baseline; human gates | next_prompt_handoff | **yes** |
| next_prompt_handoff | "what's next", "continue", "resume", "next step" | checkpoint_review | handoff only; no self-execution; do not invent state | intake_classification | no |

**Call-resolution rules:** prefer the safest matching call; if prerequisites are missing,
downgrade to the safe nearest stage or HOLD. If multiple calls match, prefer the earlier, safer
stage. Any hard-stop / promotion / live-material / connector / publication issue overrides route
calling and forces HOLD.

## Anti-recursion controls

Route calls do not self-execute. Generated prompts do not amend the skill. Failed outputs are not
source authority for reruns. Maintenance happens only through a new versioned artifact. Generate
the Next Prompt Block and stop unless the user expressly authorizes the next safe stage.
