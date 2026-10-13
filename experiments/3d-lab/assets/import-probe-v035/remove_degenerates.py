import json,pathlib,math
P=pathlib.Path(__file__).resolve().parent;r=json.loads((P/'probe.json').read_text());removed=0
for m in r['meshes']:
 keep=[];v=m['positions']
 for j in range(0,len(m['indices']),3):
  ids=m['indices'][j:j+3];a,b,c=[v[i*3:i*3+3] for i in ids];u=[b[i]-a[i] for i in range(3)];w=[c[i]-a[i] for i in range(3)];cross=[u[1]*w[2]-u[2]*w[1],u[2]*w[0]-u[0]*w[2],u[0]*w[1]-u[1]*w[0]]
  if sum(x*x for x in cross)<1e-24:removed+=1
  else:keep.extend(ids)
 pos=[];norm=[];uv=[]
 for i in keep:pos.extend(m['positions'][3*i:3*i+3]);norm.extend(m['normals'][3*i:3*i+3]);uv.extend(m['uv0'][2*i:2*i+2])
 m['positions']=pos;m['normals']=norm;m['uv0']=uv;m['indices']=list(range(len(keep)))
 for g in r['groups']:
  if g['meshId']==m['id']:g['triangles']=len(keep)//3
r['removedZeroAreaSourceTriangles']=removed;(P/'probe.json').write_text(json.dumps(r,separators=(',',':')))
manifest=json.loads((P/'manifest.json').read_text());manifest['meshes']['triangles']=sum(len(m['indices'])//3 for m in r['meshes']);manifest['removedZeroAreaSourceTriangles']=removed;(P/'manifest.json').write_text(json.dumps(manifest,indent=2))
read=(P/'README.txt').read_text().replace('8,256 triangles','8,128 triangles');read+='\n128 zero-area copper-pole triangles were removed after export; they cover no visible surface, so the reference preview appearance is unchanged. Run remove_degenerates.py after exporting and adding proxies when rebuilding the package.\n';(P/'README.txt').write_text(read);print('Removed',removed)
