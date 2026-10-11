"""Verify and record v02 scope, effective geometry, capture timing and file hashes."""
from pathlib import Path
from datetime import datetime, timezone, timedelta
import hashlib
import json
import math
import re
import subprocess
import sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'docs/验证/evidence/home-hit-feedback-r1'
BASE = '6c7cccf38c0265172527361d4a3277a67eabb3c1'
sys.path.insert(0, str(ROOT / '.tmp/b1-python'))
from lupa.lua54 import LuaRuntime, lua_type

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def native(value):
    if lua_type(value) != 'table': return value
    keys = list(value.keys())
    if keys and set(keys) == set(range(1, len(keys)+1)):
        return [native(value[i]) for i in range(1, len(keys)+1)]
    return {k: native(value[k]) for k in keys}

manifest_path = 'assets/image/home-entry-r3/source-manifest.json'
before = json.loads(subprocess.check_output(['git', 'show', BASE+':'+manifest_path], cwd=ROOT))
after = read(ROOT / manifest_path)
assert after['version'] == 'C-HOME-ENTRY-20261010-r3-v02'
assert before['layers'] == after['layers'] and before['objects'][1:] == after['objects'][1:]
assert {k:v for k,v in before.items() if k not in ('version','objects')} == {k:v for k,v in after.items() if k not in ('version','objects')}
assert {k:v for k,v in before['objects'][0].items() if k!='regions'} == {k:v for k,v in after['objects'][0].items() if k!='regions'}
for layer in after['layers']:
    assert sha(ROOT / 'assets' / layer['path']) == layer['sha256']

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('package.path = ... .. "/scripts/?.lua;" .. package.path', ROOT.as_posix())
manifest = lua.execute('return require("ui.landscape.LayoutManifest")')[0]
geometry = lua.execute('return require("ui.landscape.LayoutGeometry")')[0]
assert native(manifest) == after, 'Lua and JSON manifests differ'
region = manifest.objects[1]
layer = manifest.layers[region.layer]
windows = []
for w,h in [(1280,720),(1560,720),(1600,720),(1024,768),(800,360),(640,360)]:
    ui_scale = max(.625, min(math.sqrt(min(w,h)/720), 1))
    fit = geometry.Fit(lua.table_from(dict(x=0,y=48,w=w/ui_scale,h=h/ui_scale-84)), manifest)
    row = dict(window=[w,h], desktopDpr=1, uiScale=ui_scale, handles=[])
    for i in (1,2):
        old = geometry.Region(layer, lua.table_from(before['objects'][0]['regions'][i-1]), fit, 44 if i==1 else 0)
        new = geometry.ObjectRegion(layer, region, fit, i)
        def physical(r):
            x,y=geometry.Rotate(r.x,r.y,layer.rotation)
            return dict(center=[(fit.x+(layer.x+x)*fit.scale)*ui_scale,(fit.y+(layer.y+y)*fit.scale)*ui_scale],
                        size=[r.w*fit.scale*ui_scale,r.h*fit.scale*ui_scale])
        row['handles'].append(dict(index=i,before=physical(old),after=physical(new)))
    windows.append(row)
(OUT / 'geometry.json').write_text(json.dumps(dict(before=before['objects'][0],after=after['objects'][0],windows=windows,
    units='region fractions of untrimmed image; minTouch in UI base units; physical projections at desktop DPR=1'),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

captures = read(OUT / 'capture-index.json')
assert len(captures)==9
for item in captures:
    stamp=re.search(r'(\d{4}-\d\d-\d\d \d\d_\d\d_\d\d_\d{3})', item['marker']).group(1)
    down=datetime.strptime(stamp,'%Y-%m-%d %H_%M_%S_%f').replace(tzinfo=timezone(timedelta(hours=8)))
    start=datetime.fromisoformat(item['startUtc'].replace('Z','+00:00'))
    end=datetime.fromisoformat(item['endUtc'].replace('Z','+00:00'))
    assert 0 <= (start-down).total_seconds() <= (end-down).total_seconds() < 5, item['name']
assert len({sha(Path(item['file'])) for item in captures})==1, 'Held frames visually differ'

files = ['scripts/ui/landscape/'+name for name in ('HomeView.lua','LayoutGeometry.lua','LayoutManifest.lua','DevChecks.lua')]
files += ['scripts/ui/landscape/tests/'+name for name in ('import_layout.py','NativeProbe.lua','HitFeedbackProbe.lua','HitFeedbackTest.lua','run_hit_feedback.py','capture_hit_feedback.ps1','verify_hit_delivery.py')]
files += [manifest_path,'scripts/actions/2026-10-11-home-hit-feedback-r1.md']
render_files = ['scripts/ui/landscape/'+name for name in ('HomeView.lua','LayoutGeometry.lua','LayoutManifest.lua')]
runtime_sources = {}
for mode in ('normal','debug','final'):
    path = OUT / (mode+'-session.json')
    if not path.exists(): continue
    receipt = read(path)
    source = Path(receipt['preparation']['source_directory'])
    hashes = {p:sha(source/p) for p in render_files}
    assert hashes=={p:sha(ROOT/p) for p in render_files}, mode+' rendering code mismatch'
    runtime_sources[mode]=dict(session=receipt['session_id'],reload=receipt['reload_id'],renderCodeSha256=hashes,
                              devFlags=(source/'scripts/ui/landscape/DevChecks.lua').read_text(encoding='utf-8'))
result=dict(version=after['version'],task='C-HOME-HITFIX-20261011-r1',baselineCommit=BASE,
    projectRevision=201,pageRevision=189,imagesByteIdentical=True,visualTransformsUnchanged=True,otherObjectRegionsUnchanged=True,
    changedFileSha256={p:sha(ROOT/p) for p in files},screenshots={p.name:sha(p) for p in sorted(OUT.glob('*.png'))},
    normalHeldCaptureCount=9,capturesWithinPointerDownHold=True,normalHeldFramesByteIdentical=True,
    runtimeSources=runtime_sources,osMouseTested=False,phoneTested=False,
    scope='v01 locally committed; v02 remains uncommitted; no push/remote build/app rebinding')
(OUT/'delivery.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('PASS: v01 art/transforms/other objects preserved; Lua=JSON; nine captures inside held interval; runtime render source hashes match; delivery.json + geometry.json written')
