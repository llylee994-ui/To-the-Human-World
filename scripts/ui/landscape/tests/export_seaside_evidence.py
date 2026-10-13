"""Replay actual seaside NanoVG calls; offline art + simplified UI, NOT native QA."""
from pathlib import Path
import hashlib
import json
import math
import sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'docs/验证/evidence/seaside-r1'
sys.path.insert(0, str(ROOT / 'scripts/debug'))
import run_b1
from content_test_runtime import run
from lupa.lua54 import lua_type
from PIL import Image, ImageDraw, ImageFont

frames = []
original = run_b1.LuaRuntime

def native(value):
    if lua_type(value) != 'table':
        return value
    keys = list(value.keys())
    if keys and set(keys) == set(range(1, len(keys) + 1)):
        return [native(value[i]) for i in range(1, len(keys) + 1)]
    return {str(k): native(value[k]) for k in keys}

def runtime(*args, **kwargs):
    lua = original(*args, **kwargs)
    lua.execute('''
        package.loaded["ui.landscape.DevChecks"]={hotspots=false,nativeProbe=false,hitFeedback=false,seasideProbe=false}
        local calls={}
        for _,name in ipairs({"nvgSave","nvgRestore","nvgTranslate","nvgRotate","nvgScale","nvgBeginPath","nvgRect","nvgEllipse","nvgCircle","nvgFillColor","nvgFill","nvgFillPaint","nvgIntersectScissor","nvgStrokeColor","nvgStrokeWidth","nvgStroke"}) do
            _G[name]=function(_,...) calls[#calls+1]={name,...} end
        end
        nvgRGBA=function(...) return {...} end
        IMAGE_PATHS={}
        nvgImagePattern=function(_,x,y,w,h,angle,handle,alpha) return {x=x,y=y,w=w,h=h,path=IMAGE_PATHS[handle],alpha=alpha} end
        package.loaded["urhox-libs/UI/Core/ImageCache"]={Get=function(path)
            for i,p in ipairs(IMAGE_PATHS) do if p==path then return i end end
            IMAGE_PATHS[#IMAGE_PATHS+1]=path;return #IMAGE_PATHS
        end}
        SEASIDE_DRAW_TRACE=function(view) calls={};view.seaside.background:Render(nil);view.seaside.art:Render(nil);return calls end
    ''')
    def capture(width, height, name, t, view, snapshot):
        controls = {}
        for key in ['playLedger', 'startSalvage', 'readCapturedLetter', 'seasideShop', 'salvageStatus', 'playMessage', 'skipSalvage']:
            widget = view.root.FindById(view.root, key)
            controls[key] = {name:native(widget.props[name]) for name in ['text','visible','disabled','width'] if widget.props[name] is not None}
        state = native(snapshot)
        frames.append(dict(width=width, height=height, name=name, time=t, scene=view.scene, panel=view.panel,
            fit=native(view.seaside.Fit()), rootBounds=native(view.root.GetAbsoluteLayout(view.root)),
            pose=native(view.salvage.Pose()), active=view.salvage.active, controls=controls,
            receivedCount=len(state['live']['letters']['byId']), usedToday=state['live']['gameFlow']['salvageUsedToday'],
            stateSha256=hashlib.sha256(json.dumps(state, sort_keys=True).encode()).hexdigest(),
            drawCalls=native(lua.globals().SEASIDE_DRAW_TRACE(view))))
    lua.globals().SEASIDE_EVIDENCE = capture
    return lua

def mul(m, n):
    a,b,c,d,e,f=m;g,h,i,j,k,l=n
    return (a*g+c*h,b*g+d*h,a*i+c*j,b*i+d*j,a*k+c*l+e,b*k+d*l+f)

def inverse(m):
    a,b,c,d,e,f=m;det=a*d-b*c
    return (d/det,-c/det,(c*f-d*e)/det,-b/det,a/det,(b*e-a*f)/det)

font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 16)
small = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 12)
assets = {}

