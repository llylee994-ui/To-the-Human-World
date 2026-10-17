-- Shared display geometry; never changes source words, token IDs or saved layouts.
local UI=require "urhox-libs/UI"
local Theme=require "urhox-libs/UI/Core/Theme"
local Cache=require "urhox-libs/UI/Core/ImageCache"
local S={image="image/界面_纸条_折痕_透明_v01.png"}

function S.Metrics(value,options)
    options=options or {}
    local size=options.fontSize or 18
    local pixels=Theme.FontSize(size)
    local px,py=3,3
    local maxWidth=math.max(px*2+pixels,options.maxWidth or 320)
    local function measure(text)
        local width=UI.MeasureTextWidth and UI.MeasureTextWidth(text,pixels,Theme.FontFace("story","normal")) or 0
        -- A missing native font/context must not collapse a strip during startup.
        if width<=0 and text~="" then return (utf8.len(text) or #text)*pixels end
        return width
    end
    local natural=0
    for line in (value.."\n"):gmatch("(.-)\n") do natural=math.max(natural,measure(line)) end
    local width=math.min(maxWidth,math.ceil(natural)+px*2+2)
    local inner=math.max(1,math.floor(width-px*2-2))
    local lines={};local line=""
    for _,cp in utf8.codes(value) do
        local char=utf8.char(cp)
        if char=="\n" then lines[#lines+1]=line;line=""
        elseif line~="" and measure(line..char)>inner then lines[#lines+1]=line;line=char
        else line=line..char end
    end
    lines[#lines+1]=line
    -- Wrapped rows need the same fit as short words: size to the longest real row,
    -- not the original width limit or a tray grid cell. Metadata never reserves space.
    local longest=0
    for _,row in ipairs(lines) do longest=math.max(longest,measure(row)) end
    width=math.ceil(longest)+px*2+2
    local lineHeight=1.05
    local textHeight=math.ceil(#lines*pixels*lineHeight)
    return {width=width,height=textHeight+py*2,
        text=table.concat(lines,"\n"),fontSize=size,paddingX=px,paddingY=py,reserveTop=0,
        textHeight=textHeight,lineCount=#lines,lineHeight=lineHeight}
end

-- Preserve each torn end at the image's vertical scale. Only the middle stretches.
function S.Draw(vg,r,opacity)
    local handle=math.floor(Cache.Get(S.image))
    local iw,ih=Cache.GetSize(S.image)
    if handle<=0 or iw<=0 or ih<=0 or r.w<=0 or r.h<=0 then return end
    local sourceCap=iw*.08
    local cap=math.min(r.w/4,sourceCap*r.h/ih)
    local parts={{0,sourceCap,0,cap},{sourceCap,iw-2*sourceCap,cap,r.w-2*cap},{iw-sourceCap,sourceCap,r.w-cap,cap}}
    for _,p in ipairs(parts) do
        local sx=p[4]/p[2]
        nvgBeginPath(vg);nvgRect(vg,r.x+p[3],r.y,p[4],r.h)
        nvgFillPaint(vg,nvgImagePattern(vg,r.x+p[3]-p[1]*sx,r.y,iw*sx,r.h,0,handle,opacity or 1));nvgFill(vg)
    end
end

function S.Surface(props)
    props.backgroundImage=S.image;props.backgroundFit="fill"
    local root=UI.Panel(props)
    function root:RenderBackgroundImage(vg,_,r,_,_,_,_,opacity)
        S.Draw(vg,r or self:GetAbsoluteLayout(),opacity)
    end
    return root
end

function S.Label(parent,metrics,id,color)
    local label=UI.Label {id=id,text=metrics.text,fontFamily="story",fontSize=metrics.fontSize,
        fontColor=color or {65,47,32,255},position="absolute",left=metrics.paddingX,
        top=(metrics.height-metrics.textHeight+metrics.reserveTop)/2,
        width=metrics.width-2*metrics.paddingX,height=metrics.textHeight,
        textAlign="center",verticalAlign="middle",whiteSpace=metrics.lineCount==1 and "nowrap" or "normal",lineHeight=metrics.lineHeight,
        padding=0,flexShrink=0,pointerEvents="none"}
    parent:AddChild(label)
    return label
end
return S
