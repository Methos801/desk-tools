# Target Lanes — porting a kernel between platforms

Translation is **function preservation across deployment lanes, not surface imitation.** Do not
ask what a target version should "look like" in the abstract. Determine what controls must stay
always-on, what can move into structured files, and what must stay separate as task/fact sources.

Common lanes: Claude skill; Copilot Studio agent; Custom GPT; Agent Builder with attached files;
SharePoint-grounded Copilot; direct logical-file upload; a future API/agentic workflow.

## Core translation questions

Before proposing a translated package, determine: 1. what controls workflow logic today; 2. what
controls task/fact material today; 3. what must remain always-on; 4. what is too large or brittle
for the target instruction surface; 5. what can safely move to structured/reference files; 6. what
target-lane limits affect retrieval or trust; 7. what new failure modes the target lane
introduces; 8. what human-review gates remain mandatory.

## Builder / runtime split (all lanes)

Separate, and do not collapse merely to fit a smaller surface: short always-on instruction
kernel; structured logical/control file; companion operational detail; prompt / run card; task /
fact source files; deployment/setup guidance; archive/source-basis materials.

## Source-role preservation (all lanes)

Distinguish at minimum: workflow/routing authority; task/fact source; legal/currentness source
where applicable; example/pattern source. Do not let a workflow file become fact authority, or a
fact file become workflow authority.

---

## Lane: Claude skill (native target)

A Claude skill loads in three tiers, which maps almost exactly onto this skill's own layers:

- **Tier 1 — metadata (always in context):** the `name` and `description` frontmatter. This is
  the *only* thing Claude sees before deciding to open the skill, so it is the whole triggering
  mechanism. It corresponds to the kernel's identity/scope plus its trigger conditions.
- **Tier 2 — SKILL.md body (loads on trigger):** the always-on kernel — identity, hard stops,
  stage ladder, output contract, routing summary. Keep it focused; roughly 500 lines is a
  comfortable ceiling.
- **Tier 3 — bundled resources (load on demand):** `references/` for docs read as needed,
  `scripts/` for deterministic code, `assets/` for output templates. This is where companion,
  prompt-bank, validation, logical-file, and archive material belongs.

**Anatomy:**

```
skill-name/
├── SKILL.md            (frontmatter + always-on body)
├── references/         (docs loaded as needed)
├── scripts/            (deterministic code, runs without loading into context)
└── assets/             (templates, icons used in output)
```

**Frontmatter constraints (validated on upload):**

- `name` — kebab-case, max 64 chars.
- `description` — max **1,024 characters**, no angle brackets. This is the same hard cap you know
  from the Copilot skill surface, so the "put trigger conditions in the description, keep it tight"
  discipline transfers unchanged.
- Only these keys are allowed: `name`, `description`, `license`, `allowed-tools`, `metadata`,
  `compatibility`. Any other top-level key fails validation.
- Exactly one SKILL.md per skill, at the folder root. Nested SKILL.md files are rejected on upload
  (only Claude Code's filesystem loads nested ones). To ship several skills, package each
  separately or build a plugin.

**Translation moves, GPT/Copilot kernel → Claude skill:**

- The GPT `AGENTS.md` / Custom-GPT instruction field → the SKILL.md body. Compress it to the
  always-on kernel; push operational detail to `references/`.
- Copilot/GPT "knowledge files" and logical `.json.txt` route files → `references/`. Note the
  trust shift below.
- The triggering description is usually **new work**: GPT agents are invoked by name/@-mention,
  so they often carry no trigger text. A Claude skill lives or dies on its description. Write it
  pushy and specific — name the phrasings and contexts that should fire it, since Claude tends to
  under-trigger skills for tasks it thinks it can already handle.
- Deployment/upload-stack mechanics (which files to upload where, retrieval-stability redundancy)
  are **obsolete** in the Claude lane and should be dropped, not ported. Progressive disclosure
  replaces the deliberate redundancy that the GPT/Copilot upload stack needed.

**Trust model:** a Claude skill's SKILL.md body and references are read as instructions Claude
follows, which is *stronger* trust than a Copilot grounding file. That makes an always-on kernel
easier to preserve here than in a SharePoint-grounded Copilot lane — but it raises the stakes on
the anti-thinning discipline, because a control silently dropped from SKILL.md is simply gone.

**Where gating belongs:** audience/condition gating ("only for role X", "only when condition Y")
belongs in the **orchestrating skill**, not smeared across each downstream skill's trigger
description. Keep each skill's description about *what it does and when it fires*; let a router
skill decide *whether the user is allowed to be here*.

---

## Lane: Copilot Studio / SharePoint-grounded (translation model)

When the target is Copilot or SharePoint-grounded, treat retrieval as untrusted and limited:

- selected-source scope must be explicit or treated as limited;
- permission limitations must be surfaced when material;
- truncation / under-reading are real limitations, not edge cases;
- broad library grounding must not be assumed;
- a missing-source note is safer than unsupported synthesis.

## Summary-insufficiency rule (logical files, all lanes)

A summary of a logical file is navigation only, never execution authority. If a logical file is
used, extract controller blocks before substantive execution — at minimum the package manifest,
source-role model, route/stage controls, truncation/selected-source protocol, and anti-recursion
controls. If those cannot be retrieved reliably, HOLD.

## Anti-flattening rule

Do not translate a multi-layer workflow into generic prose that loses manifest/controller
structure, the source-role model, the route map, the stage ladder, selected-source/truncation
controls, anti-recursion rules, audit/preview checks, or deployment limitations. If a translation
removes a required layer, mark it not promotable and restore the layer.

## Translation output requirements

Return: 1. intake classification; 2. current lane and target lane; 3. retained always-on controls;
4. moved controls and destinations; 5. instruction-kernel recommendation for the target;
6. logical-file recommendation if applicable; 7. source-role preservation map; 8. target-lane
grounding/truncation/permission risks; 9. defects/holds; 10. readiness label; 11. bounded Next
Prompt Block.

## When a logical file is worth it

More likely prudent when: the target instruction surface is small; routing/controller logic is
too large for live instructions; Copilot selected-source behavior needs explicit mapping;
summary/truncation failures are likely; a reusable package is needed across lanes. Less likely
prudent when: a short kernel plus a few companion files suffices; the workflow is narrow and
stable; extra packaging would add more complexity than control value.

## Known translation failure modes

1. Live instructions become too thin and lose always-on controls. 2. Knowledge files are treated
as trusted instructions when the platform does not behave that way. 3. Selected-source limits
hidden. 4. Truncation ignored. 5. Summary text becomes execution authority. 6. Workflow and fact
sources collapse together. 7. Prompt routing widens scope beyond the original workflow. 8. A
translated package is mistaken for deployment approval.
