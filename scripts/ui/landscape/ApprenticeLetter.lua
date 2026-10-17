local UI=require "urhox-libs/UI"
local A=require "ui.landscape.JourneyArt"
local Style=require "ui.landscape.StoryStyle"
local L={}
function L.New(ctx,parent,text,onCollect)
    local vp=ctx.viewport or {w=1280,h=720}
    local s=ctx.safeInsets or {left=0,top=0,right=0,bottom=0}
    local w,h=vp.w-s.left-s.right,vp.h-s.top-s.bottom
    local root=UI.Panel {id="apprenticeLetter",position="absolute",left=0,top=0,width="100%",height="100%",visible=false,zIndex=12}
    parent:AddChild(root)
    local small=h<500
    local sheet=A.Paper(root,{id="apprenticeLetterPaper",position="absolute",left=s.left+w*.03,top=s.top+h*.025,
        width=w*.94,height=h-102,padding=small and {24,32} or {40,60},gap=small and 8 or 18,
        backgroundColor={0,0,0,0}})
    local scroll=UI.ScrollView {id="merchantLetterScroll",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,
        minHeight=0,scrollY=true,showScrollbar=true,pointerEvents="auto"}
    sheet:AddChild(scroll)
    local body=UI.Panel {width="100%",flexShrink=0,paddingRight=16,pointerEvents="box-none"}
    scroll:AddChild(body)
    A.Label(body,text,"merchantLetterText",small and 18 or 20,{width="100%",lineHeight=1.85,fontColor={65,48,33,255}})
    local signature=UI.Panel {width="100%",height=42,flexShrink=0,pointerEvents="none"}
    sheet:AddChild(signature)
    A.Label(signature,"—— 店主",nil,16,{position="absolute",right=66,top=4,width=140,height=34,textAlign="right"})
    local smile=UI.Panel {id="apprenticeSmile",position="absolute",right=4,top=0,width=44,height=42,pointerEvents="none",rotate=-8}
    signature:AddChild(smile)
    function smile:Render(vg)
        local r=self:GetAbsoluteLayout();local x,y=r.x+r.w/2,r.y+r.h/2
        nvgStrokeColor(vg,nvgRGBA(91,66,43,220));nvgStrokeWidth(vg,1.5)
        nvgBeginPath(vg)
        for i=0,40 do
            local a=i*math.pi/20;local radius=15+.45*math.sin(i*1.7)
            local px,py=x+math.cos(a)*radius,y+math.sin(a)*radius*.94
            if i==0 then nvgMoveTo(vg,px,py) else nvgLineTo(vg,px,py) end
        end
        nvgStroke(vg)
        nvgBeginPath(vg);nvgMoveTo(vg,x-5,y-5);nvgLineTo(vg,x-5.5,y-1)
        nvgMoveTo(vg,x+5,y-5.5);nvgLineTo(vg,x+4.5,y-1.5);nvgStroke(vg)
        nvgBeginPath(vg);nvgMoveTo(vg,x-7,y+4)
        nvgBezierTo(vg,x-3,y+11,x+4,y+10,x+8,y+2);nvgStroke(vg)
    end
    local button=Style.Button {id="finishMerchantLetter",text="收下信件",position="absolute",
        left=s.left+(w-260)/2,bottom=s.bottom+18,width=260,height=58,minHeight=48,fontSize=18,
        onClick=onCollect}
    root:AddChild(button)
    return {root=root,sheet=sheet,button=button,scroll=scroll}
end
return L
