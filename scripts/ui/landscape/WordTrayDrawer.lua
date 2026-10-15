-- Word tray drawer: cloth mat, wooden tray, paper strips pulled out of the left edge.
-- Browsing and picking strips are view state only; nothing here writes a snapshot.
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local Harbor=require "ui.landscape.HarborStyle"
local Art=require "ui.landscape.WordTrayArt"
local PanelArt=require "ui.landscape.PanelArt"
local D={}
local ink,light={65,47,32,255},{255,244,218,255}
-- 原纸条纹理整图显示；词卡按参考布局的两列排布。
local SLIP_IMAGE="image/界面_纸条_折痕_透明_v01.png"

---@class WordTrayState
---@field open number
---@field target number
---@field settled boolean
---@field panel Widget|false
---@field selected string|false
---@field category string|false
---@field closing boolean

D.AnimationSeconds=.22
D.WidthRatio=.26

local function ease(t) t=math.max(0,math.min(1,t));return t*t*(3-2*t) end
local function text(parent,value,size,id,color)
    local label=UI.Label {id=id,text=tostring(value or ""),fontFamily=Harbor.fontFamily,fontSize=size or 16,
        fontColor=color or ink,whiteSpace="normal",lineHeight=1.35,flexShrink=0,pointerEvents="none",alignSelf="stretch"}
    parent:AddChild(label);return label
end
local function viewportWidth(ctx)
    if ctx.viewport and ctx.viewport.w and ctx.viewport.w>0 then return ctx.viewport.w end
    if UI.GetViewportSize then local w=UI.GetViewportSize();if w and w>0 then return w end end
    return 1280
end
local function viewportHeight(ctx)
    if ctx.viewport and ctx.viewport.h and ctx.viewport.h>0 then return ctx.viewport.h end
    if UI.GetViewportSize then local _,h=UI.GetViewportSize();if h and h>0 then return h end end
    return 720
end
local function insets(ctx) return ctx.safeInsets or {left=0,top=0,right=0,bottom=0} end
local function panelWidth(ctx)
    local safe=insets(ctx)
    return math.floor(math.max(0,viewportWidth(ctx)-safe.left-safe.right)*D.WidthRatio)
end
local function panelLeft(ctx,state) return math.floor(insets(ctx).left-(1-ease(state.open))*panelWidth(ctx)) end
---@param ctx table
---@return WordTrayState
function D.State(ctx)
    local state=ctx.wordTray
    if not state then
        state={open=0,target=0,settled=true,panel=false,selected=false,category=false,closing=false}
        ctx.wordTray=state
    end
    return state --[[@as WordTrayState]]
end
function D.Progress(ctx)
    local state=ctx.wordTray --[[@as WordTrayState?]]
    return state and state.open or 0
end
function D.Settled(ctx)
    local state=ctx.wordTray --[[@as WordTrayState?]]
    return not state or state.settled
end
function D.Open(ctx,userInitiated)
    local state=D.State(ctx)
    if state.closing then return state end
    if userInitiated and state.target~=1 and ctx.PlayObjectSound then ctx.PlayObjectSound("tray_open") end
    state.target=1;state.settled=false
    return state
end
-- 切场景/换面板/销毁时直接复位，别把动画状态留给下一次打开。
function D.Reset(ctx)
    local state=ctx.wordTray --[[@as WordTrayState?]]
    if not state then return end
    state.open=0;state.target=0;state.settled=true;state.panel=false
    state.selected=false;state.category=false;state.closing=false
end
-- 关闭按钮先滑出再真正关面板；其它关闭路径保持立即关闭。
function D.RequestClose(ctx)
    local state=ctx.wordTray --[[@as WordTrayState?]]
    if not state or state.open<=0 then return end
    if not state.closing and ctx.panel=="words" and ctx.PlayObjectSound then ctx.PlayObjectSound("tray_close") end
    state.closing=true;state.target=0;state.settled=false
end
function D.Update(ctx,dt)
    local state=ctx.wordTray --[[@as WordTrayState?]]
    if not state or state.settled then return end
    local step=(dt or 0)/D.AnimationSeconds
    if state.target>=state.open then state.open=math.min(state.target,state.open+step)
    else state.open=math.max(state.target,state.open-step) end
    if state.open==state.target then state.settled=true end
    if state.panel then Widget.SetStyle(state.panel,{left=panelLeft(ctx,state)}) end
    if state.closing and state.settled then
        state.closing=false
        ctx.Close()
    end
end
-- 界面上把「情绪类」这类分类名收成两个字；只影响显示，不改 data.words。
function D.ShortTitle(title)
    local short=(title or ""):gsub("类$","")
    return short
end
function D.StatusText(card)
    if not card.available then return "已消耗" end
    if card.selectedRole=="main" then return "已投入 · 主词" end
    if card.selectedRole=="aux" then return "已投入 · 辅词" end
    return "可用"