def replay(frame):
    width,height=round(frame['rootBounds']['w']),round(frame['rootBounds']['h'])
    canvas=Image.new('RGBA',(width,height),(32,60,72,255))
    art=Image.new('RGBA',canvas.size)
    m=(1,0,0,1,0,0);stack=[];paint=None;color=(255,255,255,255);stroke=color;shape=None;line=1
    def point(x,y):
        a,b,c,d,e,f=m
        return a*x+c*y+e,b*x+d*y+f
    for call in frame['drawCalls']:
        name,*v=call
        if name=='nvgSave': stack.append(m)
        elif name=='nvgRestore': m=stack.pop()
        elif name=='nvgTranslate': m=mul(m,(1,0,0,1,v[0],v[1]))
        elif name=='nvgScale': m=mul(m,(v[0],0,0,v[1],0,0))
        elif name=='nvgRotate':
            c,s=math.cos(v[0]),math.sin(v[0]);m=mul(m,(c,s,-s,c,0,0))
        elif name=='nvgFillPaint': paint=v[0]
        elif name=='nvgFillColor': color=tuple(round(n) for n in v[0]);paint=None
        elif name=='nvgStrokeColor': stroke=tuple(round(n) for n in v[0])
        elif name=='nvgStrokeWidth': line=max(1,round(v[0]*math.hypot(m[0],m[1])))
        elif name=='nvgEllipse' or name=='nvgCircle':
            x,y=point(v[0],v[1]);rx=v[2]*math.hypot(m[0],m[1]);ry=(v[3] if name=='nvgEllipse' else v[2])*math.hypot(m[2],m[3])
            shape=(x-rx,y-ry,x+rx,y+ry)
        elif name=='nvgFill' and paint:
            path=paint['path']
            if path not in assets: assets[path]=Image.open(ROOT/'assets'/path).convert('RGBA')
            src=assets[path]
            transform=mul(m,(paint['w']/src.width,0,0,paint['h']/src.height,paint['x'],paint['y']))
            layer=src.transform(canvas.size,Image.Transform.AFFINE,inverse(transform),Image.Resampling.BICUBIC)
            if paint['alpha']<1: layer.putalpha(layer.getchannel('A').point(lambda a:round(a*paint['alpha'])))
            art.alpha_composite(layer)
        elif name in ('nvgFill','nvgStroke') and shape:
            overlay=Image.new('RGBA',canvas.size)
            draw=ImageDraw.Draw(overlay)
            if name=='nvgFill': draw.ellipse(shape,fill=color)
            else: draw.ellipse(shape,outline=stroke,width=line)
            art.alpha_composite(overlay)
    clip=Image.new('L',canvas.size,255)
    canvas.paste(art,(0,0),clip)
    draw=ImageDraw.Draw(canvas)
    draw.rectangle((0,0,width,48),fill=(40,42,33,255))
    draw.text((14,13),frame['controls']['playLedger']['text'],font=font,fill='#ffefd0')
    draw.text((width-236,13),'返回主页',font=font,fill='#dbe5d7')
    draw.text((width-114,13),'结束当天',font=font,fill='#dbe5d7')
    draw.rectangle((0,height-112,width,height),fill=(32,49,49,255))
    draw.text((14,height-99),'海边 · 木码头',font=font,fill='#f9e7c5')
    draw.text((14,height-73),frame['controls']['salvageStatus'].get('text',''),font=small,fill='#c9dedd')
    key='readCapturedLetter' if frame['controls']['readCapturedLetter'].get('visible') else 'startSalvage'
    props=frame['controls'][key]
    for box,text in [((width-148-props['width'],height-98,width-148,height-50),props['text']),((width-136,height-98,width-14,height-50),'商队商店')]:
        draw.rounded_rectangle(box,8,fill='#8f774b' if props.get('disabled') else '#bc934d')
        draw.text((box[0]+10,box[1]+15),text,font=small,fill='#222921')
    if frame['active']:
        draw.rounded_rectangle((width-130,height-94,width-14,height-46),8,fill='#43564f')
        draw.text((width-114,height-79),'跳过演出',font=small,fill='white')
    draw.text((14,height-28),frame['controls']['playMessage'].get('text',''),font=small,fill='#ffe5b3')
    draw.rectangle((8,53,492,81),fill=(15,25,33,238))
    draw.text((15,59),'OFFLINE · 实际 Lua 图层重放 / UI 简化示意 · '+frame['name'],font=small,fill='#ffffff')
    return canvas.convert('RGB').resize((frame['width'],frame['height']),Image.Resampling.LANCZOS)

if __name__ == '__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    run_b1.LuaRuntime=runtime
    try:
        if run('ui.landscape.tests.SeasideEvidenceHost') != 0: raise SystemExit(1)
    finally: run_b1.LuaRuntime=original
    for frame in frames:
        if frame['name']=='idle' or frame['width']==1280:
            replay(frame).save(OUT/f"offline-{frame['width']}-{frame['name']}.png")
    overview=Image.new('RGB',(1920,720),'#18343e')
    for i,name in enumerate(['idle','lowering','net-in-water','lifting','reveal','bottle-closeup']):
        frame=next(f for f in frames if f['width']==1280 and f['name']==name)
        overview.paste(replay(frame).resize((640,360)),((i%3)*640,(i//3)*360))
    overview.save(OUT/'offline-sequence.png')
    (OUT/'offline-timeline.json').write_text(json.dumps(dict(evidence='offline actual Lua drawing; NOT native, UI simplified',frames=frames),ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'[SeasideEvidence] {len(frames)} recorded frames across five aspect/size projections; OFFLINE only')
