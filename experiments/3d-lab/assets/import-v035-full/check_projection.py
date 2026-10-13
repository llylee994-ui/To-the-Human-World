"""Pure Python, standard library only. No Blender or engine dependency."""
import json,math,pathlib
P=pathlib.Path(__file__).resolve().parent;r=json.loads((P/'camera_projection_reference.json').read_text())
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def transform(v):return [v[0],v[2],-v[1]]
def project(p,c,right,up,forward):
 d=[x-y for x,y in zip(p,c)];z=dot(d,forward);f=r['frustumSlopes'];return [(dot(d,right)/z-f['left'])/(f['right']-f['left']),1-(dot(d,up)/z-f['bottom'])/(f['top']-f['bottom'])]
errors=[]
for t in r['tests']:
 v=project(t['world'],r['position'],r['right'],r['up'],r['forward']);w=project(transform(t['world']),transform(r['position']),transform(r['right']),transform(r['up']),transform(r['forward']));e=max(abs(v[i]-t['expectedScreenTopLeft'][i]) for i in [0,1]);mapped=max(abs(w[i]-v[i]) for i in [0,1]);errors.append(e);assert e<1e-6 and mapped<1e-12,(t['id'],e,mapped);print(t['id'],v)
print('PASS',len(errors),'anchors; maximum Blender-reference error',max(errors))
