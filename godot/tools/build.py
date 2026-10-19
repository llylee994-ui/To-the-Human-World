"""Export the P0 debug packages and write a delivery receipt.

Run from the repository root:
    python godot/tools/build.py --target all --configuration debug --output godot/build/p0
"""
from __future__ import annotations

import argparse
import hashlib
import json
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

PRESETS = {
    "android": "Android P0",
    "windows": "Windows P0",
}
ARTIFACTS = {
    "android": "ToTheHumanWorld-P0-Android-debug.apk",
    "windows": "ToTheHumanWorld-P0-Windows-debug.exe",
}


def godot_binary(argument: str | None) -> Path:
    candidate = Path(argument) if argument else Path(os.environ.get("GODOT_BIN", DEFAULT_GODOT))
    if not candidate.exists():
        raise FileNotFoundError(f"Godot console binary not found: {candidate}")
    return candidate


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=["windows", "android", "all"], default="all")
    parser.add_argument("--configuration", choices=["debug", "release"], default="debug")
    parser.add_argument("--output", default="godot/build/p0")
    parser.add_argument("--godot")
    args = parser.parse_args()
    if args.configuration != "debug":
        print("P0 only exports debug packages. Release signing belongs to P6.", file=sys.stderr)
        return 2
    binary = godot_binary(args.godot)
    output = (ROOT / args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("ANDROID_HOME", "C:/Android")
    os.environ.setdefault("ANDROID_SDK_ROOT", "C:/Android")
    if Path("C:/Program Files/Java/jdk-21").exists():
        os.environ.setdefault("JAVA_HOME", "C:/Program Files/Java/jdk-21")

    import_code = subprocess.run(
        [str(binary), "--headless", "--path", str(PROJECT), "--editor", "--import", "--quit"],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    print("--- import ---")
    print(((import_code.stdout or "") + (import_code.stderr or "")).strip()[-2500:])
    if import_code.returncode != 0:
        print("import failed", file=sys.stderr)
        return import_code.returncode

    targets = ["windows", "android"] if args.target == "all" else [args.target]
    artifacts = []
    for target in targets:
        destination = output / ARTIFACTS[target]
        command = [str(binary), "--headless", "--path", str(PROJECT),
                   "--export-debug", PRESETS[target], str(destination)]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                encoding="utf-8", errors="replace")
        print(f"--- export {target} (exit {result.returncode}) ---")
        print(((result.stdout or "") + (result.stderr or "")).strip()[-3000:])
        if result.returncode != 0 or not destination.exists() or destination.stat().st_size <= 0:
            print(f"export failed: {target}", file=sys.stderr)
            return result.returncode or 1
        artifacts.append({
            "target": target,
            "path": destination.relative_to(ROOT).as_posix(),
            "bytes": destination.stat().st_size,
            "sha256": sha256(destination),
        })

    source_revision = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True
    ).stdout.strip()
    godot_version = subprocess.run(
        [str(binary), "--version"], cwd=ROOT, capture_output=True, text=True
    ).stdout.strip()
    receipt = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source_revision": source_revision,
        "godot_version": godot_version,
        "configuration": args.configuration,
        "scope": "P0 visual baseline; no formal gameplay, orders or saves",
        "presets": {target: PRESETS[target] for target in targets},
        "artifacts": artifacts,
    }
    receipt_path = output / "delivery.json"
    receipt_path.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"delivery: {receipt_path.relative_to(ROOT).as_posix()}")
    for artifact in artifacts:
        print(f"{artifact['target']}: {artifact['bytes']} bytes sha256={artifact['sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
