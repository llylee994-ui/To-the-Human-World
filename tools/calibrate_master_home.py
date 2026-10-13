"""Fit a perspective camera to explicitly recorded image landmarks; no image edits.
Bottom-right doorway point is partly obscured and therefore has low weight.
"""
import math,json,random
from pathlib import Path
root=Path(__file__).resolve().parents[1]
aspect=1672/941
points=[((-3.75,3.4,3.55),(.179,.084),1),((-1.55,3.4,3.55),(.427,.106),1),((-3.75,0,3.55),(.172,.776),.6),((-1.55,0,3.55),(.438,.624),.22)]
def project(point,p):
 x,y,z,yaw,pitch=p
 f=(math.sin(yaw)*math.cos(pitch),-math.sin(pitch),math.cos(yaw)*math.cos(pitch))
 right=(math.cos(yaw),0,-math.sin(yaw)); up=(math.sin(yaw)*math.sin(pitch),math.cos(pitch),math.cos(yaw)*math.sin(pitch))
 d=(point[0]-x,point[1]-y,point[2]-z); dep=sum(a*b for a,b in zip(d,f))
 if dep<=.1:return (-10,-10)
 h=math.tan(math.radians(54/2))*dep
 return (.5+sum(a*b for a,b in zip(d,right))/(2*h*aspect),.5-sum(a*b for a,b in zip(d,up))/(2*h))
def score(p):
 bounds=[(-4.0,-1.0),(1.8,3.2),(-5.0,-1.5),(0.1,.8),(-.10,.45)]
 if any(not a<=v<=b for v,(a,b) in zip(p,bounds)):return 1e9
 return sum(w*sum((a-b)**2 for a,b in zip(project(pt,p),expected)) for pt,expected,w in points)
best=[-3,2.45,-3,.46,.13]; rng=random.Random(112)
for restart in range(20):
 p=best[:] if restart==0 else [best[i]+rng.uniform(-.15,.15)*(1 if i<3 else .2) for i in range(5)]
 steps=[.3,.2,.3,.06,.06]
 for iteration in range(140):
  improved=False
  for i in range(5):
   for sign in (-1,1):
    q=p[:];q[i]+=steps[i]*sign
    if score(q)<score(p):p=q;improved=True
  if not improved:steps=[s*.7 for s in steps]
 if score(p)<score(best):best=p
x,y,z,yaw,pitch=best
look=[x+6*math.sin(yaw)*math.cos(pitch),y-6*math.sin(pitch),z+6*math.cos(yaw)*math.cos(pitch)]
d={'reference':'libfile_6ea7753ee7a48191aa842fadeeb7db67','reference_rgba_sha256':'477413f9265ed4aca1deb3a3b92c89d758394e0c3de1792c0eb4209d02871061','method':'Least squares fit of perspective door anchors, fixed 54 degree vertical FOV. Not a claim that this AI-painted reference has physically exact perspective.','position':best[:3],'look':look,'yaw_degrees':math.degrees(yaw),'pitch_degrees':math.degrees(pitch),'fov':54,'weighted_squared_error':score(best),'anchors':[{'world':pt,'reference':expected,'weight':w,'projected':project(pt,best)} for pt,expected,w in points]}
(root/'docs/evidence/3d-lab-r3/master-camera-calibration.json').write_text(json.dumps(d,indent=2),encoding='utf-8')
print(json.dumps(d,indent=2))
