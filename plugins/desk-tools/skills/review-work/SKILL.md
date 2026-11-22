---
name: review-work
description: Review existing work against requirements and evidence, identifying defects, regressions, omissions, unsupported claims, and verification gaps without automatically editing it.
argument-hint: What to review and what it was supposed to achieve
user-invocable: true
disable-model-invocation: false
---

# Review Work

Review the existing artifact or change before proposing rewrites.

## Method

1. Identify the requested acceptance criteria, requirements, or intended outcome.
2. Inspect the relevant artifact, diff, files, or deliverable.
3. Find defects, contradictions, dropped requirements, regressions, unsupported assumptions, and missing verification.
4. Separate confirmed blockers from risks, suggestions, and optional improvements.
5. Prioritize findings by impact and likelihood.
6. Cite the evidence supporting each material finding.
7. Do not silently rewrite the work. Offer fixes only after making the review result clear.

When enough evidence exists, state whether the work is ready, conditionally ready, or not ready:

```
Verdict: READY | CONDITIONALLY READY | NOT READY
Findings (highest impact first):
  1. [blocker | risk | suggestion] <finding> — evidence: <location or output>
Verification gaps: <what was not or could not be checked>
```
