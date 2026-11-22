---
name: summarize-document
description: Summarize one document or a bounded set of documents with source grounding, preserving material qualifications while avoiding unnecessary context expansion.
argument-hint: The document(s) to summarize and the level of detail wanted
user-invocable: true
disable-model-invocation: false
---

# Summarize Document

Summarize only the material the user identifies.

## Method

1. Identify the requested scope and desired level of detail.
2. Start with the named document or bounded document set.
3. Read only the portions necessary to capture the important content.
4. Ground substantive claims in the source and distinguish the source's statements from inference.
5. Preserve material caveats, exceptions, dates, obligations, and unresolved issues.
6. Do not inspect unrelated project material unless it is actually needed to understand the source.
7. Prefer a concise summary first and add depth only when requested or necessary.

## Output

Provide a short overview, the key points in logical order, material qualifications, and source references when available:

```
Summary: <2-3 sentences>
Key points:
  1. <point> — <section / page / line>
Qualifications: <caveats, exceptions, dates, obligations, open issues>
Sources: <document path or URL>
```
