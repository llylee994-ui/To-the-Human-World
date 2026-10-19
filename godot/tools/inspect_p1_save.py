"""Read-only inspection of a preserved P1 save directory.

This tool never writes, migrates, or clears a save. It reports the wrapper
version, revision, source tokens and any top-level P1 draft so the P2 package
can state that the old test slot was preserved and P2 starts a new slot.

Run from the repository root:
    python godot/tools/inspect_p1_save.py --dir <save-dir> --slot ordinary_release_v3
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_optional(path: Path) -> str | None:
    return path.read_text(encoding="utf-8") if path.exists() else None


def parse_marker(raw: str | None, side: str) -> dict | None:
    if not raw:
        return None
    parts = raw.strip().split("|")
    if len(parts) != 6 or parts[0] != "B1" or parts[2] != side or parts[5] != "END":
        return None
    if not parts[1].isdigit() or not parts[3].isdigit():
        return None
    return {"generation": int(parts[1]), "side": side, "length": int(parts[3]), "hash": parts[4]}


def lua_digest(raw: str) -> str:
    data = raw.encode("utf-8")
    n = 0
    stop = len(data) - len(data) % 4
    for index in range(0, stop, 4):
        a, b, c, d = data[index:index + 4]
        n = (n * 923521 + a * 29791 + b * 961 + c * 31 + d) % 4294967291
    for value in data[stop:]:
        n = (n * 31 + value) % 4294967291
    return str(n)


def verify(raw: str, marker: dict) -> bool:
    return len(raw.encode("utf-8")) == marker["length"] and lua_digest(raw) == marker["hash"]


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def select_payload(directory: Path, slot: str) -> tuple[dict | None, dict]:
    paths = {
        "legacy": directory / f"save_{slot}.json",
        "a": directory / f"save_{slot}_a.json",
        "b": directory / f"save_{slot}_b.json",
        "ca": directory / f"save_{slot}_a.commit",
        "cb": directory / f"save_{slot}_b.commit",
    }
    rows = []
    for side in ("a", "b"):
        marker = parse_marker(read_optional(paths["c" + side]), side)
        raw = read_optional(paths[side])
        if marker and raw is not None and verify(raw, marker):
            rows.append((marker["generation"], side, raw, marker))
    if rows:
        rows.sort(key=lambda row: row[0], reverse=True)
        generation, side, raw, marker = rows[0]
        return json.loads(raw), {"kind": "dual", "generation": generation, "side": side,
                                  "files": [str(paths[side]), str(paths["c" + side])],
                                  "sha256": sha256(paths[side])}
    legacy = read_optional(paths["legacy"])
    if legacy is not None:
        return json.loads(legacy), {"kind": "legacy", "generation": 0, "side": "legacy",
                                     "files": [str(paths["legacy"])],
                                     "sha256": sha256(paths["legacy"])}
    return None, {"kind": "missing", "files": []}


def inspect_value(value: dict) -> dict:
    if value.get("format") == "tthw-godot":
        payload = value.get("payload", {})
        live = payload.get("live", {})
        tokens = live.get("wordTokens", {}).get("byId", {})
        return {
            "wrapper": "tthw-godot",
            "schema_version": value.get("schema_version"),
            "content_version": value.get("content_version"),
            "revision": payload.get("revision"),
            "tokens": sorted(tokens.keys()),
            "draft": payload.get("draft"),
            "current_order_draft": (payload.get("currentOrder") or {}).get("draft")
                if isinstance(payload.get("currentOrder"), dict) else None,
            "payload_version": payload.get("payload_version"),
        }
    data = value.get("data", value)
    live = data.get("live", {})
    current = data.get("currentOrder", False)
    return {
        "wrapper": "lua-save",
        "schema_version": value.get("schema"),
        "content_version": data.get("contentVersion"),
        "revision": data.get("revision"),
        "tokens": sorted(live.get("wordTokens", {}).get("byId", {}).keys()),
        "draft": data.get("draft"),
        "current_order_draft": current.get("draft") if isinstance(current, dict) else None,
        "payload_version": None,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", required=True)
    parser.add_argument("--slot", default="ordinary_release_v3")
    args = parser.parse_args()
    directory = Path(args.dir)
    value, meta = select_payload(directory, args.slot)
    if value is None:
        print(json.dumps({"ok": False, "error": "no valid P1 save found", "slot": args.slot,
                          "directory": str(directory), "preserved": True}, ensure_ascii=False, indent=2))
        return 1
    report = {
        "ok": True,
        "slot": args.slot,
        "directory": str(directory),
        "preserved": True,
        "note": "P1 test slot is preserved; the P2 package starts a new independent slot.",
        "storage": meta,
    }
    report.update(inspect_value(value))
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