end
function D.MarkText(card)
    if card.selectedRole=="main" then return "主" end
    if card.selectedRole=="aux" then return "辅" end
    if not card.available then return "已用" end
    return false
end
-- 纸条：底面用生成图整体拉伸（切片在短纸条上会重叠），词由代码渲染。
local function strip(ctx,state,card,compact,layout,index)
    local width=layout.slipWidth
    local height=math.max(38,layout.slipHeight)
    local col=(index-1)%2
    local wrapper=UI.Panel {id="wordTrayCard_"..card.tokenId,position="absolute",
        left=col*(layout.cards.w-width),top=math.floor((index-1)/2)*math.max(height+12,layout.rowStep),
        width=width,height=height,flexShrink=0,
        alignItems="center",justifyContent="center",
        backgroundImage=SLIP_IMAGE,backgroundFit="fill",
        backgroundImageOpacity=card.available and 1 or .55,
        onClick=function() state.selected=card.tokenId;ctx.model.dirty=true end}
    local label=text(wrapper,card.text,compact and 16 or 18,"wordTrayText_"..card.tokenId,
        card.available and ink or {65,47,32,150})
    label.props.textAlign="center"
    label.props.whiteSpace="nowrap"
    if state.selected==card.tokenId then
        wrapper:AddChild(UI.Panel {position="absolute",left=0,top=0,right=0,bottom=0,
            borderWidth=2,borderColor={214,178,110,235},borderRadius=4,pointerEvents="none"})
    end
    local mark=D.MarkText(card)
    if mark then
        wrapper:AddChild(UI.Label {id="wordTrayMark_"..card.tokenId,text=mark,position="absolute",right=0,top=0,
            backgroundColor={93,71,46,215},borderRadius=4,fontFamily=Harbor.fontFamily,fontSize=11,
            fontColor={255,244,218,255},padding={2,6},pointerEvents="none"})
    end
    return wrapper
