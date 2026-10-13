import json,math,pathlib
P=pathlib.Path(__file__).resolve().parent;r=json.loads((P/'probe.json').read_text());c=r['camera'];pos=c['position'];f=c['forward'];up=c['up']
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
right=cross(f,up);sizes={'home.net':(.055,.19),'home.merchantShip':(.095,.17),'home.letterPaper':(.14,.07),'home.tray':(.14,.09),'home.drawer':(.15,.095),'home.journal':(.12,.10),'home.caseFile':(.07,.12),'home.stove':(.13,.18)}
r['proxyMeshes']=[]
for a in r['interactionProxies']:
 center=a['position'];d=sum((center[i]-pos[i])*f[i] for i in range(3));w,h=sizes[a['id']];hw=d*math.tan(math.radians(c['horizontalFovDegrees']/2))*w;hh=d*math.tan(math.radians(c['verticalFovDegrees']/2))*h;v=[]
 for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]:v.extend(center[i]+x*hw*right[i]+y*hh*up[i] for i in range(3))
 r['proxyMeshes'].append({'id':'proxy_'+a['id'],'interactionId':a['id'],'materialId':'interaction_proxy_invisible','positions':v,'normals':[-x for x in f]*4,'uv0':[0,0,1,0,1,1,0,1],'indices':[0,1,2,0,2,3],'renderVisible':False,'pickable':True})
 a['screenSize']=list(sizes[a['id']]);a['proxyMeshId']='proxy_'+a['id']
r['materials'].append({'id':'interaction_proxy_invisible','baseColorFactor':[1,1,1,0],'alphaMode':'BLEND','unlit':True,'doubleSided':True,'renderVisible':False,'note':'Prefer separate non-rendering pick geometry; not a visible room image'})
(P/'probe.json').write_text(json.dumps(r,separators=(',',':')))
