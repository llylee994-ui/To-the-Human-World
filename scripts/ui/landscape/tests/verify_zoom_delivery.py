"""Scope and evidence checks for C-HOME-ZOOM-20261011-r1-v01."""
from pathlib import Path
import hashlib
import json
import subprocess
ROOT=Path(__file__).resolve().parents[4]
OUT=ROOT/'docs/验证/evidence/home-zoom-r1'
BASE='0136ebda0b692d010aad740894f3386fd9aa0dc2'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
baseline=read(ROOT/'docs/验证/evidence/home-hit-feedback-r1/delivery.json')
for path,digest in baseline['changedFileSha256'].items():
    if path!='scripts/ui/landscape/HomeView.lua': assert sha(ROOT/path)==digest,path
manifest=read(ROOT/'assets/image/home-entry-r3/source-manifest.json')
for layer in manifest['layers']: assert sha(ROOT/'assets'/layer['path'])==layer['sha256']
preserved=['scripts/ui/PlayView.lua','scripts/ui/PlayModel.lua','scripts/main.lua','scripts/core','scripts/systems','scripts/data',
    'urhox-libs','scripts/ui/landscape/Panels.lua','scripts/ui/landscape/LayoutManifest.lua','scripts/ui/landscape/LayoutGeometry.lua',
    'assets/image','docs/验证/evidence/home-entry-r3','docs/验证/evidence/home-hit-feedback-r1']
subprocess.run(['git','diff','--exit-code',BASE,'--',*preserved],cwd=ROOT,check=True)
timeline=read(OUT/'offline-timeline.json')
assert all(sha(ROOT/p)==v for p,v in timeline['sourceSha256'].items())
for frame in timeline['frames']: assert sha(OUT/frame['image'])==frame['imageSha256']
assert len(timeline['frames'])==20
assert len({f['stateSha256'] for f in timeline['frames']})==1
assert not read(OUT/'preview-status-final.json')['process_alive']
files=['scripts/ui/landscape/'+s for s in ('AppView.lua','HomeView.lua','HomeZoom.lua')]
files+=['scripts/ui/landscape/tests/'+s for s in ('HomeEntryTest.lua','HomeZoomTest.lua','ZoomTestHost.lua','run_home_zoom.py','export_zoom_evidence.py','verify_zoom_delivery.py')]
files+=['scripts/actions/2026-10-11-home-zoom-r1.md']
delivery=dict(version='C-HOME-ZOOM-20261011-r1-v01',baselineVersion=baseline['version'],baselineCommit=BASE,
    projectRevision=201,pageRevision=189,parameters=dict(startScale=1,targetScale=1.15,durationSeconds=.45,
        easing='smoothstep t*t*(3-2*t)',anchorDesign=[600,540],anchorNormalized=[.3125,.5],gapCancelSeconds=.25),
    destination='existing seaside renderer in Panels.lua',officialSeasideArtIntegrated=False,
    visualsAndHotspotsPreserved=True,assetsUnchanged=True,onlyTrigger='home.net',
    checks=dict(zoomStateAssertions=383,homeEntryAssertions=303,hitFeedbackAssertions=210706,
        nativePlayback='UNVERIFIED: preview not alive; no start permitted',osMouse='UNVERIFIED',phone='UNVERIFIED',
        offlineFrames=20,offlineAspectRatios=['16:9','19.5:9','20:9','4:3']),
    interruptionPolicy='cancel on observed focus loss/minimize, fit change, dt or elapsed gap > .25s, or root destruction; reset scale/blocker; no deferred navigation',
    changedFileSha256={p:sha(ROOT/p) for p in files},
    evidenceSha256={p.name:sha(p) for p in OUT.iterdir() if p.is_file() and p.name!='delivery.json'},
    commitPolicy='baseline v02 committed locally; current zoom work uncommitted; no push/build/binding change')
(OUT/'delivery.json').write_text(json.dumps(delivery,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('PASS scope: v02 controls/art/manifests/business preserved; final source matches offline replay; 20 frame hashes verified; preview remains stopped')
