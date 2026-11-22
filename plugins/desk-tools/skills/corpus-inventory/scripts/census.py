#!/usr/bin/env python3
"""Deterministic corpus census for the corpus-inventory workflow.

Enumerates every directory and artifact under ROOT without following links,
assigns stable run-local IDs (D000001 / F000001), and writes the frozen census
plus empty record files into the inventory workspace.

Output is byte-identical to census.ps1 for the same tree and options, except
PROCESS_STATE.json (timestamps and absolute paths). Python 3.8+, standard
library only. Never modifies anything under ROOT.
"""

from __future__ import annotations

import argparse
import csv
import datetime as _dt
import fnmatch
import hashlib
import json
import os
import stat
import sys

SCHEMA_VERSION = 1
CENSUS_COLUMNS = [
    "item_id", "item_type", "path", "parent_id", "name", "ext", "size_bytes",
    "mtime_utc", "sha256", "likely_binary", "link_target", "census_status", "note",
]
BINARY_SNIFF_BYTES = 8192
BINARY_TOKEN_ESTIMATE = 50


def dumps(obj) -> str:
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"))


def sort_key(name: str) -> bytes:
    return name.encode("utf-8", "surrogateescape")


def ext_of(name: str) -> str:
    i = name.rfind(".")
    return name[i + 1:].lower() if i > 0 else ""


def mtime_utc(st) -> str:
    t = _dt.datetime.fromtimestamp(int(st.st_mtime), tz=_dt.timezone.utc)
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")


def matches(patterns, rel_path: str, name: str):
    for p in patterns:
        if fnmatch.fnmatchcase(rel_path, p) or fnmatch.fnmatchcase(name, p):
            return p
    return None


IO_REPARSE_TAG_SYMLINK = 0xA000000C
IO_REPARSE_TAG_MOUNT_POINT = 0xA0000003  # junction
FILE_ATTRIBUTE_OFFLINE = 0x1000
FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS = 0x400000  # OneDrive/SharePoint "files on demand"


def is_link(entry) -> bool:
    """Symlinks and junctions only. Other reparse points (cloud placeholders) are real files/dirs."""
    try:
        if entry.is_symlink():
            return True
        st = entry.stat(follow_symlinks=False)
        return getattr(st, "st_reparse_tag", 0) in (IO_REPARSE_TAG_SYMLINK, IO_REPARSE_TAG_MOUNT_POINT)
    except OSError:
        return False


def is_cloud_placeholder(st) -> bool:
    """True for Windows files whose content is not on disk; reading them would download them."""
    attrs = getattr(st, "st_file_attributes", 0)
    return bool(attrs & (FILE_ATTRIBUTE_OFFLINE | FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS))


