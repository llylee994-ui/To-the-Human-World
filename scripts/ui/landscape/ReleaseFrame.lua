-- Shared safe-area paper frame; long content scrolls separately from decisions.
local UI=require "urhox-libs/UI"
local H=require "ui.landscape.HarborStyle"
local Hud=require "ui.landscape.HudLayout"
local Responsive=require "ui.landscape.Responsive"
---@alias ReleasePage {root:Panel,body:Panel,footer:Panel,Refresh:fun(),Destroy:fun()}
local F={}
function F.Text(parent,text,id,size)
    local label=UI.Label {id=id,text=text,fontSize=size or 17,fontFamily=H.fontFamily,fontColor={62,49,36,255},
        whiteSpace="normal",lineHeight=1.55,alignSelf="stretch",flexShrink=0,pointerEvents="none"}
    parent:AddChild(label);return label
end
function F.Button(parent,id,text,click,enabled)
    local row=parent.props.flexDirection=="row"
    local button=H.Button {id=id,text=text,minHeight=48,minWidth=0,width=not row and "100%" or nil,
        flexGrow=row and 1 or 0,flexShrink=row and 1 or 0,flexBasis=row and 0 or nil,
        disabled=enabled==false,onClick=click}
    parent:AddChild(button);return button
end
---@return ReleasePage
function F.New(ctx,title)
    local safe=ctx.safeInsets or {left=0,top=0,right=0,bottom=0}
    local viewport=ctx.viewport or {w=1280,h=720}
    local top=Hud.SidePanelTop(viewport,safe,ctx.menuRect)
    local metrics=Responsive.Metrics(viewport,safe)
    local root=H.Paper {id="activePanel",position="absolute",left=safe.left+12,right=safe.right+12,
        top=top,bottom=safe.bottom+12,padding=metrics.short and 16 or 32,paperInset=metrics.short and 16 or 32,
        gap=8,overflow="hidden",onClick=function() end}
    F.Text(root,title,"releasePageTitle",23)
    local notice=UI.ScrollView {height=44,width="100%",flexShrink=0,scrollY=true,visible=false}
    ctx.panelNotice=F.Text(notice,ctx.model.message,"panelMessage",14);ctx.panelNoticeArea=notice;root:AddChild(notice)
    if not ctx.session.state.CanMutate() then
        F.Button(root,"reloadReleaseSave","重新读取原存档",function() ctx.model.Reload() end)
    end
    local scroll=UI.ScrollView {id="releaseBodyScroll",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,
        minHeight=0,scrollY=true,showScrollbar=true}
    local body=UI.Panel {width="100%",flexShrink=0,gap=12,paddingRight=12,pointerEvents="box-none"}
    scroll:AddChild(body);root:AddChild(scroll)
    local footer=UI.Panel {id="releaseFooter",width="100%",flexShrink=0,flexDirection="row",gap=8,pointerEvents="box-none"}
    root:AddChild(footer)
    return {root=root,body=body,footer=footer,Refresh=function() ctx.model.dirty=true end,Destroy=function() root:Destroy() end}
end
return F
