-- Word tray drawer: cloth mat, wooden tray, paper strips pulled out of the left edge.
-- Browsing and picking strips are view state only; nothing here writes a snapshot.
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local Theme=require "urhox-libs/UI/Core/Theme"
local Harbor=require "ui.landscape.HarborStyle"
local D={}
local ink,light={65,47,32,255},{255,244,218,255}
-- 三张生成图：铺满即可，不做九宫格切分（切片在目标小于切片和时两端不缩、会重叠）。
local CLOTH_IMAGE="image/界面_桌布_透明_v01.png"
local TRAY_IMAGE="image/界面_木托盘_透明_v01.png"
local SLIP_IMAGE="image/界面_纸条_折痕_透明_v01.png"
local FLOWERS_IMAGE="image/界面_干花束_透明_v01.png"
local TRAY_ASPECT=1086/1448          -- 托盘原图比例，锁住免得木框被拉扁
local TRAY_RIM_RATIO=.08             -- 盘沿用原图的宽度比例，纸条要落在盘底里面

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
-- 托盘尺寸按实际占位反推（标签行数、页脚行数、紧凑态），保持原图比例：
-- 宁可小一点，也别把木框拉扁或把页脚挤出面板。
local function traySize(ctx,collected,compact,picked)
    local panelHeight=viewportHeight(ctx)-(insets(ctx).top+12)-(insets(ctx).bottom+12)
    local contentWidth=panelWidth(ctx)-32
    local tabWidth,tabHeight,gap=compact and 64 or 78,compact and 36 or 42,compact and 6 or 8
    local perRow=math.max(1,math.floor((contentWidth+gap)/(tabWidth+gap)))
    local tabRows=#collected>0 and math.ceil(#collected/perRow) or 0
    local tabsHeight=tabRows*tabHeight+(tabRows>0 and (tabRows-1)*gap or 0)
    local footerHeight=compact and 26 or 52
    local available=math.max(96,panelHeight-32-44-8-tabsHeight-8-footerHeight-8)
    local width=math.min(contentWidth,math.floor(available*TRAY_ASPECT))
    return width,math.floor(width/TRAY_ASPECT)
end
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
function D.Open(ctx)
    local state=D.State(ctx)
    if state.closing then return state end
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
local function strip(ctx,state,card,compact)
    local width=math.floor(UI.MeasureTextWidth(card.text,Theme.FontSize(compact and 16 or 18),Harbor.fontFamily)
        +(compact and 24 or 40))
    local wrapper=UI.Panel {id="wordTrayCard_"..card.tokenId,width=width,height=compact and 38 or 46,flexShrink=0,
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
local function tab(ctx,state,parent,category,selected,compact)
    local button=UI.Button {id="wordTrayTab_"..category.id,text=D.ShortTitle(category.title),
        height=compact and 36 or 42,width=compact and 64 or 78,fontFamily=Harbor.fontFamily,
        fontSize=compact and 15 or 17,fontWeight="normal",
        backgroundImage=Harbor.paperImage,backgroundFit="fill",backgroundImageOpacity=selected and 1 or .72,
        hoverBackgroundImageOpacity=1,pressedBackgroundImageOpacity=.82,
        backgroundColor={0,0,0,0},hoverBackgroundColor={0,0,0,0},pressedBackgroundColor={0,0,0,0},
        variantBackgroundGradient={},variantHoverBackgroundGradient={},variantPressedBackgroundGradient={},
        borderWidth=0,hoverBorderWidth=0,pressedBorderWidth=0,borderRadius=0,boxShadow=false,glowShadow={},
        textColor=selected and ink or {116,89,63,255},padding={5,10},pressedPadding={5,10},
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
        width=width,height=viewportHeight(ctx)-(safe.top+12)-(safe.bottom+12),padding=16,gap=8,
        backgroundImage=CLOTH_IMAGE,backgroundFit="fill",
        overflow="hidden",pointerEvents="box-none",onClick=function() end}
    overlay:AddChild(panel)
    state.panel=panel
    local header=UI.Panel {id="wordTrayHeader",width="100%",height=44,flexShrink=0,flexDirection="row",
        alignItems="center",gap=8,pointerEvents="box-none"}
    panel:AddChild(header)
    -- 布面是浅色又有绣花，标题和页脚都用深色小底板压住，免得读不清。
    local title=Harbor.Tag {id="wordTrayTitle",text="词条栏",fontSize=15}
    header:AddChild(title)
    header:AddChild(UI.Panel {flexGrow=1,pointerEvents="none"})
    header:AddChild(Harbor.Button {id="closePanel",text="×",width=44,minHeight=44,fontSize=22,onClick=function() D.RequestClose(ctx) end})
    -- 转瞬消息沿用通用面板的字段，交给 UpdateChrome 每帧刷新。
    local noticeArea=UI.ScrollView {id="wordTrayMessageArea",width="100%",height=40,flexShrink=0,scrollY=true,
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
        local tabs=UI.Panel {id="wordTrayTabs",width="100%",flexShrink=0,flexDirection="row",flexWrap="wrap",
            gap=compact and 6 or 8,pointerEvents="box-none"}
        panel:AddChild(tabs)
        for _,category in ipairs(collected) do tab(ctx,state,tabs,category,category.id==selected,compact) end
    end
    ---@type table|false
    local picked=false
    for _,card in ipairs(view.cards) do if card.tokenId==state.selected then picked=card end end
    if not picked then state.selected=false end
    local trayWidth,trayHeight=traySize(ctx,collected,compact,picked)
    local rimPadding=math.floor(trayWidth*TRAY_RIM_RATIO)+6
    local flowerWidth=math.floor(math.min(compact and 64 or 76,trayWidth*.28))
    local flowerHeight=math.floor(flowerWidth*1.5)
    local holder=UI.Panel {id="wordTrayHolder",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,
        alignItems="center",justifyContent="center",pointerEvents="box-none"}
    panel:AddChild(holder)
    local tray=UI.Panel {id="wordTrayFrame",width=trayWidth,height=trayHeight,
        padding=rimPadding,paddingBottom=math.max(rimPadding,flowerHeight+12),gap=8,
        backgroundImage=TRAY_IMAGE,backgroundFit="fill",overflow="hidden",pointerEvents="box-none"}
    holder:AddChild(tray)
    local strips=UI.ScrollView {id="wordTrayStrips",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,
        scrollY=true,showScrollbar=true,pointerEvents="box-none"}
    local row=UI.Panel {width="100%",flexShrink=0,flexDirection="row",flexWrap="wrap",alignContent="flex-start",
        gap=10,pointerEvents="box-none"}
    strips:AddChild(row);tray:AddChild(strips)
    -- A readable bunch rests on the lower-left corner; scrolling stops above it.
    tray:AddChild(UI.Panel {id="wordTrayDriedFlowers",position="absolute",left=6,bottom=6,
        width=flowerWidth,height=flowerHeight,
        backgroundImage=FLOWERS_IMAGE,backgroundFit="contain",pointerEvents="none"})
    local mounted=0
    for _,card in ipairs(view.cards) do
        if card.categoryId==selected then
            mounted=mounted+1
            row:AddChild(strip(ctx,state,card,compact))
        end
    end
    if #collected==0 then
        text(row,"尚未收集词卡。阅读来信并剪下标记词后，会按来源收在这里。",16,"wordTrayEmpty",light)
    end
    local footer=UI.Panel {id="wordTrayFooter",width="100%",flexShrink=0,gap=4,overflow="hidden",pointerEvents="box-none"}
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
