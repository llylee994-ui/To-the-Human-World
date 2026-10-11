"""Offline replay of actual HomeView NanoVG calls and AppView state, NOT native capture."""
from pathlib import Path
import hashlib
import json
import math
import sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'docs/验证/evidence/home-zoom-r1'
sys.path.insert(0, str(ROOT / 'scripts/debug'))
import run_b1
from content_test_runtime import run
from lupa.lua54 import lua_type
from PIL import Image, ImageDraw, ImageFont

def native(value):
    if lua_type(value) != 'table': return value
    keys = list(value.keys())
    if keys and set(keys) == set(range(1, len(keys)+1)):
        return [native(value[i]) for i in range(1,len(keys)+1)]
    return {str(k):native(value[k]) for k in keys}

frames=[]
original=run_b1.LuaRuntime
def runtime(*args, **kwargs):
    lua=original(*args, **kwargs)
    lua.execute('''
        local calls={}
        for _,name in ipairs({"nvgSave","nvgRestore","nvgTranslate","nvgRotate","nvgScale","nvgBeginPath","nvgRect","nvgFillColor","nvgFill","nvgFillPaint","nvgIntersectScissor"}) do
            _G[name]=function(_,...) calls[#calls+1]={name,...} end
        end
        nvgRGBA=function(...) return {...} end
        nvgImagePattern=function(_,x,y,w,h,angle,handle,alpha) return {x=x,y=y,w=w,h=h,path=IMAGE_PATHS[handle],alpha=alpha} end
        IMAGE_PATHS={}
        package.loaded["urhox-libs/UI/Core/ImageCache"]={Get=function(path)
            for i,p in ipairs(IMAGE_PATHS) do if p==path then return i end end
            IMAGE_PATHS[#IMAGE_PATHS+1]=path;return #IMAGE_PATHS
        end}
        ZOOM_DRAW_TRACE=function(view)
            calls={};view.home.art:Render(nil);return calls
        end
    ''')
    def capture(name,t,view,snapshot):
        texts=[]
        def walk(widget):
            if widget.props.visible is False: return
            text=widget.props.text
            if text: texts.append(text)
            for child in widget.children.values(): walk(child)
        walk(view.root)
        frames.append(dict(name=name,simulatedTime=t,scene=view.scene,scale=view.home.zoom,
            fit=native(view.home.Fit()),rootBounds=native(view.root.GetAbsoluteLayout(view.root)),
            uiTexts=texts,stateSha256=hashlib.sha256(json.dumps(native(snapshot),sort_keys=True).encode()).hexdigest(),
            drawCalls=native(lua.globals().ZOOM_DRAW_TRACE(view))))
    lua.globals().HOME_ZOOM_EVIDENCE=capture
    return lua

def mul(m,n):
    a,b,c,d,e,f=m;g,h,i,j,k,l=n
    return (a*g+c*h,b*g+d*h,a*i+c*j,b*i+d*j,a*k+c*l+e,b*k+d*l+f)

def inverse(m):
    a,b,c,d,e,f=m;det=a*d-b*c
    return d/det,-c/det,(c*f-d*e)/det,-b/det,a/det,(b*e-a*f)/det

