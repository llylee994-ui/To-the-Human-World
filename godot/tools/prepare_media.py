"""Copy the approved P0 media snapshot from the Maker project.

The source game, its assets and its editor data are read-only. This tool
exports the current home layout to JSON, copies only referenced media and
records source paths, hashes and image alpha bounds for later parity checks.

Run from the repository root:
    python godot/tools/prepare_media.py --scope p0
    python godot/tools/prepare_media.py --scope all
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".tmp" / "b1-python"))
from lupa.lua54 import LuaRuntime  # noqa: E402

P0_MEDIA = [
    "fonts/HarborHand-Regular.ttf",
    "fonts/HarborHand-Medium.ttf",
    "image/loading-r1/harbor-small-v01.jpg",
    "image/misty-harbor-r1/sea-calm.png",
    "image/misty-harbor-r1/home-foreground.png",
    "image/misty-harbor-r1/merchant-ship-muted.png",
    "image/home-entry-r3/tray.png",
    "image/home-entry-r3/net.png",
    "image/home-entry-r3/letter-paper.png",
    "image/home-entry-r3/lily-vase.png",
    "image/home-entry-r3/amber-jar.png",
    "image/home-entry-r3/herb-jar.png",
    "image/home-entry-r3/glass-bottle.png",
    "image/home-entry-r3/stove.png",
    "image/title-screen-r1/shop-doorway-soft.png",
    "image/story-result/button-skins-v01.png",
    "image/brew-topdown/cauldron-v01.png",
    "image/brew-topdown/four-cell-tray-v01.png",
    "image/原料_海盐_透明_v01_20261013032602.png",
    "image/原料_夜露_透明_v01_20261013032602.png",
    "image/原料_灰烬草_透明_v01_20261013032602.png",
    "image/原料_干花瓣_透明_v01_20261013032602.png",
    "image/界面_纸条_折痕_透明_v01.png",
    "image/界面_柔边纸面_透明_v01_20261013070534.png",
    "image/界面_深木牌_透明_v01_20261013070534.png",
    "image/界面_桌布_透明_v01.png",
    "image/界面_木托盘_透明_v01.png",
    "image/界面_干花束_透明_v01.png",
    "image/界面_记录书_左半厚书_透明_v01.png",
    "image/界面_记录书_索引纸签_透明_v01.png",
    "image/界面_记录书_麦穗干草_透明_v01.png",
    "image/界面_记录书_大朵干花_透明_v01.png",
    "image/wish-collage-r1/soft-scrollwork-letter-paper.png",
]


def lua_runtime() -> LuaRuntime:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("package.path = ... .. '/scripts/?.lua;' .. package.path", ROOT.as_posix())
    return lua


def convert(value):
    """Convert Lua tables to Python without losing array order."""
    if hasattr(value, "keys"):
        keys = list(value.keys())
        if keys and all(isinstance(key, int) for key in keys):
            return [convert(value[key]) for key in sorted(keys)]
        return {str(key): convert(value[key]) for key in keys}
    return value


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def image_info(path: Path) -> dict:
    try:
        from PIL import Image
    except ImportError:
        return {}
    try:
        with Image.open(path) as image:
            image = image.convert("RGBA")
            bounds = image.getchannel("A").getbbox()
            return {
                "width": image.width,
                "height": image.height,
                "alpha_bounds": list(bounds) if bounds else [0, 0, image.width, image.height],
            }
    except Exception as error:  # keep the media copy usable even if inspection fails
        return {"inspect_error": str(error)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scope", choices=["p0", "all"], default="p0")
    args = parser.parse_args()

    lua = lua_runtime()
    raw_layout = lua.eval('require("ui.landscape.LayoutManifest")')
    if isinstance(raw_layout, tuple):
        raw_layout = raw_layout[0]
    layout = convert(raw_layout)

    media_root = PROJECT / "media"
    media_root.mkdir(parents=True, exist_ok=True)
    layout_path = media_root / "home-layout.json"
    layout_path.write_text(json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    raw_panels = lua.eval('require("ui.landscape.PanelLayoutManifest")')
    if isinstance(raw_panels, tuple):
        raw_panels = raw_panels[0]
    panels = convert(raw_panels)
    panels_path = media_root / "panel-pages.json"
    panels_path.write_text(json.dumps(panels, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if args.scope == "p0":
        paths = list(P0_MEDIA)
    else:
        raw_preload = lua.eval('require("ui.landscape.PreloadManifest").AllEntries()')
        if isinstance(raw_preload, tuple):
            raw_preload = raw_preload[0]
        preload = convert(raw_preload)
        paths = [str(row["path"]) for row in preload]

    rows = []
    for relative in paths:
        source = ROOT / "assets" / relative
        if not source.exists():
            raise FileNotFoundError(f"missing source asset: {source}")
        target = media_root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        row = {
            "source": f"assets/{relative}",
            "target": f"media/{relative}",
            "bytes": source.stat().st_size,
            "sha256": sha256(source),
        }
        if relative.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
            row.update(image_info(source))
        rows.append(row)

    icon_source = ROOT / "docs/宣传素材/2026-10-18/11-游戏图标-柔金浅青-v02.png"
    if icon_source.exists():
        icon_target = media_root / "icon.png"
        shutil.copyfile(icon_source, icon_target)
        rows.append({
            "source": icon_source.relative_to(ROOT).as_posix(),
            "target": "media/icon.png",
            "bytes": icon_source.stat().st_size,
            "sha256": sha256(icon_source),
        })

    sources = {
        "scope": args.scope,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "layout_source": "scripts/ui/landscape/LayoutManifest.lua",
        "layout_sha256": sha256(ROOT / "scripts/ui/landscape/LayoutManifest.lua"),
        "panel_pages_source": "scripts/ui/landscape/PanelLayoutManifest.lua",
        "panel_pages_sha256": sha256(ROOT / "scripts/ui/landscape/PanelLayoutManifest.lua"),
        "files": rows,
    }
    (media_root / "sources.json").write_text(
        json.dumps(sources, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    total = sum(row["bytes"] for row in rows)
    print(f"P0 media prepared: {len(rows)} files, {total / 1024 / 1024:.1f} MiB")
    print(f"Layout: {layout_path.relative_to(ROOT).as_posix()}")
    print(f"Manifest: {(media_root / 'sources.json').relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
