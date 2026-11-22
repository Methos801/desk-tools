# Inventory record formats

All files live in the inventory workspace. The census writes the first five; you append to the `.jsonl` files and update `PROCESS_STATE.json`.

| File | Written by | Rule |
|---|---|---|
| `CORPUS_CENSUS.csv` | census | Frozen. Never edit. |
| `DIRECTORY_LEDGER.jsonl` | census, then you | Append status lines. Latest line per `directory_id` wins. |
| `ARTIFACT_RECORDS.jsonl` | you | One line per record. Latest line per `item_id` wins. |
| `RELATIONSHIPS.jsonl` | census (exact matches), then you | Append only. |
| `QUEUE.jsonl` | census | Frozen batch plan. |
| `PROCESS_STATE.json` | census, then you | Small state file; rewrite whole file. |
| `RECONCILE_REPORT.json` | reconcile `--write` | Regenerated each audit. |
| `MANIFEST.md`, `GLOSSARY.md`, `CORPUS_OVERVIEW.md`, `RUN_REPORT.md` | you | Human-readable; derived from records only. |

**Append, don't rewrite.** To change a status, append a new line with the same ID. Never delete or edit earlier lines in a `.jsonl` file.

## Census columns

`item_id, item_type, path, parent_id, name, ext, size_bytes, mtime_utc, sha256, likely_binary, link_target, census_status, note`

- `item_type`: `DIRECTORY`, `FILE`, `LINK` (symlink or junction; never followed), `OTHER` (special file).
- `census_status`: `UNSEEN` (needs your review), or already terminal: `METADATA_ONLY`, `EXCLUDED_BY_RULE`, `INACCESSIBLE`.
- `likely_binary`: `true` when the first 8 KB contains a NUL byte. Binary files usually get `METADATA_ONLY` unless you have a way to read them.

## Artifact record (append to `ARTIFACT_RECORDS.jsonl`, one line)

```json
{"item_id":"F004821","path":"src/router/config.ts","status":"REVIEWED","inspection_level":"STANDARD","artifact_role":"configuration module","summary":"…","key_contents":[],"tags":[],"relationships":[],"uncertainty":null,"notes":null}
```

Required: `item_id`, `status`. Include `path` exactly as in the census (reconcile rejects a mismatch). Do not force a classification; use `uncertainty` instead.

Artifact statuses: `UNSEEN`, `QUEUED`, `PARTIAL` (not terminal); `REVIEWED`, `METADATA_ONLY`, `EXCLUDED_BY_RULE`, `FAILED`, `INACCESSIBLE`, `NEEDS_REVIEW` (terminal). `FAILED` and `NEEDS_REVIEW` are reportable exceptions, not omissions — include a `notes` reason and the useful next action.

For `PARTIAL` oversized artifacts add `"segments_total": N, "segments_done": [1,2]`.

## Inspection levels

| Level | Record content |
|---|---|
| `CENSUS` | Metadata only (status `METADATA_ONLY`) |
| `QUICK` | Apparent role plus one-line summary |
| `STANDARD` | Role, concise summary, important contents, relationships, uncertainty (default) |
| `DEEP` | Adds internal structure, dependencies/references, version significance, material issues |

## Directory status line (append to `DIRECTORY_LEDGER.jsonl`)

```json
{"directory_id":"D000042","status":"COMPLETE","summary":"…built only from this directory's records and completed child summaries…"}
```

Directory statuses: `UNSEEN`, `ACTIVE`, `PARTIAL` (not terminal); `COMPLETE`, `EXCLUDED_BY_RULE`, `INACCESSIBLE` (terminal). Reconcile flags any `COMPLETE` directory that still has a non-terminal artifact or child directory.

## Relationship line (append to `RELATIONSHIPS.jsonl`)

```json
{"type":"VERSION_OF","from":"F000120","to":"F000118","certainty":"PROBABLE","evidence":"same title, later date in header"}
```

Types: `EXACT_CONTENT_MATCH`, `NEAR_CONTENT_MATCH`, `VERSION_OF`, `SUPERSEDES`, `DERIVED_FROM`, `SOURCE_OF`, `EXPORT_OF`, `GENERATED_FROM`, `TESTS`, `CONFIGURES`, `REFERENCES`, `IMPLEMENTS`, `DOCUMENTS`, `ATTACHED_TO`, `RELATED_TO`. Certainty: `CONFIRMED`, `PROBABLE`, `POSSIBLE`. The census already wrote `EXACT_CONTENT_MATCH` lines for identical non-empty files; both records stay.

## PROCESS_STATE.json fields you maintain

`phase` (`CENSUS_FROZEN` → `PROCESSING` → `SYNTHESIS` → `AUDITED`), `profile`, `inspection_level`, `last_completed_batch`, `active_batch`, `next_action`, `exceptions` (IDs currently `FAILED` / `INACCESSIBLE` / `NEEDS_REVIEW` with reasons), and optionally `active_directory`, `oversized_in_progress` (IDs with segment progress), `open_relationship_questions`. Keep the census-written `counts` and `config` unchanged.
