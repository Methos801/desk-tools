---
name: corpus-inventory
description: "ONLY for an explicit corpus inventory/manifest task or when desk-inventory-manifest requires it. Build or continue a loss-resistant hierarchical census using the bundled deterministic census and reconciliation scripts. Never use as a fallback for reading a document or obtaining a missing tool."
argument-hint: Source root, output workspace, inspection level (QUICK / STANDARD / DEEP), exclusions
user-invocable: true
disable-model-invocation: false
---

# Corpus Inventory

Use this skill when inventorying a large or deeply nested source tree. The scripts do the counting; you do the reading and judgment.

## Non-negotiable rules

- The census script decides what exists. Never decide by browsing or by memory.
- Every discovered directory and artifact keeps its own record and its original relative path.
- Similarity and exact duplication create relationships; they never erase records.
- The source corpus is read-only. Write only inside the inventory workspace.
- Durable files are the memory. Assume the conversation may disappear after any batch.
- Never use scripts, embeddings, clustering, sampling, or deduplication to skip an artifact's individual record.
- Never mark a directory `COMPLETE` until its direct artifacts and child directories are terminal.
- Never declare the run complete until `reconcile` reports `RECONCILED`.

## Scripts

The scripts are in the `scripts/` folder next to this SKILL.md. Use the folder you read this file from to build the full path. Both languages produce the same files, so use whichever runtime exists:

| Task | Python 3.8+ (macOS/Linux: `python3`, Windows: `py -3`) | PowerShell (Windows PowerShell 5.1 or `pwsh` 7+) |
|---|---|---|
| Census | `python3 <skill>/scripts/census.py <root> --out <workspace> [--exclude .git] [--exclude node_modules]` | `<skill>/scripts/census.ps1 -Root <root> -Out <workspace> [-Exclude .git,node_modules]` |
| Check one batch | `python3 <skill>/scripts/reconcile.py --out <workspace> --batch B00012` | `<skill>/scripts/reconcile.ps1 -Out <workspace> -Batch B00012` |
| Final audit | `python3 <skill>/scripts/reconcile.py --out <workspace> --write` | `<skill>/scripts/reconcile.ps1 -Out <workspace> -Write` |

On Windows, if PowerShell refuses to run the script, prefix the call with `powershell -NoProfile -ExecutionPolicy Bypass -File`.

Useful census options: `--metadata-only <glob>` (enumerate but don't read, e.g. `*.pdf` when the model can't read PDFs), `--no-hash`, `--max-hash-mb N`, `--batch-tokens N` (12000 for 32K sessions, 24000 for 64K). Globs support `*` and `?` and match the relative path or the name. The census refuses to overwrite an existing census unless you pass `--force`; only do that to start a new run.

A mapped network drive (for example `N:`) works as the root. The census reads the share once; take paths from `CORPUS_CENSUS.csv` rather than re-listing the share.

On Windows, OneDrive/SharePoint "files on demand" placeholders are enumerated but not opened, hashed, or downloaded (census note `cloud placeholder`). Reading one during review downloads it, so tell the user before reviewing a large cloud-only folder.

Exit codes for `reconcile`: `0` done, `1` incomplete, `2` record errors — fix errors before anything else.

## Sequence

1. Resolve root, workspace (default `.inventory-manifest`, relative to the current directory; when that falls under the root, or the user said not to write in the source folder, pass an explicit `--out` outside the root), inspection level, exclusions (recommend excluding `.git`), and an optional interpretive profile: `AUTO`, `CODEBASE`, `DOCUMENT_CORPUS`, `CONFIGURATION`, or `MIXED`. A profile changes interpretation hints only — never whether an item is enumerated or whether similar items may be collapsed.
2. Run the census once. Read its summary line and `PROCESS_STATE.json`. The census is now frozen.
3. For each batch in `QUEUE.jsonl`, in order:
   1. read the batch's census rows and the artifacts themselves (only that batch);
   2. append one record per artifact to `ARTIFACT_RECORDS.jsonl`;
   3. append any relationships to `RELATIONSHIPS.jsonl`;
   4. run `reconcile --batch <id>`; fix anything it reports;
   5. update `PROCESS_STATE.json` (`last_completed_batch`, `next_action`).
4. When every batch in a directory is done and its child directories are terminal, append a directory status line (`COMPLETE`) with a short summary built only from its records.
5. Write `MANIFEST.md` (hierarchy-preserving) from the records, then optional `GLOSSARY.md` / `CORPUS_OVERVIEW.md`. A thematic index may supplement the hierarchy but never replaces it unless the user asks.
6. Run the final audit with `--write` and finish `RUN_REPORT.md` from its numbers.

Record formats, statuses, and the append rule are in `references/record-formats.md`. Read it before writing the first record.

## Small-context discipline

Treat 32K as a normal context size. Hold only the current batch plus its local structure (directory, parent, children). For oversized artifacts (`"oversized": true` in the queue), read logical sections one at a time, record `PARTIAL` with segment progress, and mark `REVIEWED` only after every segment is covered.

Do not reread completed batches unless a specific reconciliation issue requires it. State uncertainty rather than inventing missing facts.

Report uncertainty, failures, inaccessible items, and exclusions explicitly. Never hide them in summary prose.
