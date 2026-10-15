#!/usr/bin/env python3
"""Validate original CSVs and stage lossless CRLF-terminated copies for BULK INSERT."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def validate_sources() -> list[dict]:
    expected = json.loads((ROOT / "tests/source_manifest.json").read_text())
    actual = []
    for spec in expected:
        path = ROOT / spec["path"]
        with path.open(newline="", encoding="utf-8-sig") as stream:
            reader = csv.reader(stream)
            columns = next(reader)
            count = 0
            for line, row in enumerate(reader, 2):
                if len(row) != len(columns):
                    raise ValueError(f"CSV column count mismatch: {path.name}, record {line}")
                count += 1
        found = {"path": spec["path"], "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                 "columns": columns, "rows": count}
        if found != spec:
            raise ValueError(f"Source differs from the versioned tutorial manifest: {spec['path']}")
        actual.append(found)
    if len(actual) != 6:
        raise ValueError("Expected exactly six source files")
    return actual


def prepare_sources(destination: Path) -> list[dict]:
    sources = validate_sources()
    original_root = (ROOT / "datasets").resolve()
    destination = destination.resolve()
    if destination == original_root or original_root in destination.parents:
        raise ValueError("Staging must be outside the original datasets directory")
    report = []
    for spec in sources:
        original = ROOT / spec["path"]
        content = original.read_bytes()
        appended = not content.endswith(b"\r\n")
        staged = content + b"\r\n" if appended else content
        target = destination / original.relative_to(original_root)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(staged)
        # Parse the output too: the final terminator must not create/drop a row.
        with target.open(newline="", encoding="utf-8-sig") as stream:
            rows = list(csv.reader(stream))
        if len(rows) - 1 != spec["rows"] or rows[0] != spec["columns"]:
            raise ValueError(f"Staging changed CSV records: {spec['path']}")
        report.append({**spec, "appended_final_crlf": appended,
                       "staged_sha256": hashlib.sha256(staged).hexdigest()})
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(prepare_sources(args.output), indent=2))
