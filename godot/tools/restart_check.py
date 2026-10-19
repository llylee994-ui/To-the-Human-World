"""Run the real two-process save/reload check for P1.

Process 1 writes a user:// save with a cut token and draft and exits.
Process 2 starts fresh, loads the save and verifies revision, token and draft.

Run from the repository root:
    python godot/tools/restart_check.py
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = Path(__file__).resolve().parents[1]
DEFAULT_GODOT = Path(os.environ.get(
    "USERPROFILE", str(Path.home())
)) / ".codex/tools/godot/4.7.2-stable/editor/Godot_v4.7.2-stable_win64_console.exe"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    args = parser.parse_args()
    binary = Path(args.godot) if args.godot else Path(os.environ.get("GODOT_BIN", DEFAULT_GODOT))
    if not binary.exists():
        print(f"Godot console binary not found: {binary}", file=sys.stderr)
        return 2
    for script in ("restart_seed.gd", "restart_verify.gd"):
        result = subprocess.run(
            [str(binary), "--headless", "--path", str(PROJECT), "--script",
             "res://tests/integration/" + script],
            cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
        output = (result.stdout or "") + (result.stderr or "")
        print(f"--- {script} (exit {result.returncode}) ---")
        print(output.strip())
        if result.returncode != 0:
            return result.returncode
    print("[Restart] PASS separate Godot processes preserve revision, token and draft")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
