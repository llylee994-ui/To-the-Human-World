-- Quiet paper, sea and typography shared by the title and epilogue.
local UI=require "urhox-libs/UI"
local H=require "ui.landscape.HarborStyle"
local Backdrop=require "ui.landscape.SceneBackdrop"
local Sea=require "ui.landscape.SeaArt"
local Hud=require "ui.landscape.HudLayout"
local A={ink={61,57,43,255},muted={119,112,91,255},olive={76,91,73,255},cream={248,241,219,255}}
function A.Label(parent,text,id,size,extra)
    local p={id=id,text=text,fontFamily=H.fontFamily,fontSize=size or 18,fontColor=A.ink,
        whiteSpace="normal",lineHeight=1.65,flexShrink=0,pointerEvents="none"}
    for k,v in pairs(extra or {}) do p[k]=v end
    local node=UI.Label(p);parent:AddChild(node);return node
end
function A.Button(parent,id,text,click,primary,extra)
    local p={id=id,text=text,fontFamily=H.fontFamily,fontSize=16,fontWeight="normal",minHeight=44,padding={9,20},
        flexShrink=0,borderWidth=1,borderColor={128,129,101,90},borderRadius=4,
        textColor=primary and A.cream or A.ink,disabledTextColor={137,135,118,255},
        backgroundColor=primary and A.olive or {248,242,222,215},hoverBackgroundColor=primary and {93,108,84,255} or {255,249,229,255},
        pressedBackgroundColor=primary and {59,76,60,255} or {232,224,196,255},disabledBackgroundColor={215,211,190,220},
        backgroundGradient=false,hoverBackgroundGradient=false,pressedBackgroundGradient=false,disabledBackgroundGradient=false,
        variantBackgroundGradient={},variantHoverBackgroundGradient={},variantPressedBackgroundGradient={},variantDisabledBackgroundGradient={},
        boxShadow=false,hoverBoxShadow=false,pressedBoxShadow=false,disabledBoxShadow=false,glowShadow={},onClick=click}
    for k,v in pairs(extra or {}) do p[k]=v end
    local node=UI.Button(p);parent:AddChild(node);return node
end
function A.Image(parent,path,props)
    local p={position="absolute",backgroundImage=path,backgroundFit="contain",pointerEvents="none"}
    for k,v in pairs(props) do p[k]=v end
    local node=UI.Panel(p);parent:AddChild(node);return node
end
function A.Paper(parent,props)
    local p={backgroundImage=H.paperImage,backgroundFit="fill",backgroundSlice={32,32,32,32},backgroundColor={0,0,0,0},pointerEvents="box-none"}
    for k,v in pairs(props or {}) do p[k]=v end
    local node=UI.Panel(p);parent:AddChild(node);return node
end
function A.New(ctx,id,sea)
    local root=UI.Panel {id=id,position="absolute",left=0,top=0,width="100%",height="100%",onClick=function() end}
    local add=root.AddChild;local order=0
    function root:AddChild(child)
        order=order+1
        if child.props.zIndex==nil then child.props.zIndex=order end
        return add(self,child)
    end
    if sea then root:AddChild(Backdrop.New(id.."Sea",Sea.background,1920,1080,sea=="dock" and Sea.dockForeground or nil)) end
    root:AddChild(UI.Panel {position="absolute",left=0,top=0,width="100%",height="100%",backgroundColor=sea and {232,227,198,26} or {24,28,23,115},pointerEvents="none"})
    local vp=ctx.viewport or {w=1280,h=720};local s=ctx.safeInsets or {left=0,top=0,right=0,bottom=0}
    local top=math.max(s.top+14,Hud.SidePanelTop(vp,s,ctx.menuRect))
    local rect={x=s.left+24,y=top,w=vp.w-s.left-s.right-48,h=vp.h-top-s.bottom-20}
    local view={root=root,rect=rect,dead=false,busy=false}
    function view.Destroy() view.dead=true end
    function view.Live() return not view.dead and not ctx.destroyed end
    local notice=UI.ScrollView {id="journeyNotice",position="absolute",left=rect.x+16,right=s.right+40,bottom=s.bottom+76,
        maxHeight=68,minHeight=44,padding=10,scrollY=true,visible=false,backgroundColor={248,239,211,245},zIndex=40}
    ctx.panelNotice=A.Label(notice,ctx.model.message,"panelMessage",15,{fontColor={118,57,38,255}})
    ctx.panelNoticeArea=notice;root:AddChild(notice)
    if not ctx.session.state.CanMutate() then
        A.Button(root,"reloadReleaseSave","重新读取进度",function() if view.Live() then ctx.model.Reload() end end,true,
            {position="absolute",right=s.right+24,top=top,zIndex=50})
    end
    return view
end
function A.Sprite(vg,path,x,y,w,h,angle,alpha)
    local handle=math.floor(require("urhox-libs/UI/Core/ImageCache").Get(path))
    if handle<=0 or alpha<=0 then return end
    nvgSave(vg);nvgTranslate(vg,x,y);nvgRotate(vg,math.rad(angle or 0))
    nvgBeginPath(vg);nvgRect(vg,-w/2,-h/2,w,h)
    nvgFillPaint(vg,nvgImagePattern(vg,-w/2,-h/2,w,h,0,handle,alpha));nvgFill(vg);nvgRestore(vg)
end
return A
