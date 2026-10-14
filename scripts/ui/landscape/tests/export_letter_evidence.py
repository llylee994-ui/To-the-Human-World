"""Export real Lua geometry + actual font metrics to a labelled HTML replay."""
from pathlib import Path
import sys, json
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'docs/验证/evidence/letter-presentation-r1'
sys.path.insert(0, str(ROOT / 'scripts/debug'))
from PIL import ImageFont
import run_b1
from content_test_runtime import run
from export_shop_evidence import native

frames = []
fonts = {}
original = run_b1.LuaRuntime
def runtime(*args, **kwargs):
    lua = original(*args, **kwargs)
    def measure(text, size, face):
        assert face == 'story'
        key = round(size)
        font = fonts.setdefault(key, ImageFont.truetype(str(ROOT/'assets/fonts/HarborHand-Regular.ttf'), key))
        return float(font.getlength(text))
    def capture(w,h,label,definition,view,layout,frame,clip,paper,holes,pose,size,line):
        frames.append(dict(width=w,height=h,label=label,definition=native(definition),view=native(view),layout=native(layout),
                           frame=native(frame),clip=native(clip),paper=native(paper),holes=native(holes) or [],pose=native(pose),fontSize=size,lineHeight=line))
    lua.globals().LETTER_FONT_WIDTH = measure
    lua.globals().LETTER_EVIDENCE = capture
    return lua

