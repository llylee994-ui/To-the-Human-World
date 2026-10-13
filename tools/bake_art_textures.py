"""Deterministic Lab-only material textures; no reference-image pixels are used."""
from pathlib import Path
import hashlib,json
import numpy as np
from scipy.ndimage import gaussian_filter,zoom
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/Textures/LabArt'
OUT.mkdir(parents=True,exist_ok=True)
N=1024
rng=np.random.default_rng(1012)
y,x=np.mgrid[0:N,0:N].astype(float);u=x/N;v=y/N
def noise(scale):
    a=rng.random((scale,scale));return zoom(a,N/scale,order=3,mode='wrap')[:N,:N]-.5
grain_noise=noise(128);broad=noise(8);medium=noise(32)
def save(name,rgb,height=None,strength=1):
    Image.fromarray(np.uint8(np.clip(rgb,0,1)*255)).save(OUT/(name+'.png'))
    if height is not None:
        dx=(np.roll(height,-1,1)-np.roll(height,1,1))*strength
        dy=(np.roll(height,-1,0)-np.roll(height,1,0))*strength
        vec=np.stack([-dx,-dy,np.ones_like(dx)],axis=2)
        vec/=np.linalg.norm(vec,axis=2)[:,:,None]
        Image.fromarray(np.uint8((vec*.5+.5)*255)).save(OUT/(name+'-normal.png'))
def color(base,value):return np.array(base)[None,None,:]*value[:,:,None]
# Long growth rings, irregular pores and knots; no plank seams baked into pixels.
warp=u+.010*np.sin(v*12+medium*.7)+.022*broad
lines=np.sin(warp*980+np.sin(warp*117)*5)
pores=np.maximum(0,lines-.75)**2
knot=np.zeros_like(u)
for cx,cy,s in [(.23,.24,1),(.77,.79,.7)]:
    d=np.sqrt((u-cx)**2*40+(v-cy)**2*3)
    knot+=np.sin(d*115)*np.exp(-d*7)*.21*s
height=medium*.07+grain_noise*.03-pores*.19+knot
weather=.86+medium*.13+broad*.17+grain_noise*.025-pores*.42+knot
save('wood',color([.65,.40,.22],weather),height,14)
# Copper hammer dents on a perturbed hexagonal lattice, with edge catch-light.
cx=u*34;cy=v*19;near=np.full_like(u,100.0)
for dx in [-1,0,1]:
 for dy in [-1,0,1]:
    iy=np.floor(cy)+dy;ix=np.floor(cx)+dx
    xx=ix+.5*(iy%2)+.10*np.sin(ix*7+iy*4)
    yy=iy+.1*np.sin(ix*13-iy*6)
    near=np.minimum(near,(cx-xx)**2+(cy-yy)**2)
dent=-np.exp(-near*6)*.16
patina=(broad*.08+medium*.03)
save('copper',color([.66,.34,.15],.88+patina+dent*.75+grain_noise*.015),dent+medium*.01,25)
save('plaster',color([.77,.69,.56],.97+broad*.07+medium*.045+grain_noise*.04),medium*.018+grain_noise*.022,9)
# Woven linen with restrained diamond/flower stitch motifs and thread relief.
weave=(np.sin(u*N*np.pi/2)*np.sin(v*N*np.pi/2))*.016
tileu=(u*6)%1-.5;tilev=(v*6)%1-.5
motif=np.exp(-((np.abs(tileu)+np.abs(tilev)-.32)/.025)**2)*.045
motif+=np.exp(-((tileu*tileu+tilev*tilev-.055)/.012)**2)*.027
save('linen',color([.90,.84,.72],.98+weave-motif+medium*.02),weave+motif,8)
save('paper',color([.93,.86,.69],.99+broad*.025+grain_noise*.018),grain_noise*.004,3)
save('book',color([.17,.25,.20],.9+broad*.15+medium*.05),grain_noise*.03,8)
save('leaf',color([.27,.36,.13],.85+np.sin(u*25)*.05+broad*.15),np.sin(v*150+u*8)*.007,7)
wave=np.sin(v*170+np.sin(u*56)*1.4)+.4*np.sin(v*347+u*89)+.20*np.sin(v*741+u*31)
save('sea',color([.19,.46,.66],.95+wave*.045),wave*.012,22)
# Painted ceramic: small glaze variations, no fake functional labels.
save('ceramic',color([.65,.51,.32],.96+medium*.045+grain_noise*.02),grain_noise*.006,4)
# Decorative woven rug, original mathematical motif (not copied reference imagery).
border=(np.minimum.reduce([u,v,1-u,1-v])<.08)
diamond=np.cos(u*90+v*60)*np.cos(u*90-v*60)
rgb=color([.32,.32,.25],.9+medium*.12)
rust=(diamond>.35)|border
rgb[rust]=np.array([.50,.29,.16])*(.85+medium[rust,None]*.12)
cream=(np.abs(diamond)<.08)&(~border)
rgb[cream]=[.69,.55,.35]
save('rug',rgb,(np.sin(x*np.pi)*np.cos(y*np.pi)+grain_noise)*.006,8)
# A decorative botany print: clearly illustration texture, not letter/business text.
im=Image.open(OUT/'paper.png').convert('RGB');d=ImageDraw.Draw(im)
for j in range(5):
    ox=230+j*138;oy=810-(j%2)*60
    d.line([(ox,oy),(ox-15,oy-370)],fill=(93,85,48),width=5)
    for k in range(4):
        yy=oy-80-k*78
        for side in [-1,1]:
            d.ellipse((ox-15+min(side*80,0),yy-45,ox+15+max(side*80,0),yy+8),fill=(105+j*3,113+j*2,67))
d.rectangle((32,32,990,990),outline=(148,121,75),width=7)
im.save(OUT/'botany.png')
manifest={'method':'Original deterministic procedural texture bake; no source image copied or edited','resolution':N,'files':[]}
for p in sorted(OUT.glob('*.png')):
 manifest['files'].append({'path':str(p.relative_to(ROOT)).replace('\\','/'),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(ROOT/'docs/evidence/3d-lab-r3/art-texture-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'textures':len(manifest['files']),'bytes':sum(f['bytes'] for f in manifest['files']),'size':N}))
