"""Offline composition using real LetterDrawerArt.Fit/specs; NOT native Yoga or device evidence."""
from pathlib import Path
import sys, math
ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'.tmp/b1-python'))
from lupa.lua54 import LuaRuntime
from PIL import Image,ImageDraw,ImageFont
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path=... .. '/scripts/?.lua;'..package.path;package.preload['urhox-libs/UI']=function() return {} end",ROOT.as_posix())
art=lua.eval("require('ui.landscape.LetterDrawerArt')")[0]
content=lua.eval("require('data.content')")[0]
letters=content.letters
npcs=content.npcs
names={row['id']:row['name'] for _,row in npcs.items()}
rows=[r for _,r in letters.items() if r['kind']=='order'][:8]
out=ROOT/'.tmp/letter-drawer-art-preview'
out.mkdir(parents=True,exist_ok=True)
fontpath=str(ROOT/'assets/fonts/HarborHand-Regular.ttf')
def font(size): return ImageFont.truetype(fontpath,max(9,round(size)))
def render(w,h):
    canvas=Image.open(ROOT/'assets/image/home-entry-r3/background.png').convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
    canvas.alpha_composite(Image.new('RGBA',(w,h),(15,14,12,170)))
    size=math.floor(min(w-24,h*.94)); left=(w-size)/2
    layout=art.Fit(size,size)
    def paint(target,key,r,stretch=False,offset=(0,0)):
        spec=art.Specs[key];b=[int(spec['bounds'][i]) for i in range(1,5)]
        im=Image.open(ROOT/'assets'/art.Images[key]).convert('RGBA').crop(b)
        rw,rh=max(1,round(r['w'])),max(1,round(r['h']))
        if stretch: dw,dh=rw,rh
        else:
            scale=min(rw/im.width,rh/im.height);dw,dh=max(1,round(im.width*scale)),max(1,round(im.height*scale))
        x=round(r['x']+(rw-dw)/2+offset[0]);y=round(r['y']+(rh-dh)/2+offset[1])
        target.alpha_composite(im.resize((dw,dh),Image.Resampling.LANCZOS),(x,y))
        return x,y,dw,dh
    paint(canvas,'body',layout.body,offset=(left,0))
    for k in ['parcel','scrolls','plate']:paint(canvas,k,layout[k],offset=(left,0))
    def center(value,r,fs,color=(65,47,32,255)):
        draw=ImageDraw.Draw(canvas);f=font(fs);bb=draw.textbbox((0,0),value,font=f)
        draw.text((left+r['x']+(r['w']-(bb[2]-bb[0]))/2,r['y']+(r['h']-(bb[3]-bb[1]))/2-bb[1]),value,font=f,fill=color)
    center('来信抽屉',layout.plate,14 if size<460 else 17)
    for k in ['close','back']:
        r=layout[k];paint(canvas,k,{'x':r['x'],'y':r['y'],'w':max(44,r['w']),'h':max(44,r['h'])},offset=(left,0))
    hint=layout.hint;draw=ImageDraw.Draw(canvas)
    draw.text((left+hint['x']+8,hint['y']+4),'已收 '+str(len(rows))+' 封来信 · 点击信纸阅读',font=font(13),fill=(244,224,188,255))
    area=layout.cards
    cards=Image.new('RGBA',(max(1,round(area['w'])),max(1,round(area['h']))))
    columns=int(layout.card.columns);cw,ch=layout.card.w,layout.card.h
    for i,row in enumerate(rows):
        col=i%columns;rr=i//columns
        x,y=col*(cw+layout.card.gap),rr*layout.card.rowStep
        if y>=area['h']:break
        paper=Image.new('RGBA',(math.ceil(cw),math.ceil(ch)))
        _,py,pw,ph=paint(paper,'unread' if i<2 else 'read',{'x':0,'y':0,'w':cw,'h':ch})
        d=ImageDraw.Draw(paper);tf=font(12 if cw<190 else 14)
        title=row['title'];maxw=pw*.72;line='';lines=[]
        for char in title:
            if d.textlength(line+char,font=tf)>maxw and line:lines.append(line);line=char
            else:line+=char
        if line:lines.append(line)
        for n,line in enumerate(lines[:2]):d.text((pw*.07,py+ph*.10+n*tf.size*1.12),line,font=tf,fill=(65,47,32,255))
        d.text((pw*.07,py+ph*.69),names.get(row['senderId'],'寄信人'),font=font(11),fill=(116,89,63,255))
        label='未读' if i<2 else '可剪 2 处' if i%2 else '已读'
        sf=font(10);d.text((pw*.78-d.textlength(label,font=sf),py+ph*.69),label,font=sf,fill=(116,89,63,255))
        cards.alpha_composite(paper,(round(x),round(y)))
    canvas.alpha_composite(cards,(round(left+area['x']),round(area['y'])))
    paint(canvas,'track',layout.rail,True,(left,0))
    content=max(area['h'],math.ceil(len(rows)/columns)*layout.card.rowStep)
    if content>area['h']:
        th=max(24,layout.rail.h*area['h']/content)
        paint(canvas,'thumb',{'x':layout.rail.x+2,'y':layout.rail.y+3,'w':max(4,layout.rail.w-4),'h':max(8,th-6)},True,(left,0))
    label='OFFLINE / 离线布局预览 · 示例来信 · 非引擎截图'
    draw=ImageDraw.Draw(canvas);draw.rectangle((0,h-26,w,h),fill=(24,23,20,255))
    draw.text((10,h-24),label,font=font(13),fill=(255,239,209,255))
    path=out/('drawer-'+str(w)+'x'+str(h)+'-offline.png');canvas.save(path)
    print(path)
for size in [(1280,720),(800,450)]:render(*size)
