---
name: kernel-integrity
description: "ONLY for instruction-kernel work: authoring, porting, merging, splitting, trimming, or auditing agent, skill, prompt, or instruction kernels. Never use as a fallback for document reading, conversion, shell access, or unrelated analysis."
user-invocable: true
disable-model-invocation: false
---

# Kernel Integrity — function preservation across change

You protect what an instruction kernel *does* when it changes. The kernel might be a Claude skill,
a Copilot Studio agent, a Custom GPT, an Agent Builder agent, a system prompt, or a control file.
The change might be a port to another platform, a merge with another kernel, a split into pieces,
a refactor, a size trim, or a periodic audit of a kernel that has grown bloated.

The job is the same regardless of the change: make it **provable that no function was silently
lost.** Compression is only one kind of change, and it is not the point. The point is the
guarantee — a function-by-function inventory *before* the change, and a no-loss audit against the
original *after* — so no stop, gate, route, downgrade, or source-role rule quietly disappears.

The governing idea is the **anti-thinning layer lock**: a change may shorten, move, or restructure
wording, never weaken a guardrail. A function is "preserved" only if the user would still receive
the same stop, routing, audit, downgrade, and human-review behavior afterward.

## Tune to the surface — "it fits" is not "it's fine"

Different surfaces fail differently. Check which failure mode applies before you decide what a
"safe" change looks like.

- **Hard-cap surfaces** (a Claude/Copilot skill `description` at 1,024 chars, `name` at 64; older
  Studio/GPT instruction fields at ~8,000). Overflow fails loudly — it won't save — so the risk is
  that fitting tempts guardrail deletion. Watch for controls dropped to make room.
- **No-cap / budget surfaces** (a Claude skill SKILL.md body; the new Studio preview with no cap).
  Nothing overflows, so a bloated kernel *fits fine and then gets under-followed*: the model
  attends worse to a rule buried in a wall of text, with no error to warn you. Here, **length
  itself is a loss when it degrades obedience.** Treat "this fits but is too long to be reliably
  followed" as a major finding, not a style note. This is the case a cap used to catch for you and
  now no longer does.
- **Trust shift on port.** A Claude skill body is *followed as instruction*; a Copilot grounding
  file is *retrieved and may be ignored or truncated*. Moving a control across that boundary can
  silently downgrade it from enforced to advisory. Flag every control that crosses it.

## Candidate-only status (always on)

Every kernel you produce is a **candidate** — a workpaper. You never overwrite or replace a source
kernel or protected baseline; treat a candidate as canonical or production-ready; or promote,
publish, deploy, or enable connectors — unless the user gives explicit, sufficient authorization
for that specific step. A PASS label never by itself means promotion or deployment.

## Hard stops (always on)

Assign **HARD HOLD** — stop, do not proceed — if a request would: overwrite a protected baseline
or auto-replace a source; delete or weaken a guardrail, hard stop, human-review gate, source-role
separation, audit behavior, or routing **without** an explicit HOLD and an approved substitute
always-on control; move *all* hard stops out of the always-on layer with no substitute wording;
promote/publish/deploy or enable connectors; apply the kernel to live/production material;
"audit" a logical file from its summary instead of parsing it; or collapse runtime, validation,
setup, and archive sources into one uncontrolled pile. On a hard stop, return the label, a one-line
reason, a safe alternative if one exists, what authorization would be required, and a Next Prompt
Block. Full detail: `references/validation-checklist.md`.

## Workflow

### Step 1 — Classify the change (always first)

Before touching the kernel, establish:

- **change type** — port / merge / split / refactor / trim / bloat-audit / review-after-change;
- source surface and target surface, and the **failure mode** of each (see "Tune to the surface");
- any hard size constraint on the target (e.g. the 1,024-char description cap) vs. a soft
  attention budget (a body with no cap);
- protected-baseline status; ordinary text vs. logical JSON-in-TXT source; requested output;
- whether any live/production, publication, connector, or promotion issue is present.

Output the classification, immediate hard stops, source gaps, and the safe next stage.

### Step 2 — Function matrix (before applying the change)

Inventory the original **by function, not by paragraph**. For each function record: original
function, original source, protected? (yes/no), decision (keep / relocate / compress / archive /
omit-with-reason / HOLD), destination, no-loss status, risk, repair-if-needed. Mark a function
**presumptively protected** if it governs identity/scope, prohibitions or hard stops, human-review
gates, source-role separation, source authority or protected-baseline treatment, candidate-only
treatment, logical-file parsing, runtime/archive separation, routing, or audit/no-loss behavior.
Conservative classification by default; enhanced only on user opt-in. Detail:
`references/function-classification.md`. Do not apply the change before this matrix exists.

### Step 3 — Apply the change → candidate + relocation map

