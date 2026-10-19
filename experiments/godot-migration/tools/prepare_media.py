"""Copy existing approved art without editing originals or importing engine code."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[3]
PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".tmp" / "b1-python"))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
scripts = (ROOT / "scripts").as_posix()
lua.execute("package.path = ... .. '/?.lua;' .. package.path", scripts)
manifest = lua.eval('require("ui.landscape.LayoutManifest")')
if isinstance(manifest, tuple):
    manifest = manifest[0]

def convert(value):
    if hasattr(value, "keys"):
        keys = list(value.keys())
        if keys and all(isinstance(k, int) for k in keys):
            return [convert(value[k]) for k in sorted(keys)]
        return {str(k): convert(value[k]) for k in keys}
    return value

data = convert(manifest)
paths = {row["path"] for row in data["layers"] if row.get("visible")}
paths.update({"image/title-screen-r1/shop-doorway-soft.png", "image/misty-harbor-r1/sea-calm.png",
    "image/misty-harbor-r1/dock-foreground.png", "image/brew-topdown/cauldron-v01.png",
    "image/brew-topdown/four-cell-tray-v01.png", "image/wish-collage-r1/soft-scrollwork-letter-paper.png",
    "fonts/HarborHand-Regular.ttf", "fonts/HarborHand-Medium.ttf",
    "audio/bgm/hearth-quiet-loop.wav"})
# Audio identity comes from the actual catalog, not a guessed file name.
audio = lua.eval('require("ui.landscape.AudioCatalog")')
if isinstance(audio, tuple):
    audio = audio[0]
paths.discard("audio/bgm/hearth-quiet-loop.wav")
paths.add(audio.BgmPath("hearth"))
for name in ["原料_海盐_透明_v01_20261013032602.png", "原料_夜露_透明_v01_20261013032602.png", "原料_灰烬草_透明_v01_20261013032602.png", "原料_干花瓣_透明_v01_20261013032602.png"]:
    paths.add("image/" + name)

rows = []
for path in sorted(paths):
    source = ROOT / "assets" / path
    target = PROJECT / "media" / path
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    rows.append({"source": "assets/" + path, "target": "media/" + path,
        "bytes": source.stat().st_size, "sha256": hashlib.sha256(source.read_bytes()).hexdigest()})
icon = ROOT / "docs/宣传素材/2026-10-18/11-游戏图标-柔金浅青-v02.png"
shutil.copyfile(icon, PROJECT / "media/icon.png")
rows.append({"source": icon.relative_to(ROOT).as_posix(), "target": "media/icon.png",
    "bytes": icon.stat().st_size, "sha256": hashlib.sha256(icon.read_bytes()).hexdigest()})
(PROJECT / "media" / "home-layout.json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
(PROJECT / "media" / "sources.json").write_text(json.dumps({"files": rows, "bgm": "media/" + audio.BgmPath("hearth")}, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Copied {len(rows)} approved assets; source game files unchanged")
