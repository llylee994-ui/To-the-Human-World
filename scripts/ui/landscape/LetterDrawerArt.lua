-- 方形俯视抽屉。原稿不改像素，可见边界用于去掉透明留白。
local UI=require "urhox-libs/UI"
local reference=require "ui.landscape.LetterDrawerLayout"
local A={Images={},Specs={}}
local prefix="image/letter-drawer-v01/界面_来信抽屉_"
local function asset(key,name,w,h,bounds)
    A.Images[key]=prefix..name.."_透明_v01.png"
    A.Specs[key]={w=w,h=h,bounds=bounds}
end
asset("body","抽屉体_俯视方形_带拉手",1254,1254,{0,0,1254,1254})
asset("read","信纸_已读",2172,724,{43,106,2130,627})
asset("unread","信纸_未读",2172,724,{29,116,2140,627})
asset("plate","标题牌",2172,724,{25,204,2147,497})
asset("close","关闭_铜叉",1254,1254,{106,114,1149,1126})
asset("back","返回_铜箭头",1448,1086,{68,213,1381,846})
asset("track","滚动条_轨道",887,1774,{347,23,540,1753})
asset("thumb","滚动条_滑块",724,2172,{198,99,525,2063})
asset("scrolls","装饰_卷轴束",793,1983,{120,93,757,1906})
asset("parcel","装饰_绳捆包裹",1122,1402,{102,139,1023,1267})
A.Colors={ink={65,47,32,255},muted={116,89,63,255},light={244,224,188,255}}
-- Replay full, unmodified editor images, rotating around their original centers.
function A.Reference(parent,id,key,layout,origin)
    local layer=assert(reference.layers[key])
    local scale=layout.scale
    local node=UI.Panel {id=id,position="absolute",
        left=layout.x+(layer.x-layer.width/2)*scale-(origin and origin.x or 0),
        top=layout.y+(layer.y-layer.height/2)*scale-(origin and origin.y or 0),
        width=layer.width*scale,height=layer.height*scale,rotate=layer.rotation,transformOrigin="center",
        pointerEvents="none",zIndex=key=="body" and 0 or 1}
    node:AddChild(UI.Panel {id=id.."_image",position="absolute",left=0,top=0,width="100%",height="100%",
        backgroundImage=layer.path,backgroundFit="fill",pointerEvents="none"})
    parent:AddChild(node)
    return node
end
-- r 为主体区域。仅滚动轨道/滑块允许纵向拉伸；其它素材保持比例。
function A.Image(parent,id,key,r,stretch,opacity)
    local spec=assert(A.Specs[key]);local b=spec.bounds
    local bw,bh=b[3]-b[1],b[4]-b[2]
    local sx,sy=r.w/bw,r.h/bh
    if not stretch then local scale=math.min(sx,sy);sx,sy=scale,scale end
    local x,y=(r.w-bw*sx)/2,(r.h-bh*sy)/2
    local clip=UI.Panel {id=id,position="absolute",left=r.x,top=r.y,width=r.w,height=r.h,
        overflow="hidden",pointerEvents="none",zIndex=key=="body" and 0 or key=="thumb" and 2 or 1}
    clip:AddChild(UI.Panel {id=id.."_image",position="absolute",left=x-b[1]*sx,top=y-b[2]*sy,
        width=spec.w*sx,height=spec.h*sy,backgroundImage=A.Images[key],backgroundFit="fill",
        backgroundImageOpacity=opacity or 1,pointerEvents="none"})
    parent:AddChild(clip)
    return clip,{x=x,y=y,w=bw*sx,h=bh*sy}
end
---@param width number
---@param height number
function A.Fit(width,height)
    local s=math.max(1,math.min(width,height))
    local ox,oy=(width-s)/2,(height-s)/2
    local function r(x,y,w,h) return {x=ox+x*s,y=oy+y*s,w=w*s,h=h*s} end
    local scale=s/reference.width
    local function bounds(key)
        local layer=reference.layers[key];local spec=A.Specs[key]
        ---@type number[]
        local b=spec.bounds
        return {x=ox+(layer.x-layer.width/2+layer.width*b[1]/spec.w)*scale,
            y=oy+(layer.y-layer.height/2+layer.height*b[2]/spec.h)*scale,
            w=layer.width*(b[3]-b[1])/spec.w*scale,h=layer.height*(b[4]-b[2])/spec.h*scale}
    end
    local gap=math.max(8,math.floor(s*.018))
    local cards=r(.13,.245,.67,.415) -- Stop above the designer's bottom decoration band.
    local columns=s<600 and 1 or 2
    local cardW=(cards.w-gap*(columns-1))/columns
    local cardH=math.max(48,cardW*.285)
    return {x=ox,y=oy,scale=scale,body=r(0,0,1,1),cavity=r(.095,.155,.81,.665),
        plate=bounds("plate"),close=bounds("close"),
        hint=r(.13,.175,.67,.055),cards=cards,
        card={w=cardW,h=cardH,gap=gap,rowStep=cardH+gap,columns=columns},
        rail=r(.835,.245,.027,.415),foot=r(.05,.82,.90,.14),
        back=bounds("back"),handle=r(.39,.86,.22,.10),
        parcel=r(.067,.665,.06,.09),scrolls=r(.875,.60,.055,.17)}
end
return A