end
local function tab(ctx,state,parent,category,selected,compact,layout,index)
    local template=layout.categories[math.min(index,#layout.categories)]
    local extra=math.max(0,index-#layout.categories)*80*layout.scale
    local paper={x=template.x,y=template.y-layout.tabs.y+extra,w=template.w,h=template.h,
        path=template.path,rotate=template.rotate}
    local image=PanelArt.Image(parent,"wordTrayCategoryPaper_"..category.id,paper)
    image.props.backgroundImageOpacity=selected and 1 or .8
    local button=UI.Button {id="wordTrayTab_"..category.id,text=D.ShortTitle(category.title),
        position="absolute",left=layout.tabs.x,top=paper.y+(paper.h-44)/2,
        height=44,width=layout.tabs.w,fontFamily=Harbor.fontFamily,
        fontSize=15,fontWeight="normal",
        backgroundColor={0,0,0,0},hoverBackgroundColor={0,0,0,0},pressedBackgroundColor={0,0,0,0},
        variantBackgroundGradient={},variantHoverBackgroundGradient={},variantPressedBackgroundGradient={},
        borderWidth=0,hoverBorderWidth=0,pressedBorderWidth=0,borderRadius=0,boxShadow=false,glowShadow={},
        textColor=selected and ink or {116,89,63,255},padding=0,pressedPadding=0,
        onClick=function() state.category=category.id;state.selected=false;ctx.model.dirty=true end}
    if selected then
        button:AddChild(UI.Panel {position="absolute",left=14,right=14,bottom=4,height=2,
            backgroundColor={155,107,57,210},pointerEvents="none"})
    end
    parent:AddChild(button)
end
---@param ctx table
---@param overlay Widget
function D.Render(ctx,overlay)
    local state=D.State(ctx)
    local safe=insets(ctx)
    local width=panelWidth(ctx)
    local compact=viewportHeight(ctx)<540
    local panel=UI.Panel {id="activePanel",position="absolute",left=panelLeft(ctx,state),top=safe.top+12,
        width=width,height=viewportHeight(ctx)-(safe.top+12)-(safe.bottom+12),padding=0,
        overflow="hidden",pointerEvents="auto",onClick=function() end}
    overlay:AddChild(panel)
    state.panel=panel
    local layout=Art.Fit(width,panel.props.height)
    PanelArt.Image(panel,"wordTrayCloth",layout.cloth)
    local header=UI.Panel {id="wordTrayHeader",position="absolute",left=8,right=8,top=8,zIndex=10,height=44,flexShrink=0,flexDirection="row",
        alignItems="center",gap=8,pointerEvents="box-none"}
    panel:AddChild(header)
    -- 布面是浅色又有绣花，标题和页脚都用深色小底板压住，免得读不清。
    local title=Harbor.Tag {id="wordTrayTitle",text="词条栏",fontSize=15}
    header:AddChild(title)
    header:AddChild(UI.Panel {flexGrow=1,pointerEvents="none"})
    header:AddChild(Harbor.Button {id="closePanel",text="×",width=44,minHeight=44,fontSize=22,onClick=function() D.RequestClose(ctx) end})
    -- 转瞬消息沿用通用面板的字段，交给 UpdateChrome 每帧刷新。
    local noticeArea=UI.ScrollView {id="wordTrayMessageArea",position="absolute",left=8,right=8,top=58,zIndex=11,height=40,flexShrink=0,scrollY=true,
        visible=false,paddingLeft=8,paddingRight=8,pointerEvents="box-none"}
    ctx.panelNotice=text(noticeArea,ctx.model.message,13,"panelMessage");ctx.panelNoticeArea=noticeArea
    panel:AddChild(noticeArea)
    local result=ctx.session.queries.GetWordTray()
    if not result.ok then
        text(panel,result.error.message,16,"wordTrayQueryError");return
    end
    local view=result.value
    local collected={}
    for _,category in ipairs(view.categories) do
        local count=0
        for _,card in ipairs(view.cards) do if card.categoryId==category.id then count=count+1 end end
        if count>0 then collected[#collected+1]=category end
    end
    local selected=state.category
    local known=false
    for _,category in ipairs(collected) do if category.id==selected then known=true end end
    if not known then selected=collected[1] and collected[1].id or false end
    state.category=selected
    if #collected>0 then
        local tabs=UI.ScrollView {id="wordTrayTabs",position="absolute",left=0,top=layout.tabs.y,width=width,
            height=layout.tabs.h,scrollY=true,showScrollbar=false,pointerEvents="box-none"}
        panel:AddChild(tabs)
        local stack=UI.Panel {width="100%",height=math.max(layout.tabs.h,(#collected*80+20)*layout.scale),pointerEvents="box-none"}
        tabs:AddChild(stack)
        for i,category in ipairs(collected) do tab(ctx,state,stack,category,category.id==selected,compact,layout,i) end
    end
    ---@type table|false
    local picked=false
    for _,card in ipairs(view.cards) do if card.tokenId==state.selected then picked=card end end
    if not picked then state.selected=false end
    local holder=UI.Panel {id="wordTrayHolder",position="absolute",left=0,top=0,width="100%",height="100%",
        pointerEvents="box-none"}
    panel:AddChild(holder)
    PanelArt.Image(holder,"wordTrayFrame",layout.tray)
    local scrollProps=PanelArt.Style(layout.cards)
    scrollProps.id="wordTrayStrips";scrollProps.scrollY=true;scrollProps.showScrollbar=true;scrollProps.pointerEvents="box-none"
    local strips=UI.ScrollView(scrollProps)
    local row=UI.Panel {width="100%",height=layout.cards.h,pointerEvents="box-none"}
    strips:AddChild(row);holder:AddChild(strips)
    PanelArt.Image(holder,"wordTrayLavender",layout.lavender)
    PanelArt.Image(holder,"wordTrayDriedFlowers",layout.flowers)
    local mounted=0
    for _,card in ipairs(view.cards) do
        if card.categoryId==selected then
            mounted=mounted+1
            row:AddChild(strip(ctx,state,card,compact,layout,mounted))
        end
    end
    Widget.SetStyle(row,{height=math.max(layout.cards.h,math.ceil(mounted/2)*math.max(50,layout.rowStep))})
    if #collected==0 then
        text(row,"尚未收集词卡。阅读来信并剪下标记词后，会按来源收在这里。",16,"wordTrayEmpty",light)
    end
    local footer=UI.Panel {id="wordTrayFooter",position="absolute",left=12,right=12,bottom=8,
        height=56,gap=2,overflow="hidden",pointerEvents="box-none"}
    panel:AddChild(footer)
    ---@type table|false
    local active=false
    for _,category in ipairs(collected) do if category.id==selected then active=category end end
    if picked then
        footer:AddChild(Harbor.Tag {id="wordTraySource",text="来源："..picked.sourceTitle,fontSize=compact and 12 or 13,
            alignSelf="flex-start"})
        if not compact then
            footer:AddChild(Harbor.Tag {id="wordTrayStatus",text=D.StatusText(picked),fontSize=12,alignSelf="flex-start"})
        end
    else
        if active then
            footer:AddChild(Harbor.Tag {id="wordTraySource",text=active.title.." · 可用 "..active.availableCount,
                fontSize=compact and 12 or 13,alignSelf="flex-start"})
        end
        if mounted>0 then
            footer:AddChild(Harbor.Tag {id="wordTrayHint",text="点纸条查看来源",fontSize=12,alignSelf="flex-start"})
        end
    end
end
return D
