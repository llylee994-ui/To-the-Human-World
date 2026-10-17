local UI=require "urhox-libs/UI"
local A=require "ui.landscape.JourneyArt"
local Paper=require "ui.landscape.WishPaper"
local Sea=require "ui.landscape.SeaArt"
local Story=require "ui.landscape.StoryStyle"
local V={}
function V.New(ctx,ending,review)
    -- Source concatenation remains legacy audit data; the player's wish is the visual collage.
    local prose=ending.text
    if ending.wishText and prose:sub(-#ending.wishText)==ending.wishText then prose=prose:sub(1,-#ending.wishText-1):gsub("%s+$","") end
    local view=require("ui.landscape.DepartureView").New(ctx,ending,review,{heading="愿望",subtitle="寄往人间",background=Sea.background,
        backgroundWidth=1920,backgroundHeight=1080,pages=require("ui.landscape.DepartureSequence").Pages(prose)})
    local bottle=UI.Panel {id="wishBottleJourney",position="absolute",left=0,top=0,width="100%",height="100%",pointerEvents="none",zIndex=3.5}
    view.root:AddChild(bottle)
    function bottle:Render(vg)
        local b=self:GetAbsoluteLayout();local t=math.min(1,view.sequence.total/35)
        local size=b.w*.12*(1-.55*t)
        A.Sprite(vg,require("ui.landscape.SeasideManifest").bottle.path,b.x+b.w*(.5+.1*t),b.y+b.h*(.54-.16*t),size,size,-12+math.sin(t*8)*4,1-t*.35)
    end
    if not ending.collage then return view end
    local vp=ctx.viewport or {w=1280,h=720};local safe=ctx.safeInsets or {left=0,top=0,right=0,bottom=0}
    local sw,sh=vp.w-safe.left-safe.right,vp.h-safe.top-safe.bottom
    local overlay=UI.Panel {id="wishFrozenOverlay",position="absolute",left=0,top=0,width="100%",height="100%",visible=false,zIndex=30,onClick=function() end}
    A.Image(overlay,"image/wish-collage-r1/table-background.png",{left=0,top=0,width="100%",height="100%",backgroundFit="cover",zIndex=1})
    local ph=math.min(sh-110,(sw-40)*.75);local pw=ph/.75
    local frozen=Paper.New(overlay,{x=safe.left+(sw-pw)/2,y=safe.top+12,w=pw,h=ph},ending.collage,{id="wishFrozenPaper"})
    frozen.root.props.zIndex=2
    local close=Story.Button {id="closeFrozenWish",text="收好信纸",position="absolute",left=safe.left+(sw-200)/2,
        bottom=safe.bottom+18,width=200,height=48,fontSize=17,zIndex=3,onClick=function() if view.Live() then overlay:SetVisible(false) end end}
    overlay:AddChild(close);view.root:AddChild(overlay)
    local expand=A.Button(view.root,"viewEndingCollage","展开愿望信纸",function()
        if view.Live() and view.sequence.done then overlay:SetVisible(true) end
    end,false,{position="absolute",left=safe.left+(sw-220)/2,bottom=safe.bottom+20,width=220,height=44,visible=false,zIndex=14,
        backgroundColor={0,0,0,0},hoverBackgroundColor={232,200,143,15},textColor={214,187,143,255},borderWidth=0,fontSize=15})
    local update=view.Update
    function view.Update(dt,focused) update(dt,focused);expand:SetVisible(view.sequence.done) end
    return view
end
return V
