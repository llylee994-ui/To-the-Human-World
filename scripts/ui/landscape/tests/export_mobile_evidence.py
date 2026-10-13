"""Actual Lua widget trees + manifest art, replayed by CSS. Not native evidence."""
from pathlib import Path
import json
import sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'docs/验证/evidence/mobile-safe-r1'
sys.path.insert(0, str(ROOT / 'scripts/debug'))
import run_b1
from content_test_runtime import run
from lupa.lua54 import lua_type
from export_shop_evidence import native, tree, HTML

frames = []
original = run_b1.LuaRuntime
def runtime(*args, **kwargs):
    lua = original(*args, **kwargs)
    def capture(w,h,scale,scene,safe,menu,root,fit,home,sea):
        frames.append(dict(width=w,height=h,scale=scale,selected=scene,tree=tree(root),safe=native(safe),menu=native(menu),fit=native(fit),home=native(home),sea=native(sea)))
    lua.globals().MOBILE_EVIDENCE = capture
    return lua

ART = '''
function asset(path){return ASSET_ROOT+'/'+path;}
async function sceneArt(f){
 const width=f.width/f.scale,height=f.height/f.scale;
 const host=document.createElement('div');host.style.cssText=`position:absolute;left:0;top:0;width:${width}px;height:${height}px;overflow:hidden;pointer-events:none`;
 const img=(path,x,y,w,h,angle=0)=>{const el=document.createElement('img');el.src=asset(path);el.style.cssText=`position:absolute;left:${x}px;top:${y}px;width:${w}px;height:${h}px;transform:rotate(${angle}deg);transform-origin:center`;host.appendChild(el);};
 const fit=f.fit,manifest=f.selected==='home'?f.home:f.sea;
 const s=Math.max(width/1920,height/1080),aw=1920*s,ah=1080*s;
 const x=width/height>=1920/1080?0:(width-aw)/2,y=width/height>=1920/1080?height-ah:(height-ah)/2;
 img('image/misty-harbor-r1/sea-calm.png',x,y,aw,ah);
 if(f.selected==='home'){
  img('image/misty-harbor-r1/sea-calm.png',fit.x,fit.y-115*fit.scale,1920*fit.scale,1080*fit.scale);
  for(const layer of manifest.layers)if(layer.visible)img(layer.path,fit.x+(layer.x-layer.width/2)*fit.scale,fit.y+(layer.y-layer.height/2)*fit.scale,layer.width*fit.scale,layer.height*fit.scale,layer.rotation);
 }else{img(manifest.foreground,fit.x,fit.y,fit.w,fit.h);const ship=manifest.ship;img(ship.path,fit.x+(ship.x-ship.width/2)*fit.scale,fit.y+(ship.y-ship.height/2)*fit.scale,ship.width*fit.scale,ship.height*fit.scale);}
 return host;
}
const originalDraw=draw;
draw=function(selected=chosen){
 originalDraw(selected);
 const f=frames.find(f=>f.selected===chosen&&f.width===innerWidth&&f.height===innerHeight);
 if(!f)return;
 const root=stage.firstElementChild;
 // mainPanel is inside the entry SafeAreaView; AppView extends through it.
 const parent=document.createElement('div');parent.style.cssText=`position:absolute;left:${f.safe.left}px;top:${f.safe.top}px;width:${f.width/f.scale-f.safe.left-f.safe.right}px;height:${f.height/f.scale-f.safe.top-f.safe.bottom}px`;
 root.replaceWith(parent);parent.appendChild(root);
 if(f.selected!=='shop')sceneArt(f).then(art=>root.querySelector(f.selected==='home'?'#homeView':'#seasideView').prepend(art));
 for(const id of ['homeHints','homeHintIntro','homeObjectFeedback']){const node=root.querySelector('#'+id);if(node)node.style.display='none';}
 const capsule=document.createElement('div');capsule.id='simulatedCapsule';const m=f.menu;
 capsule.style.cssText=`position:absolute;left:${m.left*f.width/f.scale}px;top:${m.top*f.height/f.scale}px;width:${(m.right-m.left)*f.width/f.scale}px;height:${(m.bottom-m.top)*f.height/f.scale}px;border-radius:30px;background:#2229;color:white;font:25px sans-serif;display:flex;align-items:center;justify-content:space-evenly;z-index:9000`;
 capsule.textContent='••• │ ◎';stage.appendChild(capsule);
};
draw('shop');window.MOBILE_PREVIEW={draw};
'''

if __name__ == '__main__':
    run_b1.LuaRuntime = runtime
    if run('ui.landscape.tests.MobileEvidenceHost', 'HEAD'):
        raise SystemExit(1)
    OUT.mkdir(parents=True, exist_ok=True)
    html = HTML.replace('FRAMES',json.dumps(frames, ensure_ascii=False).replace('</','<\\/'))
    html = html.replace("let chosen='ing_sea_salt'", "let chosen='shop'")
    html = html.replace("s.fontSize=length(p.fontSize)", "s.fontSize=length(p.fontSize*4/3)")
    html = html.replace('OFFLINE · 实际 Lua 控件树的 CSS 重放 · 非引擎/手机截图', 'OFFLINE · 模拟刘海和胶囊 · 非手机/引擎截图')
    html = html.replace('</script>', 'const ASSET_ROOT='+json.dumps((ROOT/'assets').as_uri())+';\n'+ART+'\n</script>')
    (OUT/'offline-preview.html').write_text(html, encoding='utf-8')
    (OUT/'widget-trees.json').write_text(json.dumps(frames, ensure_ascii=False), encoding='utf-8')
    print(OUT/'offline-preview.html')