def sniff_and_hash(path: str, want_hash: bool):
    """Return (likely_binary, sha256_hex_or_empty)."""
    h = hashlib.sha256() if want_hash else None
    binary = False
    first = True
    with open(path, "rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            if first:
                binary = b"\x00" in chunk[:BINARY_SNIFF_BYTES]
                first = False
            if h is None:
                break
            h.update(chunk)
    return binary, (h.hexdigest() if h is not None else "")


def main() -> int:
    ap = argparse.ArgumentParser(description="Deterministic corpus census (read-only on ROOT).")
    ap.add_argument("root", help="Source corpus root")
    ap.add_argument("--out", default=".inventory-manifest", help="Inventory workspace (default: ./.inventory-manifest)")
    ap.add_argument("--exclude", action="append", default=[], help="Glob (* and ?) on relative path or name; recorded, not descended. Repeatable.")
    ap.add_argument("--metadata-only", action="append", default=[], help="Glob; matching files (and files under matching dirs) get METADATA_ONLY. Repeatable.")
    ap.add_argument("--no-hash", action="store_true", help="Skip SHA-256 hashing")
    ap.add_argument("--max-hash-mb", type=int, default=100, help="Skip hashing files larger than this (default 100)")
    ap.add_argument("--batch-tokens", type=int, default=12000, help="Approximate source tokens per queue batch (default 12000 for 32K sessions)")
    ap.add_argument("--force", action="store_true", help="Overwrite an existing census in --out")
    args = ap.parse_args()
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # Windows pipes default to a legacy code page
    except (AttributeError, ValueError):
        pass

    root = os.path.abspath(args.root)
    out = os.path.abspath(args.out)
    if not os.path.isdir(root):
        print(f"ERROR: root is not a directory: {root}", file=sys.stderr)
        return 2
    if os.path.exists(os.path.join(out, "CORPUS_CENSUS.csv")) and not args.force:
        print(f"ERROR: a census already exists in {out}. The census is frozen; use --force only to start a new run.", file=sys.stderr)
        return 2
    os.makedirs(os.path.join(out, "batches"), exist_ok=True)

    out_rel = None
    rel_to_root = os.path.relpath(out, root)
    if rel_to_root != "." and not rel_to_root.startswith(".."):
        out_rel = rel_to_root.replace(os.sep, "/")

    max_hash_bytes = args.max_hash_mb * 1024 * 1024
    rows = []       # census rows (dicts)
    dirs = []       # directory ledger entries
    dir_index = {}  # directory_id -> ledger entry
    d_count = 0
    f_count = 0

    def new_dir_id():
        nonlocal d_count
        d_count += 1
        return f"D{d_count:06d}"

    def new_file_id():
        nonlocal f_count
        f_count += 1
        return f"F{f_count:06d}"

    # stack items: (abs_path, rel_path, name, parent_id, depth, metadata_only_inherited)
    stack = [(root, ".", os.path.basename(root) or root, "", 0, False)]
    while stack:
        abs_path, rel_path, name, parent_id, depth, meta_inh = stack.pop()
        did = new_dir_id()
        try:
            st = os.lstat(abs_path)
            mt = mtime_utc(st)
        except OSError:
            mt = ""
        entry = {
            "directory_id": did, "path": rel_path, "parent_id": parent_id, "depth": depth,
            "expected_direct_artifacts": 0, "expected_child_directories": 0,
            "direct_artifact_ids": [], "child_directory_ids": [],
            "status": "UNSEEN", "note": "",
        }
        dirs.append(entry)
        dir_index[did] = entry
        if parent_id:
            parent = dir_index[parent_id]
            parent["child_directory_ids"].append(did)
            parent["expected_child_directories"] += 1
        row = {c: "" for c in CENSUS_COLUMNS}
        row.update(item_id=did, item_type="DIRECTORY", path=rel_path, parent_id=parent_id,
                   name=name, mtime_utc=mt, census_status="UNSEEN")
        rows.append(row)

        excl = None
        if rel_path != ".":
            excl = matches(args.exclude, rel_path, name)
            if out_rel is not None and rel_path == out_rel:
                excl = excl or "inventory workspace"
        if excl:
            note = f"excluded by rule: {excl}; not descended"
            row.update(census_status="EXCLUDED_BY_RULE", note=note)
            entry.update(status="EXCLUDED_BY_RULE", note=note)
            continue
        meta_here = meta_inh or (rel_path != "." and matches(args.metadata_only, rel_path, name) is not None)

        try:
            with os.scandir(abs_path) as it:
                children = sorted(it, key=lambda e: sort_key(e.name))
        except OSError:
            note = "cannot list directory"
            row.update(census_status="INACCESSIBLE", note=note)
            entry.update(status="INACCESSIBLE", note=note)
            continue

        subdirs = []
        for e in children:
            child_rel = e.name if rel_path == "." else f"{rel_path}/{e.name}"
            link = is_link(e)
            try:
                is_dir = (not link) and e.is_dir(follow_symlinks=False)
            except OSError:
                is_dir = False
            if is_dir:
                subdirs.append((e.path, child_rel, e.name, did, depth + 1, meta_here))
                continue
            fid = new_file_id()
            entry["direct_artifact_ids"].append(fid)
            entry["expected_direct_artifacts"] += 1
            r = {c: "" for c in CENSUS_COLUMNS}
            r.update(item_id=fid, path=child_rel, parent_id=did, name=e.name, ext=ext_of(e.name),
                     census_status="UNSEEN")
            try:
                st = e.stat(follow_symlinks=False)
                r["mtime_utc"] = mtime_utc(st)
            except OSError:
                r.update(item_type="FILE", census_status="INACCESSIBLE", note="cannot stat")
                rows.append(r)
                continue
            if link:
                try:
                    target = os.readlink(e.path)
                except OSError:
                    target = ""
                r.update(item_type="LINK", link_target=target.replace("\\", "/"),
                         census_status="METADATA_ONLY", note="link not followed")
            elif stat.S_ISREG(st.st_mode):
                r.update(item_type="FILE", size_bytes=str(st.st_size))
                excl_f = matches(args.exclude, child_rel, e.name)
                want_hash = (not args.no_hash) and st.st_size <= max_hash_bytes
                if is_cloud_placeholder(st):
                    r["note"] = "cloud placeholder: not downloaded, not hashed"
                else:
                    try:
                        binary, digest = sniff_and_hash(e.path, want_hash)
                        r.update(likely_binary="true" if binary else "false", sha256=digest)
                        if (not args.no_hash) and not want_hash:
                            r["note"] = "hash skipped: size"
                    except OSError:
                        r.update(census_status="INACCESSIBLE", note="cannot read")
                if r["census_status"] == "UNSEEN":
                    if excl_f:
                        r.update(census_status="EXCLUDED_BY_RULE", note=f"excluded by rule: {excl_f}")
                    elif meta_here or matches(args.metadata_only, child_rel, e.name):
                        r.update(census_status="METADATA_ONLY", note="metadata-only by rule")
            else:
                r.update(item_type="OTHER", census_status="METADATA_ONLY", note="special file")
            rows.append(r)
        for s in reversed(subdirs):
            stack.append(s)

    # Exact-content relationships (non-empty files with identical SHA-256).
    groups = {}
    for r in rows:
        if r["item_type"] == "FILE" and r["sha256"] and r["size_bytes"] not in ("", "0"):
            groups.setdefault(r["sha256"], []).append(r["item_id"])
    relationships = []
    for digest in sorted(groups):
        ids = groups[digest]
        for other in ids[1:]:
            relationships.append({"type": "EXACT_CONTENT_MATCH", "from": other, "to": ids[0],
                                  "certainty": "CONFIRMED", "source": "census-sha256"})

    # Hierarchy-aware queue: UNSEEN files, grouped per directory in census order.
    queue = []
    by_id = {r["item_id"]: r for r in rows}
    b_count = 0
    for d in dirs:
        batch, tokens = [], 0
        def flush(items, toks, oversized=False):
            nonlocal b_count
            if not items:
                return
            b_count += 1
            queue.append({"batch_id": f"B{b_count:05d}", "directory_id": d["directory_id"],
                          "directory_path": d["path"], "item_ids": items, "est_tokens": toks,
                          "oversized": oversized})
        for fid in d["direct_artifact_ids"]:
            r = by_id[fid]
            if r["census_status"] != "UNSEEN":
                continue
            est = BINARY_TOKEN_ESTIMATE if r["likely_binary"] == "true" else (int(r["size_bytes"] or 0) + 3) // 4
            if est > args.batch_tokens:
                flush(batch, tokens)
                batch, tokens = [], 0
                flush([fid], est, oversized=True)
                continue
            if batch and tokens + est > args.batch_tokens:
                flush(batch, tokens)
                batch, tokens = [], 0
            batch.append(fid)
            tokens += est
        flush(batch, tokens)

    with open(os.path.join(out, "CORPUS_CENSUS.csv"), "w", encoding="utf-8", newline="", errors="backslashreplace") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(CENSUS_COLUMNS)
        for r in rows:
            w.writerow([r[c] for c in CENSUS_COLUMNS])

    def write_jsonl(fname, items):
        with open(os.path.join(out, fname), "w", encoding="utf-8", newline="\n", errors="backslashreplace") as f:
            for it in items:
                f.write(dumps(it) + "\n")

    write_jsonl("DIRECTORY_LEDGER.jsonl", dirs)
    write_jsonl("RELATIONSHIPS.jsonl", relationships)
    write_jsonl("QUEUE.jsonl", queue)
    write_jsonl("ARTIFACT_RECORDS.jsonl", [])

    by_status, by_type = {}, {}
    for r in rows:
        if r["item_type"] == "DIRECTORY":
            continue
        by_status[r["census_status"]] = by_status.get(r["census_status"], 0) + 1
        by_type[r["item_type"]] = by_type.get(r["item_type"], 0) + 1
    counts = {
        "directories": d_count,
        "artifacts": f_count,
        "artifacts_by_census_status": {k: by_status[k] for k in sorted(by_status)},
        "artifacts_by_type": {k: by_type[k] for k in sorted(by_type)},
        "exact_content_relationships": len(relationships),
        "queue_batches": len(queue),
    }
    state = {
        "schema_version": SCHEMA_VERSION,
        "phase": "CENSUS_FROZEN",
        "root": root,
        "output": out,
        "created_utc": _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "generator": "census.py",
        "config": {"exclude": args.exclude, "metadata_only": args.metadata_only,
                   "hash": not args.no_hash, "max_hash_mb": args.max_hash_mb,
                   "batch_tokens": args.batch_tokens},
        "counts": counts,
        "last_completed_batch": None,
        "next_action": f"Process batch {queue[0]['batch_id']}" if queue else "No UNSEEN artifacts; run reconcile",
    }
    with open(os.path.join(out, "PROCESS_STATE.json"), "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(state, ensure_ascii=False, indent=2) + "\n")

    print(dumps(counts))
    return 0


if __name__ == "__main__":
    sys.exit(main())
