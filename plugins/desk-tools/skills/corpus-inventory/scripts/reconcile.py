#!/usr/bin/env python3
"""No-loss reconciliation for the corpus-inventory workflow.

Reads the frozen census and the append-only record files in the inventory
workspace, applies "latest line per ID wins", and reports every artifact and
directory that is not yet in a terminal accounted state.

Exit codes: 0 = fully reconciled (or --batch complete); 1 = incomplete;
2 = record errors (bad JSON, unknown IDs, path mismatch, invalid status).
Output is byte-identical to reconcile.ps1. Python 3.8+, standard library only.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys

ARTIFACT_STATUSES = {"UNSEEN", "QUEUED", "PARTIAL", "REVIEWED", "METADATA_ONLY",
                     "EXCLUDED_BY_RULE", "FAILED", "INACCESSIBLE", "NEEDS_REVIEW"}
ARTIFACT_TERMINAL = {"REVIEWED", "METADATA_ONLY", "EXCLUDED_BY_RULE", "FAILED",
                     "INACCESSIBLE", "NEEDS_REVIEW"}
DIRECTORY_STATUSES = {"UNSEEN", "ACTIVE", "PARTIAL", "COMPLETE", "EXCLUDED_BY_RULE", "INACCESSIBLE"}
DIRECTORY_TERMINAL = {"COMPLETE", "EXCLUDED_BY_RULE", "INACCESSIBLE"}


def read_jsonl(path, errors, label):
    items = []
    if not os.path.exists(path):
        return items
    with open(path, "r", encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            if not line.strip():
                continue
            try:
                obj = json.loads(line)
            except ValueError:
                errors.append(f"{label}:{n}: invalid JSON")
                continue
            if not isinstance(obj, dict):
                errors.append(f"{label}:{n}: not a JSON object")
                continue
            items.append((n, obj))
    return items


def counted(d):
    return {k: d[k] for k in sorted(d)}


def main() -> int:
    ap = argparse.ArgumentParser(description="Reconcile inventory records against the frozen census.")
    ap.add_argument("--out", default=".inventory-manifest", help="Inventory workspace (default: ./.inventory-manifest)")
    ap.add_argument("--batch", help="Check only this queue batch (e.g. B00012)")
    ap.add_argument("--limit", type=int, default=50, help="Max IDs listed per category (default 50)")
    ap.add_argument("--write", action="store_true", help="Also write RECONCILE_REPORT.json to the workspace")
    args = ap.parse_args()
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # Windows pipes default to a legacy code page
    except (AttributeError, ValueError):
        pass

    out = os.path.abspath(args.out)
    census_path = os.path.join(out, "CORPUS_CENSUS.csv")
    if not os.path.exists(census_path):
        print(f"ERROR: no census at {census_path}", file=sys.stderr)
        return 2

    errors = []
    artifacts = {}   # id -> {"path":..., "status":...}
    with open(census_path, "r", encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            if row["item_type"] != "DIRECTORY":
                artifacts[row["item_id"]] = {"path": row["path"], "status": row["census_status"]}

    directories = {}  # id -> ledger entry with current status
    for n, obj in read_jsonl(os.path.join(out, "DIRECTORY_LEDGER.jsonl"), errors, "DIRECTORY_LEDGER.jsonl"):
        did = obj.get("directory_id")
        if not isinstance(did, str):
            errors.append(f"DIRECTORY_LEDGER.jsonl:{n}: missing directory_id")
            continue
        status = obj.get("status")
        if did not in directories:
            if "direct_artifact_ids" not in obj:
                errors.append(f"DIRECTORY_LEDGER.jsonl:{n}: unknown directory_id {did}")
                continue
            directories[did] = {"path": obj.get("path", ""),
                                "direct": list(obj.get("direct_artifact_ids") or []),
                                "children": list(obj.get("child_directory_ids") or []),
                                "status": status}
        elif status is not None:
            if "path" in obj and obj["path"] != directories[did]["path"]:
                errors.append(f"DIRECTORY_LEDGER.jsonl:{n}: path mismatch for {did}")
            directories[did]["status"] = status
        if status is not None and status not in DIRECTORY_STATUSES:
            errors.append(f"DIRECTORY_LEDGER.jsonl:{n}: invalid status {json.dumps(status, ensure_ascii=False)} for {did}")

    for n, obj in read_jsonl(os.path.join(out, "ARTIFACT_RECORDS.jsonl"), errors, "ARTIFACT_RECORDS.jsonl"):
        iid = obj.get("item_id")
        if iid not in artifacts:
            errors.append(f"ARTIFACT_RECORDS.jsonl:{n}: unknown item_id {json.dumps(iid, ensure_ascii=False)}")
            continue
        if "path" in obj and obj["path"] != artifacts[iid]["path"]:
            errors.append(f"ARTIFACT_RECORDS.jsonl:{n}: path mismatch for {iid}")
        status = obj.get("status")
        if status not in ARTIFACT_STATUSES:
            errors.append(f"ARTIFACT_RECORDS.jsonl:{n}: invalid status {json.dumps(status, ensure_ascii=False)} for {iid}")
            continue
        artifacts[iid]["status"] = status

    report = {}
    if args.batch:
        batch = None
        for _, obj in read_jsonl(os.path.join(out, "QUEUE.jsonl"), errors, "QUEUE.jsonl"):
            if obj.get("batch_id") == args.batch:
                batch = obj
        if batch is None:
            errors.append(f"QUEUE.jsonl: batch {args.batch} not found")
            ids = []
        else:
            ids = list(batch.get("item_ids") or [])
        pending = sorted(i for i in ids if i not in artifacts or artifacts[i]["status"] not in ARTIFACT_TERMINAL)
        report = {
            "mode": "batch",
            "batch_id": args.batch,
            "expected": len(ids),
            "terminal": len(ids) - len(pending),
            "pending_count": len(pending),
            "pending_ids": pending[: args.limit],
            "errors": errors[: args.limit],
            "error_count": len(errors),
            "result": "ERRORS" if errors else ("BATCH_COMPLETE" if not pending else "BATCH_INCOMPLETE"),
        }
    else:
        a_status, d_status = {}, {}
        for a in artifacts.values():
            a_status[a["status"]] = a_status.get(a["status"], 0) + 1
        for d in directories.values():
            d_status[d["status"]] = d_status.get(d["status"], 0) + 1
        unaccounted_a = sorted(i for i, a in artifacts.items() if a["status"] not in ARTIFACT_TERMINAL)
        unaccounted_d = sorted(i for i, d in directories.items() if d["status"] not in DIRECTORY_TERMINAL)
        premature = []
        for did in sorted(directories):
            d = directories[did]
            if d["status"] != "COMPLETE":
                continue
            open_a = [i for i in d["direct"] if artifacts.get(i, {}).get("status") not in ARTIFACT_TERMINAL]
            open_d = [c for c in d["children"] if directories.get(c, {}).get("status") not in DIRECTORY_TERMINAL]
            if open_a or open_d:
                premature.append(did)
        ok = not errors and not unaccounted_a and not unaccounted_d and not premature
        report = {
            "mode": "full",
            "artifacts": len(artifacts),
            "directories": len(directories),
            "artifacts_by_status": counted(a_status),
            "directories_by_status": counted(d_status),
            "unaccounted_artifact_count": len(unaccounted_a),
            "unaccounted_artifact_ids": unaccounted_a[: args.limit],
            "unaccounted_directory_count": len(unaccounted_d),
            "unaccounted_directory_ids": unaccounted_d[: args.limit],
            "premature_complete_count": len(premature),
            "premature_complete_ids": premature[: args.limit],
            "error_count": len(errors),
            "errors": errors[: args.limit],
            "result": "ERRORS" if errors else ("RECONCILED" if ok else "INCOMPLETE"),
        }

    text = json.dumps(report, ensure_ascii=False, indent=2)
    if args.write:
        with open(os.path.join(out, "RECONCILE_REPORT.json"), "w", encoding="utf-8", newline="\n") as f:
            f.write(text + "\n")
    print(text)
    if report["result"] == "ERRORS":
        return 2
    return 0 if report["result"] in ("RECONCILED", "BATCH_COMPLETE") else 1


if __name__ == "__main__":
    sys.exit(main())
