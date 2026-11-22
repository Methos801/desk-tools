---
name: compare-materials
description: Compare documents, configurations, code, or other materials for meaningful semantic differences, impacts, omissions, and conflicts.
argument-hint: Source A, source B, and what the comparison is for
user-invocable: true
disable-model-invocation: false
---

# Compare Materials

Compare the user-specified materials without silently broadening the scope.

## Method

- Establish the comparison dimensions that matter to the user's question.
- Read both sides sufficiently to avoid one-sided comparison.
- Focus on substantive semantic changes; ignore trivial formatting differences unless they matter.
- Identify additions, removals, changed obligations or behavior, contradictions, and dropped requirements.
- Ground each material difference in both sources where possible.
- Distinguish confirmed differences from interpretation or uncertainty.
- Explain practical impact when the evidence supports it.
- Do not edit either source unless the user separately requests modification.

## Output

Lead with the most important difference, then present the significant differences in a scannable structure with impact and source references:

```
Key difference: <the single most important difference, with a reference into each source>

| Aspect | Source A | Source B | Impact |
|---|---|---|---|
| <aspect> | <detail — location> | <detail — location> | High / Medium / Low |

Omissions or conflicts: <requirements dropped, contradictions, or "none found">
Uncertain: <differences that depend on interpretation>
Sources: <path or URL for each side>
```
