"""Prepare a pinned official portable Godot and matching export templates."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import urllib.request
import zipfile

VERSION = "4.7.2-stable"
ROOT = Path.home() / ".codex" / "tools" / "godot" / VERSION
BASE = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}/"

def download(name):
    ROOT.mkdir(parents=True, exist_ok=True)
    final = ROOT / name
    if final.exists():
        return final
    part = final.with_suffix(final.suffix + ".part")
    request = urllib.request.Request(BASE + name, headers={"User-Agent": "ToTheHumanWorld-Migration-Spike"})
    with urllib.request.urlopen(request, timeout=90) as response, part.open("wb") as target:
        total = int(response.headers.get("Content-Length", 0))
        done = 0
        reported = -1
        while chunk := response.read(2 * 1024 * 1024):
            target.write(chunk)
            done += len(chunk)
            step = done // (100 * 1024 * 1024)
            if step != reported:
                print(f"[download] {name}: {done // 1048576}/{total // 1048576} MiB", flush=True)
                reported = step
    part.replace(final)
    return final

def prepare(name, sums):
    archive = download(name)
    expected = None
    for row in sums.splitlines():
        fields = row.split()
        if len(fields) >= 2 and fields[-1].lstrip("*") == name:
            expected = fields[0]
            break
    if expected is None:
        raise RuntimeError(f"No official SHA512 for {name}")
    actual = hashlib.file_digest(archive.open("rb"), "sha512").hexdigest()
    if actual != expected:
        raise RuntimeError(f"SHA512 mismatch: {name}")
    if name.endswith(".exe.zip"):
        dest = ROOT / "editor"
        with zipfile.ZipFile(archive) as source:
            source.extractall(dest)
        print(f"[ready] editor={dest}; official SHA512 verified", flush=True)
    else:
        dest = ROOT / "templates"
        dest.mkdir(exist_ok=True)
        with zipfile.ZipFile(archive) as source:
            for entry in source.infolist():
                if Path(entry.filename).name in {"android_debug.apk", "android_release.apk", "windows_debug_x86_64.exe", "windows_release_x86_64.exe", "version.txt"}:
                    (dest / Path(entry.filename).name).write_bytes(source.read(entry))
        print(f"[ready] templates={dest}; official SHA512 verified", flush=True)
    evidence = ROOT / (name + ".verified.json")
    evidence.write_text(json.dumps({"url": BASE + name, "sha512": actual, "bytes": archive.stat().st_size}, indent=2), encoding="utf-8")

if __name__ == "__main__":
    sums = download("SHA512-SUMS.txt").read_text(encoding="utf-8")
    names = [f"Godot_v{VERSION}_win64.exe.zip", f"Godot_v{VERSION}_export_templates.tpz"]
    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(lambda name: prepare(name, sums), names))
