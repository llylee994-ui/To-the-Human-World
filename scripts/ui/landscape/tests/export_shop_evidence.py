"""Export actual ShopView props to a labelled offline CSS replay. No game launch."""
from pathlib import Path
import json
import sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'docs/验证/evidence' / (sys.argv[1] if len(sys.argv)>1 else 'shop-counter-r1')
sys.path.insert(0, str(ROOT / 'scripts/debug'))
import run_b1
from content_test_runtime import run
from lupa.lua54 import lua_type

frames = []
original = run_b1.LuaRuntime

def native(value):
    kind = lua_type(value)
    if kind == 'table':
        keys = list(value.keys())
        if keys and set(keys) == set(range(1, len(keys) + 1)):
            return [native(value[i]) for i in range(1, len(keys) + 1)]
        return {str(k): native(value[k]) for k in keys if lua_type(value[k]) != 'function' and str(k) != 'children'}
    return value

def tree(widget):
    props = native(widget.props)
    if props.get('backgroundImage'):
        props['backgroundImage'] = (ROOT / 'assets' / props['backgroundImage']).as_uri()
    return dict(props=props, children=[tree(child) for child in widget.children.values()])

def runtime(*args, **kwargs):
    lua = original(*args, **kwargs)
    lua.globals().TRAVEL_TICKET_EVIDENCE = len(sys.argv)>1 and sys.argv[1]=='shop-ticket-r1'
    lua.globals().SHOP_EVIDENCE = lambda w,h,scale,item,root: frames.append(dict(width=w,height=h,scale=scale,selected=item,tree=tree(root)))
    return lua

HTML = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>商队木柜台 · 离线排版预览</title>
<style>*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#352719;font-family:"Microsoft YaHei",sans-serif}#stage{position:absolute;left:0;top:0;transform-origin:0 0}.widget{display:flex;flex-direction:column;flex-shrink:0;position:relative;min-width:0}.label{white-space:nowrap}.offline{position:fixed;bottom:2px;left:4px;font:10px sans-serif;color:#fff;background:#222a;padding:2px 5px;pointer-events:none;z-index:9999}</style>
<div id="stage"></div><div class="offline">OFFLINE · 实际 Lua 控件树的 CSS 重放 · 非引擎/手机截图</div>
<script>
const frames=FRAMES;
const stage=document.querySelector('#stage');
function color(a){return Array.isArray(a)?`rgba(${a[0]},${a[1]},${a[2]},${(a[3]??255)/255})`:a;}
function length(x){return typeof x==='number'?x+'px':x;}
function edges(a){if(typeof a==='number')return a+'px';if(Array.isArray(a))return a.map(length).join(' ');return '0';}
function render(node){
 const p=node.props,el=document.createElement('div');el.className='widget'+(p.text!==undefined?' label':'');
 if(p.id)el.id=p.id;const s=el.style;
 for(const key of ['width','height','minWidth','maxWidth','minHeight','maxHeight','left','right','top','bottom','borderRadius','gap','marginTop','paddingTop','paddingRight','paddingLeft','paddingBottom'])if(p[key]!==undefined)s[key]=length(p[key]);
 for(const key of ['flexDirection','justifyContent','alignItems','alignSelf','position','overflow','whiteSpace','textAlign'])if(p[key]!==undefined)s[key]=p[key];
 for(const key of ['flexGrow','flexShrink','flexBasis'])if(p[key]!==undefined)s[key]=typeof p[key]==='number'?String(p[key]):p[key];
 if(p.padding!==undefined)s.padding=edges(p.padding);if(p.margin!==undefined)s.margin=edges(p.margin);
 if(p.paddingHorizontal!==undefined){s.paddingLeft=length(p.paddingHorizontal);s.paddingRight=length(p.paddingHorizontal);}
 if(p.borderWidth){s.borderWidth=length(p.borderWidth);s.borderStyle='solid';s.borderColor=color(p.borderColor);}
 if(p.backgroundColor)s.backgroundColor=color(p.backgroundColor);
 if(p.backgroundGradient?.from)s.backgroundImage=`linear-gradient(to bottom,${color(p.backgroundGradient.from)},${color(p.backgroundGradient.to)})`;
 if(p.backgroundImage){s.backgroundImage=`url("${p.backgroundImage}")`;s.backgroundSize=p.backgroundFit==='fill'?'100% 100%':p.backgroundFit||'cover';s.backgroundPosition='center';s.backgroundRepeat='no-repeat';}
 if(p.fontSize)s.fontSize=length(p.fontSize);if(p.lineHeight)s.lineHeight=p.lineHeight;
 s.color=color(p.textColor||p.fontColor||[65,46,28,255]);if(p.text!==undefined){el.textContent=p.text;s.flexShrink=0;}
 if(p.id?.startsWith('buy_')||p.id==='closePanel'){s.justifyContent='center';s.alignItems='center';s.cursor='pointer';}
 if(p.disabled){s.backgroundImage='none';s.backgroundColor=color(p.disabledBackgroundColor);s.color=color(p.disabledTextColor);}
 if(p.visible===false)s.display='none';
 if(p.id?.endsWith('Scroll')){s.overflowY='auto';s.overflowX='hidden';s.flexShrink=1;}
 if(p.id?.startsWith('shop_select_'))el.onclick=()=>draw(p.id.slice('shop_select_'.length));
 if(p.id==='closePanel')el.onclick=()=>{};
 for(const child of node.children)el.appendChild(render(child));return el;
}
let chosen='ing_sea_salt';function draw(selected=chosen){chosen=selected;const candidates=frames.filter(f=>f.selected===chosen);const f=candidates.reduce((a,b)=>Math.abs(b.width-innerWidth)+Math.abs(b.height-innerHeight)<Math.abs(a.width-innerWidth)+Math.abs(a.height-innerHeight)?b:a);stage.style.width=f.width/f.scale+'px';stage.style.height=f.height/f.scale+'px';stage.style.transform=`scale(${f.scale})`;stage.replaceChildren(render(f.tree));}
draw();window.addEventListener('resize',()=>draw());window.SHOP_PREVIEW={draw};
</script></html>'''

if __name__ == '__main__':
    run_b1.LuaRuntime = runtime
    if run('ui.landscape.tests.ShopEvidenceHost'):
        raise SystemExit(1)
    OUT.mkdir(parents=True, exist_ok=True)
    raw = json.dumps(frames, ensure_ascii=False)
    (OUT / 'widget-trees.json').write_text(raw, encoding='utf-8')
    (OUT / 'offline-preview.html').write_text(HTML.replace('FRAMES',raw.replace('</','<\\/')), encoding='utf-8')
    print(OUT / 'offline-preview.html')
