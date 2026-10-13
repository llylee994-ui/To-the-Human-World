"""Select unmodified native PNGs and timestamped transition sequences for review."""
from pathlib import Path
import json,datetime,hashlib,shutil,html
root=Path(__file__).resolve().parents[1]; evidence=root/'docs/evidence/3d-lab-r3'; native=evidence/'native'; selected=native/'selected'
selected.mkdir(exist_ok=True)
pairs=[('native-qa-local-r1','native-qa-r1-official'),('aspect-16x9','aspect-16x9-official'),('aspect-21x9','aspect-21x9-official'),('aspect-4x3','aspect-4x3-official')]
rows=[]
def timestamp(s): return datetime.datetime.strptime(s,'%Y%m%dT%H%M%S%fZ').replace(tzinfo=datetime.timezone.utc)
def iso(s): return datetime.datetime.fromisoformat(s.replace('Z','+00:00'))
def add(path,name,label,utc,source):
    dest=selected/name; shutil.copyfile(path,dest)
    rows.append({'file':name,'label':label,'utc':utc,'original':str(path.relative_to(root)),'series':source,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'bytes':dest.stat().st_size})
add(native/'20261012-lab-window-r0.png','home-first-native.png','首轮原生Home，参考图尚未查看','2026-10-12T04:23:55.637Z','first-native')
for series,summary in pairs:
    f=native/series/'frames.jsonl'; report=evidence/summary/'summary.json'
    if not f.exists() or not report.exists(): continue
    frames=[json.loads(x) for x in f.read_text(encoding='utf-8-sig').splitlines() if x.strip()]
    frames=[x for x in frames if x['success']]
    qa=json.loads(report.read_text(encoding='utf-8'))['native_qa']; chosen={}
    for event in qa:
        if event['status']!='BEGIN' or event['name'].startswith('aspect ') and series=='native-qa-local-r1': continue
        t=iso(event['utc']); name=event['name']
        # Consecutive source frames spanning each actual camera route.
        motion=any(x in name for x in ('to Seaside','Seaside return','to Brew','Brew return','aspect reader close','aspect Seaside','aspect Brew'))
        if motion:
            duration=6 if ('Seaside' in name or 'reader close' in name) else 3
            for frame in frames:
                dt=(timestamp(frame['utc'])-t).total_seconds()
                if -0.2<=dt<=duration: chosen[frame['file']]=(frame,name+' / 路径连续帧')
        else:
            candidates=[x for x in frames if 0.5<=(timestamp(x['utc'])-t).total_seconds()<=3.5]
            if candidates: chosen[candidates[0]['file']]=(candidates[0],name+' / 阶段静态帧')
    for name,(frame,label) in sorted(chosen.items()):
        add(native/series/name,series+'--'+name,label,frame['utc'],series)
manifest={'generated_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'method':'Byte-for-byte copies of own-window PrintWindow PNGs. No compositing, repainting or generated imagery. Native automated calls, no OS input.','limitation':'Selected consecutive still frames are time-stamped; they do not establish smooth video playback or human-input acceptance. Latest user reference images remain unavailable.','frames':rows}
(selected/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
cards=[]
for row in rows:
    cards.append('<figure><a href="selected/'+html.escape(row['file'])+'"><img loading="lazy" src="selected/'+html.escape(row['file'])+'"></a><figcaption>'+html.escape(row['series']+' · '+row['label'])+'<br>'+html.escape(row['utc'])+'</figcaption></figure>')
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>D3 Lab 原生证据</title><style>body{font:16px/1.5 system-ui;margin:32px;background:#f6efdf;color:#302b22}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(400px,1fr));gap:20px}figure{margin:0;background:white;padding:12px}img{width:100%;height:auto}figcaption{padding-top:8px;font-size:13px}</style><h1>寄往人间 · 原生运行证据</h1><p>D3-LAB-20261012-r3-v01。实际Windows Runtime窗口、原图未改动。程序驱动验证，不等于人工输入验收；连续静态帧不证明播放流畅度。四张用户参考图仍未材料化，当前外观是文字约束默认值。</p><p>点击帧查看原始尺寸；时间为UTC。完整来源及SHA256见 selected/manifest.json。</p><main>'''+''.join(cards)+'</main></html>'
(native/'gallery.html').write_text(page,encoding='utf-8')
print(json.dumps({'selected_frames':len(rows),'bytes':sum(r['bytes'] for r in rows),'gallery':str(native/'gallery.html')}))
