"""Run the Godot P0 import and headless suites.

Run from the repository root:
    python godot/tools/verify.py --suite layout
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = Path(__file__).resolve().parents[1]
DEFAULT_GODOT = Path(os.environ.get(
    "USERPROFILE", str(Path.home())
)) / ".codex/tools/godot/4.7.2-stable/editor/Godot_v4.7.2-stable_win64_console.exe"


def godot_binary(argument: str | None) -> Path:
    candidate = Path(argument) if argument else Path(os.environ.get("GODOT_BIN", DEFAULT_GODOT))
    if not candidate.exists():
        raise FileNotFoundError(
            f"Godot console binary not found: {candidate}. "
            "Pass --godot or set GODOT_BIN."
        )
    return candidate


def run(command: list[str], label: str) -> tuple[int, str]:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                            encoding="utf-8", errors="replace")
    output = (result.stdout or "") + (result.stderr or "")
    print(f"--- {label} (exit {result.returncode}) ---")
    print(output.strip()[-4000:])
    return result.returncode, output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=["content", "potion", "oracle", "commands", "faults", "foundation", "layout", "scenes", "drag", "readability", "all"], default="layout")
    parser.add_argument("--godot")
    parser.add_argument("--python-libs", default=str(ROOT / ".tmp" / "b1-python"))
    parser.add_argument("--skip-import", action="store_true")
    args = parser.parse_args()
    binary = godot_binary(args.godot)
    logs: list[str] = []
    if args.suite in {"content", "foundation", "all"}:
        for script in ("export_content.py", "export_oracle.py"):
            code, output = run([sys.executable, str(PROJECT / "tools" / script), "--check",
                                "--python-libs", args.python_libs], f"{script} --check")
            logs.append(output)
            if code != 0:
                print(f"{script} check failed; generated content is stale.")
                return code
        code, output = run([sys.executable, str(PROJECT / "tools" / "test_export_negative.py")],
                           "content:negative")
        logs.append(output)
        if code != 0:
            print("content negative checks failed.")
            return code
    if not args.skip_import:
        code, output = run([str(binary), "--headless", "--path", str(PROJECT),
                            "--editor", "--import", "--quit"], "import")
        logs.append(output)
        if code != 0:
            print("Godot import failed; export and tests will not be trusted.")
            return code
    code, output = run([str(binary), "--headless", "--path", str(PROJECT),
                        "--script", "res://tests/run_tests.gd", "--", f"--suite={args.suite}"],
                       f"tests:{args.suite}")
    logs.append(output)
    if code == 0 and args.suite in {"commands", "foundation", "all"}:
        restart_code, restart_output = run(
            [sys.executable, str(PROJECT / "tools" / "restart_check.py"), "--godot", str(binary)],
            "restart:separate-process",
        )
        logs.append(restart_output)
        if restart_code != 0:
            code = restart_code
    p0_suites = {"layout", "scenes", "drag", "readability"}
    evidence = PROJECT / "docs" / "evidence" / ("p0-verify.txt" if args.suite in p0_suites else "p1-verify.txt")
    evidence.parent.mkdir(parents=True, exist_ok=True)
    evidence.write_text(
        f"generated_at={datetime.now(timezone.utc).isoformat()}\n"
        f"suite={args.suite}\n\n" + "\n".join(logs),
        encoding="utf-8",
    )
    print(f"evidence: {evidence.relative_to(ROOT).as_posix()}")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
