"""Replay production tray geometry with the real font; NOT native/phone evidence."""
from pathlib import Path
from functools import lru_cache
import hashlib
import json
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'docs/验证/evidence/word-slip-sizing-r1'
sys.path.insert(0, str(ROOT / 'scripts/debug'))
from PIL import Image, ImageDraw, ImageFont
import run_b1
from lupa.lua54 import lua_type
from content_test_runtime import run

FONT = ROOT / 'assets/fonts/HarborHand-Regular.ttf'
TEXTURE = ROOT / 'assets/image/界面_纸条_折痕_透明_v01.png'
frames = []
original = run_b1.LuaRuntime


@lru_cache(maxsize=32)
def font(size):
    return ImageFont.truetype(str(FONT), size)


def native(value):
    if lua_type(value) != 'table':
        return value
    keys = list(value.keys())
    if keys and set(keys) == set(range(1, len(keys)+1)):
        return [native(value[i]) for i in range(1, len(keys)+1)]
    return {str(k): native(value[k]) for k in keys}


def runtime(*args, **kwargs):
    lua = original(*args, **kwargs)

    def measure(text, size, face):
        assert face == 'story'
        return font(round(size*4)).getlength(text)/4

    lua.globals().SLIP_FONT_MEASURE = measure
    lua.globals().SLIP_EVIDENCE = lambda w, h, area, rows: frames.append(
        dict(width=w, height=h, area=native(area), rows=native(rows)))
    return lua


def paper(texture, width, height):
    # Same source/end fractions as WordSlip.Draw; preserve each end's aspect.
    iw, ih = texture.size
    source = round(iw*.08)
    edge = min(width//4, round(source*height/ih))
    result = Image.new('RGBA', (width, height))
    for crop, x, dest in [((0, 0, source, ih), 0, edge),
                          ((source, 0, iw-source, ih), edge, width-2*edge),
                          ((iw-source, 0, iw, ih), width-edge, edge)]:
        result.alpha_composite(texture.crop(crop).resize((dest, height), Image.Resampling.LANCZOS), (x, 0))
    return result


if __name__ == '__main__':
    run_b1.LuaRuntime = runtime
    if run('ui.landscape.tests.WordSlipEvidence'):
        raise SystemExit(1)
    OUT.mkdir(parents=True, exist_ok=True)
    texture = Image.open(TEXTURE).convert('RGBA')
    widths = [max(440, round(frame['area']['w']*1.6)+50) for frame in frames]
    image = Image.new('RGB', (sum(widths)+40, 1050), '#302921')
    draw = ImageDraw.Draw(image)
    draw.text((28, 22), 'OFFLINE / 真实字体 + Lua 纸条布局 / 非引擎或手机截图', font=font(26), fill='#efe5ce')
    for index, frame in enumerate(frames):
        ox, oy, scale = 30+sum(widths[:index]), 125, 1.6
        draw.text((ox, 78), f"{frame['width']} × {frame['height']}", font=font(23), fill='#efe5ce')
        area = frame['area']
        visible = [row for row in frame['rows'] if row.get('page', 1) == 1][:6]
        end = max(row['y']+row['metrics']['height'] for row in visible)
        draw.rounded_rectangle((ox-10, oy-10, ox+area['w']*scale+10, oy+end*scale+16), 12, fill='#62472e')
        for row in visible:
            m = row['metrics']
            x, y = round(ox+row['x']*scale), round(oy+row['y']*scale)
            w, h = round(m['width']*scale), round(m['height']*scale)
            image.paste(paper(texture, w, h), (x, y), paper(texture, w, h))
            lines = m['text'].split('\n')
            fp = row['fontPixels']
            center_y = y+(m['height']+m['reserveTop'])*scale/2
            for i, line in enumerate(lines):
                ly = center_y+(i-(len(lines)-1)/2)*fp*1.35*scale
                draw.text((x+w/2, ly), line, font=font(round(fp*scale)), fill='#412f20', anchor='mm')
        draw.text((ox, oy+end*scale+40), f"全量词库：{len(frame['rows'])-6} 个词 + 6 个边界样本", font=font(18), fill='#efe5ce')
    image.save(OUT/'offline-word-slips.png')
    files = [FONT, TEXTURE] + [ROOT/'scripts/ui/landscape'/name for name in
             ['WordSlip.lua', 'WordTrayDrawer.lua', 'WishPaper.lua', 'WishView.lua', 'BrewView.lua', 'BrewInteraction.lua']]
    (OUT/'geometry.json').write_text(json.dumps(dict(evidence='OFFLINE', frames=frames,
        sha256={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}), ensure_ascii=False, indent=2), encoding='utf-8')
    print(OUT/'offline-word-slips.png')
