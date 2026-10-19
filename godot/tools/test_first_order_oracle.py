"""Negative checks for the frozen first-order oracle bundle.

Run from the repository root:
    python godot/tools/test_first_order_oracle.py
"""
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / "tools"))
import export_first_order_oracle as oracle  # noqa: E402


def load() -> tuple[dict, dict]:
    base = PROJECT / "tests" / "fixtures" / "first_order"
    return (
        json.loads((base / "traces.json").read_text(encoding="utf-8")),
        json.loads((base / "manifest.json").read_text(encoding="utf-8")),
    )


def main() -> int:
    traces, manifest = load()
    failures = 0
    if oracle.validate_bundle(traces, manifest):
        print("[FirstOrderNegative] FAIL valid bundle rejected")
        return 1
    print("[FirstOrderNegative] PASS valid bundle")

    cases = []
    broken = copy.deepcopy(traces)
    broken["recipes"][0]["steps"] = broken["recipes"][0]["steps"][:2]
    cases.append(("missing steps", broken, manifest))

    broken = copy.deepcopy(traces)
    broken["recipes"][0]["recipe_id"] = "recipe_invalid"
    broken["recipes"][0]["case_id"] = "recipe_invalid"
    cases.append(("invalid recipe id", broken, manifest))

    broken = copy.deepcopy(traces)
    broken["source_hash"] = "0" * 64
    cases.append(("source hash changed", broken, manifest))

    broken_manifest = copy.deepcopy(manifest)
    broken_manifest["source_files"] = []
    cases.append(("missing source inventory", copy.deepcopy(traces), broken_manifest))

    for name, mutated_traces, mutated_manifest in cases:
        errors = oracle.validate_bundle(mutated_traces, mutated_manifest)
        if errors:
            print(f"[FirstOrderNegative] PASS {name}")
        else:
            failures += 1
            print(f"[FirstOrderNegative] FAIL {name}")
    if failures:
        return 1
    print(f"[FirstOrderNegative] PASS {len(cases)} negative cases")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
