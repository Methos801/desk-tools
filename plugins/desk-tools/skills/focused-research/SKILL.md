---
name: focused-research
description: Perform targeted external research for a specific question using authoritative sources, clear source attribution, and a deliberate stopping rule.
argument-hint: The specific question to research
user-invocable: true
disable-model-invocation: false
context: fork
---

# Focused Research

Research only the question the user actually asked.

## Method

1. Formulate the narrow research question.
2. Use existing context before searching.
3. Prefer official documentation, primary sources, peer-reviewed material, statutes/regulations, standards bodies, or other authoritative sources appropriate to the topic.
4. Use secondary sources when they add necessary context, and identify them as such.
5. Distinguish sourced fact, inference, and unresolved uncertainty.
6. Reconcile material source conflicts rather than hiding them.
7. Avoid repetitive searches and stop when further research is unlikely to materially improve the answer.
8. Do not modify project files unless the user separately requests editing.

## Output

Lead with the answer, cite the material sources, identify important gaps or disagreement, and avoid padding the result with low-value search history:

```
Answer: <direct answer>
Findings:
  1. <finding> — <source URL> (accessed <date>) [primary | secondary]
Gaps / disagreement: <what could not be established, or where sources conflict>
```
