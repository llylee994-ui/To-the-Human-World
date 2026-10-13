"""Correct only the audited closed, inward-facing floor shell; preserve all positions/UVs."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[1]/'assets/v035-full'
p=ROOT/'meshes/full_group_018_000.json'
old='c657a0062d8bb7340c55dcf3ad6d17420edefb847309b6dbd6bf6d5312b74b5f'
assert hashlib.sha256(p.read_bytes()).hexdigest()==old,'requires original audited floor'
m=json.loads(p.read_text());m['normals']=[-v for v in m['normals']]
for i in range(0,len(m['indices']),3):m['indices'][i+1],m['indices'][i+2]=m['indices'][i+2],m['indices'][i+1]
p.write_text(json.dumps(m,separators=(',',':')))
new=hashlib.sha256(p.read_bytes()).hexdigest()
s=ROOT/'scene.json';data=json.loads(s.read_text())
for e in data['meshFiles']:
 if e['id']==m['id']:e['sha256']=new
for mat in data['materials']:
 if mat['id']=='full_mat_018':mat['cullMode']='CW'
s.write_text(json.dumps(data,ensure_ascii=False,indent=2))
h=ROOT/'runtime-assets.sha256.json';hs=json.loads(h.read_text())
for key in hs:hs[key]=hashlib.sha256((ROOT/key).read_bytes()).hexdigest()
h.write_text(json.dumps(hs,indent=2)+'\n')
print('floor:',old,'->',new)
