"""Read-only geometric replay of the failed case-file anchor ray."""
from pathlib import Path
import json,numpy as np
root=Path(__file__).resolve().parents[1]/'assets/v035-full'
s=json.loads((root/'scene.json').read_text());a=next(a for a in s['interactionProxies'] if a['id']=='home.caseFile')
origin=np.array(s['camera']['position']);delta=np.array(a['position'])-origin
distance=np.linalg.norm(delta);direction=delta/distance;hits=[]
for desc in s['meshFiles']:
    mesh=json.loads((root/desc['file']).read_text())
    p=np.array(mesh['positions']).reshape(-1,3);idx=np.array(mesh['indices']).reshape(-1,3)
    v=p[idx];e1=v[:,1]-v[:,0];e2=v[:,2]-v[:,0]
    h=np.cross(direction,e2);det=np.einsum('ij,ij->i',e1,h)
    valid=np.abs(det)>1e-10;inv=np.divide(1,det,out=np.zeros_like(det),where=valid)
    offset=origin-v[:,0];u=np.einsum('ij,ij->i',offset,h)*inv
    q=np.cross(offset,e1);vv=np.einsum('j,ij->i',direction,q)*inv
    t=np.einsum('ij,ij->i',e2,q)*inv
    valid &= (u>=0)&(vv>=0)&(u+vv<=1)&(t>0)
    if valid.any():
        nearest=float(t[valid].min())
        hits.append({'mesh':mesh['id'],'distance':nearest,'differenceFromProxy':nearest-float(distance),'material':mesh['materialId'],'ownedByCase':mesh['id'] in a['visibleMeshIds'],'hitPoint':(origin+nearest*direction).tolist()})
result={'anchor':a,'anchorDistance':float(distance),'nearestHits':sorted(hits,key=lambda x:x['distance'])[:12],'scope':'offline exact source ray, not native octree'}
out=root.parents[1]/'docs/evidence/v035-main-interface/case-ray-diagnosis.json'
out.write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
