"""Verify native camera telemetry and retain timestamped, unedited window captures."""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import math
import re
import shutil

ROOT = Path(__file__).resolve().parents[4]
EVIDENCE = ROOT / 'docs/验证/evidence/home-yaw-probe-r1'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--captures', type=Path, required=True)
    args = parser.parse_args()
    raw = []
    for path in sorted(EVIDENCE.glob('native-log-verified-part*.json')):
        raw.extend(row['text'] for row in json.loads(path.read_text(encoding='utf-8-sig'))['logs'])
    frames = {}
    for line in raw:
        match = re.search(r'\[HomeYawFrame\] (\{.*\})', line)
        if match:
            value = json.loads(match[1])
            frames[(value['wall'], value['frame'], value['state'])] = value
    frames = sorted(frames.values(), key=lambda v: (v['wall'], v['frame']))
    assert frames, 'No native camera samples'
    for frame in frames:
        assert max(abs(a-b) for a,b in zip(frame['position'], [0,1.65,0])) < 1e-5
        assert abs(frame['rotation'][0]-8) < 1e-4 and abs(frame['rotation'][2]) < 1e-4
        assert frame['fov'] == 50 and abs(frame['aspect']-16/9) < 1e-5
        assert frame['objectsUnchanged']
    final = [f for f in frames if f['state']=='complete']
    assert len(final) >= 3, 'Need repeated completed plays'
    assert all(abs(f['rotation'][1]-math.degrees(math.atan2(3.2,2.8)))<1e-4 for f in final)
    assert all(abs(f['potScreen'][0]-.5)<1e-5 for f in final)
    assert any('[HomeYawNative] PASS' in line for line in raw), 'No native lifecycle PASS'
    assert not any('[HomeYawNative] FAIL' in line or '[HomeYawProbe] ERROR' in line for line in raw)
    (EVIDENCE/'camera-timeline.json').write_text(json.dumps(frames,ensure_ascii=False,indent=2),encoding='utf-8')
    targets = sorted(set(re.findall(r'\[HomeYawTarget\] size=(\d+x\d+)', ''.join(raw))))
    assert len(targets)>=3, 'No native resized target evidence'

    # Keep the full motion interval plus one home frame at each end. Idle duplicate
    # captures remain in ignored .tmp; selected source pixels are copied unchanged.
    capture_rows = list(csv.DictReader((args.captures/'capture.csv').open(encoding='utf-8-sig')))
    motion_lines = [line for line in raw if '[HomeYawFrame]' in line]
    times = []
    from datetime import datetime, timezone, timedelta
    for line in motion_lines:
        m = re.search(r'\[(\d{4}-\d{2}-\d{2}) (\d{2})_(\d{2})_(\d{2})_(\d{3})\]', line)
        if m:
            date, h, minute, second, ms = m.groups()
            times.append(datetime.fromisoformat(f'{date}T{h}:{minute}:{second}.{ms}+08:00').astimezone(timezone.utc))
    assert times
    lo, hi = min(times)-timedelta(seconds=.4), max(times)+timedelta(seconds=3)
    selected = [r for i,r in enumerate(capture_rows) if i==0 or i==len(capture_rows)-1 or lo <= datetime.fromisoformat(r['utc'].replace('Z','+00:00')) <= hi]
    destination = EVIDENCE/'native-frames'
    destination.mkdir(exist_ok=True)
    for row in selected:
        name=f"frame-{int(row['frame']):04d}.png"
        shutil.copyfile(args.captures/name,destination/name)
    with (destination/'capture.csv').open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=capture_rows[0].keys());writer.writeheader();writer.writerows(selected)
    report={'camera_samples':len(frames),'completed_plays':len(final),'fixed_position':[0,1.65,0],
            'fixed_pitch':8,'fixed_roll':0,'fixed_vertical_fov':50,'yaw_end':final[0]['rotation'][1],
            'end_pot_screen':final[0]['potScreen'],'object_count':48,'objects_unchanged':True,
            'render_target_sizes':targets,'native_lifecycle':'PASS','capture_frames':len(selected),
            'capture_only':'Timestamped PrintWindow sampling; not a smoothness/FPS or OS touch acceptance',
            'raw_captures':str(args.captures),'first_capture':selected[0]['utc'],'last_capture':selected[-1]['utc']}
    (EVIDENCE/'verification-summary.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    manifest=[{'path':str(p.relative_to(EVIDENCE)).replace('\\','/'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in destination.glob('*.png')]
    (destination/'sha256.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False))

if __name__=='__main__':
    main()
