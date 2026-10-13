"""Set only the lab's preview size using the installed Maker window.json schema.
Maker 0.0.36 windowSettings.ts read/save validation: maker.js lines 44311-44368.
The CLI has no window subcommand. This is local preview configuration only.
"""
from pathlib import Path
import json,sys,datetime
root=Path(__file__).resolve().parents[1]
w,h=map(int,sys.argv[1:3]); assert 100<=h<=w<=4096
dirs=[p for p in (root/'.preview-home/preview').iterdir() if p.is_dir()]
assert len(dirs)==1, 'Do not guess a preview project directory'
target=dirs[0]/'window.json'; assert target.resolve().is_relative_to(root.resolve())
before=json.loads(target.read_text(encoding='utf-8')) if target.exists() else None
settings={'orientation':'landscape','preset':'custom','custom':{'longEdge':w,'shortEdge':h}}
target.write_text(json.dumps(settings),encoding='utf-8')
e={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'path':str(target),'before':before,'after':settings,'scope':'Only local preview dimensions; no app/binding/token or project identity changed. Actual size must be checked after official refresh.'}
(root/f'docs/evidence/3d-lab-r3/preview-size-{w}x{h}.json').write_text(json.dumps(e,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(e,ensure_ascii=False))