HTML = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>信纸剪词 · 离线过程检查</title>
<style>@font-face{font-family:story;src:url('FONT')}*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#302a23;font-family:story;color:#3e3124}#stage{position:absolute;inset:0}.art{position:absolute;width:100%;height:100%;object-fit:cover;filter:brightness(.42)}.paper{position:absolute;pointer-events:none}.label,.run{position:absolute;white-space:pre}.run.word{border-bottom:1px dashed #785b3b77}.hole{border:1px solid #76593899;box-shadow:inset 0 2px 2px #20170d88}.strip{position:absolute;background:url('PAPER') center/100% 100%;box-shadow:2px 3px 5px #20170d44;text-align:center;clip-path:polygon(2% 0,20% 2%,40% 0,60% 2%,80% 0,98% 2%,100% 95%,80% 100%,60% 97%,40% 100%,20% 97%,0 95%)}#controls{position:fixed;bottom:0;left:0;right:0;z-index:20;background:#211a13e8;color:#fff;font:12px sans-serif;padding:5px 10px}button{margin-left:8px}svg{position:absolute;inset:0;pointer-events:none}</style>
<div id="stage"></div><div id="controls">OFFLINE · 真实 Lua 排版/时序 + 模拟字体测量与布局 · 非引擎/手机截图 <button onclick="draw('before')">剪前</button><button onclick="draw('snip')">剪刀</button><button onclick="draw('flight')">收取</button><button onclick="draw('after')">剪后</button></div>
<script>const frames=FRAMES;const stage=document.querySelector('#stage');let chosen='before';
function box(e,r){Object.assign(e.style,{left:r.x+'px',top:r.y+'px',width:r.w+'px',height:r.h+'px'});return e}
function label(text,x,y,size){const e=document.createElement('div');e.className='label';e.textContent=text;Object.assign(e.style,{left:x+'px',top:y+'px',fontSize:size+'px'});stage.appendChild(e)}
function draw(kind=chosen){chosen=kind;const candidates=frames.filter(f=>f.label===kind);const f=candidates.reduce((a,b)=>Math.abs(b.width-innerWidth)+Math.abs(b.height-innerHeight)<Math.abs(a.width-innerWidth)+Math.abs(a.height-innerHeight)?b:a);stage.replaceChildren();
 const art=document.createElement('img');art.className='art';art.src='HOME';stage.appendChild(art);
 const ns='http://www.w3.org/2000/svg';const svg=document.createElementNS(ns,'svg');svg.setAttribute('width',f.width);svg.setAttribute('height',f.height);const mask=document.createElementNS(ns,'mask');mask.id='cuts';mask.setAttribute('maskUnits','userSpaceOnUse');
 const rect=(r,color)=>{const e=document.createElementNS(ns,'rect');for(const [key,v] of Object.entries({x:r.x,y:r.y,width:r.w,height:r.h,fill:color}))e.setAttribute(key,v);return e};mask.appendChild(rect({x:0,y:0,w:f.width,h:f.height},'white'));for(const h of f.holes){const x=Math.max(h.x,f.clip.x),y=Math.max(h.y,f.clip.y),right=Math.min(h.x+h.w,f.clip.x+f.clip.w),bottom=Math.min(h.y+h.h,f.clip.y+f.clip.h);if(right>x&&bottom>y)mask.appendChild(rect({x,y,w:right-x,h:bottom-y},'black'))}svg.appendChild(mask);
 const foreign=document.createElementNS(ns,'foreignObject');for(const [key,v] of Object.entries({x:f.frame.x,y:f.frame.y,width:f.frame.w,height:f.frame.h,mask:'url(#cuts)'}))foreign.setAttribute(key,v);const bg=document.createElement('div');bg.style.cssText='width:100%;height:100%;border:32px solid transparent;border-image:url("PAPER") 32 fill stretch;';foreign.appendChild(bg);svg.appendChild(foreign);stage.appendChild(svg);
 label('阅读信件',f.frame.x+48,f.frame.y+35,22);label('返回',f.frame.x+f.frame.w-100,f.frame.y+35,20);
 const content=document.createElement('div');content.style.cssText='position:absolute;overflow:hidden';box(content,f.clip);stage.appendChild(content);
 function text(t,x,y,size){const e=document.createElement('div');e.className='label';e.textContent=t;Object.assign(e.style,{left:x-f.clip.x+'px',top:y-f.clip.y+'px',fontSize:size+'px'});content.appendChild(e)}
 text(f.definition.title,f.paper.x,f.clip.y+10,30);text(f.view.selfIntro,f.paper.x,f.clip.y+53,21);
 for(const r of f.layout.runs){const e=document.createElement('div');e.className='run'+(r.spanId?' word':'');Object.assign(e.style,{left:f.paper.x+4+r.x-f.clip.x+'px',top:f.paper.y+4+r.y-f.clip.y+'px',width:r.w+'px',height:r.h+'px',fontSize:f.fontSize+'px'});if(r.cut){e.className='run hole';e.style.top=f.paper.y+6+r.y-f.clip.y+'px';e.style.height=r.h-5+'px'}else{e.textContent=r.text;if(r.spanId)e.style.paddingLeft='3px'}content.appendChild(e)}
 label('词条托盘',f.frame.x+f.frame.w-145,f.frame.y+f.frame.h-52,17);
 if(f.pose){const p=f.pose,e=box(document.createElement('div'),p);e.className='strip';e.textContent=p.text;Object.assign(e.style,{fontSize:f.fontSize+'px',lineHeight:p.h+'px',opacity:p.opacity,transform:`rotate(${p.angle}rad) scale(${p.scale})`});stage.appendChild(e);if(p.phase==='snip'){const sc=document.createElement('img');sc.src='SCISSORS';sc.style.cssText=`position:absolute;left:${p.x+p.w*p.snip-22}px;top:${p.y-35}px;width:112px;transform:rotate(.6rad)`;stage.appendChild(sc)}}
 window.FRAME=f;}window.LETTER_PREVIEW={draw};draw();</script></html>'''

if __name__ == '__main__':
    run_b1.LuaRuntime = runtime
    if run('ui.landscape.tests.LetterEvidenceHost'):
        raise SystemExit(1)
    OUT.mkdir(parents=True, exist_ok=True)
    html = HTML.replace('FRAMES',json.dumps(frames,ensure_ascii=False).replace('</','<\\/'))
    for key,value in {'FONT':ROOT/'assets/fonts/HarborHand-Regular.ttf','PAPER':ROOT/'assets/image/界面_柔边纸面_透明_v01_20261013070534.png',
                      'SCISSORS':ROOT/'assets/image/letter-scissors.png','HOME':ROOT/'docs/验证/evidence/home-entry-r3/native-home.png'}.items():
        html=html.replace(key,value.as_uri())
    (OUT/'offline-preview.html').write_text(html,encoding='utf-8')
    (OUT/'frames.json').write_text(json.dumps(frames,ensure_ascii=False,indent=2),encoding='utf-8')
    print(OUT/'offline-preview.html')
