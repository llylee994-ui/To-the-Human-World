"""Negative content-schema checks for the Python exporter.

Run from the repository root:
    python godot/tools/test_export_negative.py
"""
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / "tools"))
import export_content  # noqa: E402


def errors_for(catalog: dict, schema: dict) -> list[dict]:
    return export_content.validate_catalog(copy.deepcopy(catalog), schema)


def has_error(errors: list[dict], code: str, path_fragment: str) -> bool:
    return any(error.get("code") == code and path_fragment in str(error.get("path", ""))
               for error in errors)


def main() -> int:
    schema = json.loads((PROJECT / "content" / "content_schema.json").read_text(encoding="utf-8"))
    catalog = json.loads((PROJECT / "content" / "generated" / "catalog.json").read_text(encoding="utf-8"))
    cases = []

    mutated = copy.deepcopy(catalog)
    mutated["collections"]["words"][0]["attributeProfileId"] = "missing_profile"
    cases.append(("missing attributeProfileId", mutated, "UNKNOWN_REF", "attributeProfileId"))

    mutated = copy.deepcopy(catalog)
    mutated["collections"]["directRules"][0]["when"][0]["op"] = "unknown_operator"
    cases.append(("unknown rule operator", mutated, "CONTENT_INVALID", ".op"))

    mutated = copy.deepcopy(catalog)
    mutated["collections"]["ingredients"][0]["addTags"] = []
    cases.append(("addTags object becomes array", mutated, "CONTENT_INVALID", ".addTags"))

    mutated = copy.deepcopy(catalog)
    mutated["collections"]["directRules"][0]["unless"] = {}
    cases.append(("unless array becomes object", mutated, "CONTENT_INVALID", ".unless"))

    mutated = copy.deepcopy(catalog)
    order_letter = next(row for row in mutated["collections"]["letters"] if row.get("kind") == "order")
    order_letter["requirement"]["forbiddenEffects"] = {}
    cases.append(("forbiddenEffects array becomes object", mutated, "CONTENT_INVALID", ".forbiddenEffects"))

    failures = 0
    for name, mutated, code, path_fragment in cases:
        errors = errors_for(mutated, schema)
        if has_error(errors, code, path_fragment):
            print(f"[ContentNegative] PASS {name}")
        else:
            failures += 1
            print(f"[ContentNegative] FAIL {name}: {errors[:3]}")
    if failures:
        return 1
    print(f"[ContentNegative] PASS {len(cases)} negative cases")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
