"""Apply explicitly audited closed negative-shell corrections, never guess open surfaces."""
import argparse,json,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--audit',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1]/'assets/v035-full'; audit=json.loads(a.audit.read_text());report=[]
for mid,e in audit['meshes'].items():
 if e.get('alreadyRepaired') or not e['triangleIndices']:continue
 path=root/e['file']; before=hashlib.sha256(path.read_bytes()).hexdigest();assert before==e['originalSha256'],mid+' input changed'
 m=json.loads(path.read_text());sel=set(e['triangleIndices']);selected=set();other=set()
 for i in range(len(m['indices'])//3):
  (selected if i in sel else other).update(m['indices'][i*3:i*3+3])
 assert not selected&other,mid+' vertices shared between corrected and uncorrected components: require split'
 for i in selected:
  for k in range(3):m['normals'][i*3+k]=-m['normals'][i*3+k]
 for i in sel:m['indices'][i*3+1],m['indices'][i*3+2]=m['indices'][i*3+2],m['indices'][i*3+1]
 path.write_text(json.dumps(m,separators=(',',':')))
 report.append({'id':mid,'trianglesReversed':len(sel),'normalsReversed':len(selected),'shaBefore':before,'shaAfter':hashlib.sha256(path.read_bytes()).hexdigest()})
s=root/'scene.json';data=json.loads(s.read_text());byid={e['id']:e for e in report}
for m in data['meshFiles']:
 if m['id'] in byid:m['sha256']=byid[m['id']]['shaAfter']
# Blender CCW outward faces rendered by the calibrated RH camera need CW culling.
# Transparent/double-sided materials retain their existing policy.
for m in data['materials']:
 if not m.get('doubleSided') and m.get('renderVisible',True):m['cullMode']='CW'
s.write_text(json.dumps(data,ensure_ascii=False,indent=2))
h=root/'runtime-assets.sha256.json';hs=json.loads(h.read_text())
for name in hs:hs[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
h.write_text(json.dumps(hs,indent=2)+'\n')
Path('docs/cloud-closed-shell-repair.json').write_text(json.dumps({'auditSha256':hashlib.sha256(a.audit.read_bytes()).hexdigest(),'repairs':report,'trianglesReversed':sum(r['trianglesReversed'] for r in report),'positionsUVIndicesCountsUnchanged':True,'sharedVerticesAcrossRepairedBoundaries':0,'openComponentNormalsUnchanged':True},indent=2)+'\n')
print(len(report),'meshes',sum(r['trianglesReversed'] for r in report),'triangles repaired')