font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
small=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',14)
assets={}
def replay(frame):
    width,height=round(frame['rootBounds']['w']),round(frame['rootBounds']['h'])
    canvas=Image.new('RGBA',(width,height),(48,42,34,255))
    fit=frame['fit']
    if frame['scene']=='home':
        m=(1,0,0,1,0,0);stack=[];paint=None;color=(245,240,231,255)
        room=Image.new('RGBA',canvas.size,(0,0,0,0))
        ImageDraw.Draw(room).rectangle((fit['x'],fit['y'],fit['x']+fit['w'],fit['y']+fit['h']),fill=color)
        for call in frame['drawCalls']:
            name,*v=call
            if name=='nvgSave': stack.append(m)
            elif name=='nvgRestore': m=stack.pop()
            elif name=='nvgTranslate': m=mul(m,(1,0,0,1,v[0],v[1]))
            elif name=='nvgScale': m=mul(m,(v[0],0,0,v[1],0,0))
            elif name=='nvgRotate':
                c,s=math.cos(v[0]),math.sin(v[0]);m=mul(m,(c,s,-s,c,0,0))
            elif name=='nvgFillPaint': paint=v[0]
            elif name=='nvgFillColor': paint=None
            elif name=='nvgFill' and paint:
                path=paint['path']
                if path not in assets: assets[path]=Image.open(ROOT/'assets'/path).convert('RGBA')
                src=assets[path]
                matrix=mul(m,(paint['w']/src.width,0,0,paint['h']/src.height,paint['x'],paint['y']))
                placed=src.transform(canvas.size,Image.Transform.AFFINE,inverse(matrix),Image.Resampling.BICUBIC)
                room.alpha_composite(placed)
        crop=(round(fit['x']),round(fit['y']),round(fit['x']+fit['w']),round(fit['y']+fit['h']))
        canvas.paste(room.crop(crop),crop)
        draw=ImageDraw.Draw(canvas);draw.rectangle((0,0,width,47),fill=(40,42,33,255))
        draw.text((12,9),frame['uiTexts'][0],font=font,fill='white')
        draw.text((width-115,9),'结束当天',font=font,fill='white')
    else:
        draw=ImageDraw.Draw(canvas)
        draw.rectangle((0,48,width,height-36),fill=(238,228,203,255))
        draw.text((18,8),'OFFLINE UI TEXT SNAPSHOT (not a rendered game screenshot)',font=small,fill='white')
        for i,text in enumerate(frame['uiTexts']):
            draw.text((28,65+i*40),text,font=font,fill=(50,43,34,255))
    result=Image.new('RGB',(width,height+42),(30,35,40))
    result.paste(canvas.convert('RGB'),(0,42))
    ImageDraw.Draw(result).text((12,9),f"OFFLINE REPLAY | {frame['name']} | simulated t={frame['simulatedTime']:.4f}s | zoom={frame['scale']:.5f}",font=small,fill='white')
    return result

if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    run_b1.LuaRuntime=runtime
    result=run('ui.landscape.tests.HomeZoomTest')
    if result: raise SystemExit(result)
    assert len(frames)==20
    assert len({f['stateSha256'] for f in frames})==1
    for frame in frames:
        if frame['scene']=='home':
            assert sum(c[0]=='nvgFillPaint' for c in frame['drawCalls'])==11
            assert not any(c[0] in ('nvgStroke','nvgText') for c in frame['drawCalls'])
        output=OUT/('offline-'+frame['name']+'.png')
        replay(frame).save(output)
        frame['image']=output.name
        frame['imageSha256']=hashlib.sha256(output.read_bytes()).hexdigest()
    (OUT/'offline-timeline.json').write_text(json.dumps(dict(
        evidenceType='OFFLINE: real Lua state and HomeView NVG calls; simulated time/focus/layout; Pillow replay; not native or smoothness evidence',
        sourceSha256={str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest()
            for p in [ROOT/'scripts/ui/landscape'/name for name in ('HomeView.lua','AppView.lua','HomeZoom.lua')]},
        frames=frames),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for width in (1280,1560,1600,1024):
        group=[f for f in frames if f['name'].startswith(str(width)+'-')]
        thumbs=[]
        for f in group:
            img=Image.open(OUT/f['image']);img.thumbnail((640,440));thumbs.append(img)
        sheet=Image.new('RGB',(640*len(thumbs),max(i.height for i in thumbs)),(30,35,40))
        for i,img in enumerate(thumbs): sheet.paste(img,(i*640,0))
        sheet.save(OUT/f'offline-sequence-{width}.png')
    print('PASS: 20 OFFLINE frames and 4 contact sheets; actual Lua state/draw-call snapshots; NOT native playback evidence')
