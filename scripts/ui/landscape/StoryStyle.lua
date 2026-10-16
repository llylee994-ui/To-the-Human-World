-- Shared, text-free painted button plates; live text and saved ratings remain UI.
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local H=require "ui.landscape.HarborStyle"
local Art=require "ui.landscape.BrewArt"
local S={}
local path="image/story-result/button-skins-v01.png"
local frames={
    primary={path=path,width=1536,height=1024,x=33,y=150,w=1470,h=290},
    secondary={path=path,width=1536,height=1024,x=33,y=580,w=1470,h=287},
}
function S.Button(props,kind)
    kind=kind or "primary"
    local b=H.Button(props)
    Widget.SetStyle(b,{backgroundImage=path,textColor=kind=="secondary" and {93,65,37,255} or {255,240,202,255},
        disabledTextColor=kind=="secondary" and {128,114,94,255} or {205,200,180,255},padding={8,24}})
    function b:RenderBackgroundImage(vg,_,r,fit,slice,radius,tint,opacity)
        Art.Draw(vg,frames[kind],r or self:GetAbsoluteLayout(),opacity or 1)
    end
    return b
end
local function star(vg,x,y,r,filled)
    nvgBeginPath(vg)
    for i=0,9 do
        local a=-math.pi/2+i*math.pi/5;local rad=i%2==0 and r or r*.44
        if i==0 then nvgMoveTo(vg,x+math.cos(a)*rad,y+math.sin(a)*rad)
        else nvgLineTo(vg,x+math.cos(a)*rad,y+math.sin(a)*rad) end
    end
    nvgClosePath(vg)
    if filled then nvgFillColor(vg,nvgRGBA(153,94,42,225));nvgFill(vg) end
    nvgStrokeWidth(vg,1.2);nvgStrokeColor(vg,nvgRGBA(153,94,42,200));nvgStroke(vg)
end
function S.Seal(stars,scale)
    stars=math.max(0,math.min(3,stars))
    local k=scale or 1
    local p=UI.Panel {id="resultSeal",position="absolute",right=0,top=4,width=166*k,height=114*k,pointerEvents="none"}
    function p:Render(vg)
        local r=self:GetAbsoluteLayout();local x,y=r.x+r.w/2,r.y+48*k
        for _,radius in ipairs({46,41}) do
            nvgBeginPath(vg);nvgCircle(vg,x,y,radius*k)
            nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(151,94,44,155));nvgStroke(vg)
        end
        for i=1,28 do
            local a=i*math.pi/14
            nvgBeginPath(vg);nvgCircle(vg,x+math.cos(a)*44*k,y+math.sin(a)*44*k,.8*k)
            nvgFillColor(vg,nvgRGBA(151,94,44,170));nvgFill(vg)
        end
        for i=1,3 do star(vg,x+(i-2)*29*k,y+3*k,(i==2 and 16 or 12)*k,i<=stars) end
    end
    p:AddChild(UI.Label {text="药效评级",position="absolute",left=0,top=14*k,width=166*k,height=22*k,
        fontFamily=H.fontFamily,fontSize=math.max(9,11*k),textAlign="center",fontColor={138,91,46,255},pointerEvents="none"})
    p:AddChild(UI.Label {id="resultStars",text=tostring(stars).." 星",position="absolute",left=0,top=74*k,width=166*k,height=40*k,
        fontFamily=H.fontFamily,fontSize=math.max(11,14*k),textAlign="center",fontColor={138,91,46,255},pointerEvents="none"})
    return p
end
function S.Decor(parent)
    parent:AddChild(UI.Panel {position="absolute",left=-4,top=36,width=76,height=176,
        backgroundImage="image/界面_干花束_透明_v01.png",backgroundFit="contain",opacity=.7,pointerEvents="none"})
    parent:AddChild(UI.Panel {position="absolute",right=-6,bottom=9,width=100,height=150,
        backgroundImage="image/界面_记录书_麦穗干草_透明_v01.png",backgroundFit="contain",opacity=.65,pointerEvents="none"})
end
return S
