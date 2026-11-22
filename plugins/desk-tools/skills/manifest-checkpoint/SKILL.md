---
name: manifest-checkpoint
description: "ONLY during an active inventory/manifest run or an explicit manifest checkpoint request. Validate and record resumable corpus state using the corpus-inventory reconcile script. Never use as a fallback for document reading, conversion, shell access, or unrelated analysis."
argument-hint: Inventory workspace path (default .inventory-manifest)
user-invocable: true
disable-model-invocation: false
---

# Manifest Checkpoint

Create or refresh a compact, durable continuation state for an inventory/manifest run. Do not write a conversation transcript.

## Validate first

1. Run the reconcile script from the `corpus-inventory` skill for the active batch: `reconcile.py --out <workspace> --batch <id>` (PowerShell: `reconcile.ps1 -Out <workspace> -Batch <id>`).
2. If it exits `2`, fix the record errors it lists (bad JSON lines, unknown IDs, path mismatches) by appending corrected lines. Never edit or delete earlier lines.
3. If it exits `1`, keep the batch open: the pending IDs still need records.
4. Run the full reconcile (no `--batch`). Any `premature_complete_ids` must go back to `PARTIAL` by appending a new ledger line.
5. Do not repair source files or invent missing records.

## Record the checkpoint in `PROCESS_STATE.json`

- `last_completed_batch` — only a batch that reconciled as `BATCH_COMPLETE`;
- `next_action` — the exact next step, for example `Process batch B00043 (docs/specs)`;
- `profile` and `inspection_level` for the run;
- `active_batch` and `active_directory`, and any `oversized_in_progress` IDs with segment progress;
- `exceptions` — the IDs currently `FAILED`, `INACCESSIBLE`, or `NEEDS_REVIEW`, each with its reason;
- `open_relationship_questions` — version families or relationships still to reconcile;
- leave the census-written `counts` and `config` untouched.

## Continuation rule

A fresh session resumes by reading `PROCESS_STATE.json`, the next batch in `QUEUE.jsonl`, and the matching census rows — not the full manifest or conversation. If the state is inconsistent, reconcile the smallest affected scope before moving forward.

## Output

```
Workspace: <path>
Last completed batch: <id>
Reconcile: <result> — unaccounted artifacts <n>, directories <n>, errors <n>
Next action: <exact next step>
```