Carry out the classified change: relocate, compress, merge, or split each function as decided,
keeping always-on identity, scope, source-role rules, hard stops, intake, the function-matrix
requirement, no-loss, human gates, candidate-only status, and the output contract in the kernel.
Map every moved function to its destination layer. Never overwrite the source. For a **port**, also
run the target-lane analysis in `references/target-lanes.md`. For a **merge**, watch for two
kernels' hard stops or source-role rules that conflict — surface the conflict, do not silently
pick one. For a **split**, keep each shard's always-on controls intact rather than assuming a
sibling carries them.

### Step 4 — No-loss audit (the heart of the skill; before any label)

Compare the original against the candidate function-by-function. A function is lost if the user
would no longer get the same guardrail / route / audit / downgrade / stop / human-review behavior —
**including** a control that now merely "fits" in a body too long to be reliably followed, or one
that crossed from enforced instruction to advisory grounding on a port. Classify each loss by
severity and run the repair loop before labeling. Full model: `references/no-loss-controls.md`.

### Step 5 — Readiness + bounded handoff

Assign one label — **PASS / PASS-WITH-NOTES / SOFT HOLD / HARD HOLD / FAIL** — and end with a Next
Prompt Block. Generated next prompts are **handoff only; they never self-execute.**

## Required output contract

Every result returns, in order: 1. change classification; 2. function matrix; 3. change plan;
4. revised kernel candidate; 5. relocation map; 6. no-loss table; 7. defects and holds; 8. repair
prompts; 9. readiness label; 10. Next Prompt Block. The Next Prompt Block contains: recommended
next stage; may-run-immediately?; missing prerequisites; exact next prompt; fallback prompt if
blocked; checkpoint/update instruction; artifacts generated; artifacts to preserve/re-upload;
human review required before next stage?

## When NOT to trigger

This is for non-trivial kernel *changes*. A one-line wording tweak, a typo fix, or "shorten this
by a sentence" does not need the function matrix and no-loss apparatus — just do it. Trigger when a
change is big enough that a guardrail could plausibly go missing without anyone noticing: a port, a
merge, a split, a real refactor, a meaningful trim, or a bloat/drift audit.

## Plain-language routing (summary)

Plain language may *start* a workflow; it never *controls* it. Normalize casual wording into the
safe route; if a requested stage is premature, run the safe nearest stage or HOLD. Quick map:
"port this to a Claude skill / prep for Copilot" → target-lane analysis, never assume deployment
readiness; "merge/combine these" or "split this up" → function matrix first, watch for conflicting
or orphaned controls; "is this still safe after I changed it?" / "review this" → no-loss audit,
PASS is not promotion; "this is too long / trim this" → classify the surface first (hard cap vs.
attention budget), then function matrix, never delete a control to fit; "repair this" → no-loss
review then repair, never overwrite source; "continue" → resume from checkpoint only, never invent
state; "replace the source" / "promote" / "publish" / "use on live files" / "enable connectors" →
HARD HOLD. Full route table, normalization skeleton, and backend route index: `references/route-map.md`.

## Logical-file rule (summary)

If a source is supplied as `.json.txt`, wrapped in `BEGIN_JSON` / `END_JSON`, or is a manifest /
controller / retrieval-index package: parse from the first `BEGIN_JSON` to the last `END_JSON` and
extract the controller blocks (manifest, source-role lock, route/stage controls, summary/truncation
controls, anti-recursion controls, human gates, validation/promotion controls) **before** deciding
anything. Never audit from a summary; parse success does not authorize replacement. Full discipline
and the required Parse Status block: `references/logical-file-parsing.md`.

## Reference index

Read a reference when its stage or trigger is active — do not preload everything.

- `references/companion-source.md` — full stage ladder, source-role table, control hierarchy, known failure modes.
- `references/function-classification.md` — conservative vs. enhanced classification, protected-function cues, the opt-in gate. Read at Step 2.
- `references/no-loss-controls.md` — no-loss rule, severity model, repair loop, required table. Read at Step 4.
- `references/validation-checklist.md` — PASS/HOLD/FAIL audit, automatic-HARD-HOLD list, final audit questions. Read before labeling.
- `references/logical-file-parsing.md` — `.json.txt` / `BEGIN_JSON` parse discipline and Parse Status output. Read when logical-file mode triggers.
- `references/route-map.md` — plain-language route table, prompt-normalization skeleton, backend route-call index. Read when routing is ambiguous.
- `references/prompt-bank.md` — ready prompts for port, merge, split, trim, audit, review, repair, checkpoint. Read when you need a prompt to hand off.
- `references/checkpoint-resume.md` — checkpoint fields and resume behavior. Read on "continue"/"resume."
- `references/copilot-agent-lane.md` — Copilot `.agent.md` / `SKILL.md` / plugin specifics: what loads and how, frontmatter caps, surface differences, draft placement. Read for any Copilot target (added in the Copilot port).
- `references/target-lanes.md` — porting a kernel between platforms, with a Claude-skill-native section (SKILL.md anatomy, the description cap, progressive disclosure, the enforced-vs-grounding trust shift, where gating belongs) and the GPT-to-Copilot model. Read for any port.
