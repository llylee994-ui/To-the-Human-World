-- Word tray drawer: cloth mat, wooden tray, paper strips pulled out of the left edge.
-- Browsing and picking strips are view state only; nothing here writes a snapshot.
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local Harbor=require "ui.landscape.HarborStyle"
local Art=require "ui.landscape.WordTrayArt"
local PanelArt=require "ui.landscape.PanelArt"
local Arrow=require "ui.landscape.EmbroideredArrow"
local Slip=require "ui.landscape.WordSlip"
local Pages=require "ui.landscape.WordTrayPages"
local D={}
local ink,light={65,47,32,255},{255,244,218,255}

---@class WordTrayState
---@field open number
---@field target number
---@field settled boolean
---@field panel Widget|false
---@field selected string|false
---@field category string|false
---@field closing boolean
---@field pages table<string,number>
---@field pageCount number
---@field categoryGroup number

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
local function panelLeft(ctx,state)
    return math.floor(-(1-ease(state.open))*(panelWidth(ctx)+32))
end
---@param ctx table
---@return WordTrayState
function D.State(ctx)
    local state=ctx.wordTray
    if not state then
        state={open=0,target=0,settled=true,panel=false,selected=false,category=false,closing=false}
        ctx.wordTray=state
    end
    state.pages=state.pages or {};state.pageCount=state.pageCount or 1;state.categoryGroup=state.categoryGroup or 1
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
local function strip(ctx,state,card,metrics,x,y,options)
    options=options or {}
    local dimmed=not card.available or card.selectedRole
    local wrapper=Slip.Surface {id=(options.cardPrefix or "wordTrayCard_")..card.tokenId,position="absolute",
        left=x,top=y,width=metrics.width,height=metrics.height,flexShrink=0,
        alignItems="center",justifyContent="center",
        backgroundImageOpacity=dimmed and .55 or 1,disabled=options.onPick and not card.available or nil,
        onClick=function()
            if options.onPick and not card.available then return end
            state.selected=card.tokenId;ctx.model.dirty=true
            if options.onPick then options.onPick(card) end
        end}
    Slip.Label(wrapper,metrics,"wordTrayText_"..card.tokenId,
        dimmed and {65,47,32,150} or ink)
    wrapper.wordSlip=metrics
    if state.selected==card.tokenId then
        wrapper:AddChild(UI.Panel {position="absolute",left=0,top=0,right=0,bottom=0,
            borderWidth=2,borderColor={214,178,110,235},borderRadius=4,pointerEvents="none"})
    end
    if ctx.brewDrag then ctx.brewDrag(wrapper,card) end
    if options.bindSource then options.bindSource(wrapper,card) end
    return wrapper
end
local function tab(ctx,state,parent,category,selected,layout,index,step)
    local template=layout.categories[math.min(index,#layout.categories)]
    local paperHeight=math.min(step,template.h)
    local paper={x=template.x,y=(index-1)*step+(step-paperHeight)/2,w=template.w,h=paperHeight,
        path=template.path,rotate=template.rotate}
    local image=PanelArt.Image(parent,"wordTrayCategoryPaper_"..category.id,paper)
    image.props.backgroundImageOpacity=selected and 1 or .8
    local touchHeight=math.min(44,step)
    local button=UI.Button {id="wordTrayTab_"..category.id,text=D.ShortTitle(category.title),
        position="absolute",left=layout.tabs.x,top=(index-1)*step+(step-touchHeight)/2,
        height=touchHeight,width=math.max(44,layout.tabs.w),fontFamily=Harbor.fontFamily,
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
function D.Render(ctx,overlay,options)
    options=options or {}
    local state=D.State(ctx)
    local safe=insets(ctx)
    local width=panelWidth(ctx)
    local compact=viewportHeight(ctx)<540
    local panel=UI.Panel {id="activePanel",position="absolute",left=panelLeft(ctx,state),top=safe.top+12,
        width=width,height=viewportHeight(ctx)-(safe.top+12)-(safe.bottom+12),padding=0,
        overflow="visible",pointerEvents="auto",onClick=function() end}
    overlay:AddChild(panel)
    state.panel=panel
    -- Only the pull tab crosses the cloth edge; keep the designer art cropped.
    local content=UI.Panel {id="wordTrayContents",position="absolute",left=0,top=0,width="100%",height="100%",
        overflow="hidden",pointerEvents="box-none"}
    panel:AddChild(content)
    local layout=Art.Fit(width,panel.props.height)
    PanelArt.Image(content,"wordTrayCloth",layout.cloth)
    -- 标题在木托盘内上沿，避开顶部金币栏，并与首排词卡留出间距。
    local title=Harbor.Tag {id="wordTrayTitle",text="词条栏",fontSize=11,padding=0,minHeight=20,
        position="absolute",left=layout.title.x,top=layout.title.y,width=layout.title.w,height=layout.title.h,zIndex=10,
        backgroundColor={246,230,194,245},fontColor=ink,borderRadius=3}
    content:AddChild(title)
    Arrow.Attach(panel,{id="closePanel",arrowDirection="left",position="absolute",right=-20,bottom=0,
        onClick=function() D.RequestClose(ctx) end})
    -- 转瞬消息沿用通用面板的字段，交给 UpdateChrome 每帧刷新。
    local noticeArea=UI.ScrollView {id="wordTrayMessageArea",position="absolute",left=8,right=8,top=58,zIndex=11,height=40,flexShrink=0,scrollY=true,
        visible=false,paddingLeft=8,paddingRight=8,pointerEvents="box-none"}
    ctx.panelNotice=text(noticeArea,ctx.model.message,13,"panelMessage");ctx.panelNoticeArea=noticeArea
    content:AddChild(noticeArea)
    local result=options.view and {ok=true,value=options.view} or ctx.session.queries.GetWordTray()
    if not result.ok then
        text(content,result.error.message,16,"wordTrayQueryError");return
    end
    local view=result.value
    local collected={}
    for _,category in ipairs(view.categories) do
        local count=0
        for _,card in ipairs(view.cards) do if card.categoryId==category.id then count=count+1 end end
        if count>0 then collected[#collected+1]=category end
    end
    for _,category in ipairs(options.extraCategories or {}) do collected[#collected+1]=category end
    local selected=state.category
    local known=false
    for _,category in ipairs(collected) do if category.id==selected then known=true end end
    if not known then selected=collected[1] and collected[1].id or false end
    state.category=selected
    if #collected>0 then
        if options.allCategories then layout.tabs.h=math.max(layout.tabs.h,panel.props.height-layout.tabs.y-80) end
        local capacity=options.allCategories and #collected or math.max(1,math.floor((layout.tabs.h-44)/44))
        local groups=math.ceil(#collected/capacity)
        state.categoryGroup=math.max(1,math.min(groups,state.categoryGroup))
        local tabs=UI.Panel {id="wordTrayTabs",position="absolute",left=0,top=layout.tabs.y,width=width,
            height=layout.tabs.h,pointerEvents="box-none"}
        content:AddChild(tabs)
        local first=(state.categoryGroup-1)*capacity+1
        local last=math.min(#collected,first+capacity-1)
        local step=options.allCategories and math.min(64,layout.tabs.h/#collected)
            or math.min(72,math.max(44,(layout.tabs.h-(groups>1 and 44 or 0))/(last-first+1)))
        for i=first,last do tab(ctx,state,tabs,collected[i],collected[i].id==selected,layout,i-first+1,step) end
        if groups>1 then
            tabs:AddChild(Harbor.Button {id="wordTrayCategoryNext",text="›",
                position="absolute",left=layout.tabs.x,bottom=0,width=math.max(44,layout.tabs.w),height=44,minHeight=44,
                fontSize=12,padding=0,onClick=function()
                    state.categoryGroup=state.categoryGroup%groups+1;ctx.model.dirty=true
                    if ctx.PlayObjectSound then ctx.PlayObjectSound("ui_click_01") end
                end})
        end
    end
    ---@type table|false
    local picked=false
    for _,card in ipairs(view.cards) do if card.tokenId==state.selected then picked=card end end
    if not picked then state.selected=false end
    local holder=UI.Panel {id="wordTrayHolder",position="absolute",left=0,top=0,width="100%",height="100%",
        pointerEvents="box-none"}
    content:AddChild(holder)
    PanelArt.Image(holder,"wordTrayFrame",layout.tray)
    local regionProps=PanelArt.Style(layout.cards)
    regionProps.id="wordTrayStrips";regionProps.pointerEvents="box-none"
    local row=UI.Panel(regionProps);holder:AddChild(row)
    PanelArt.Image(holder,"wordTrayLavender",layout.lavender)
    PanelArt.Image(holder,"wordTrayDriedFlowers",layout.flowers)
    local available=math.max(1,layout.cards.w)
    local extraCategory=false
    for _,category in ipairs(options.extraCategories or {}) do if selected==category.id then extraCategory=true end end
    local items={}
    if extraCategory then items=options.extraItems or {}
    else for _,card in ipairs(view.cards) do if card.categoryId==selected then items[#items+1]=card end end end
    local packed=Pages.Build(items,available,layout.cards.h,function(card)
        if extraCategory then return options.measureExtra(card,available,layout.cards.h,compact) end
        return Slip.Metrics(card.text,{fontSize=compact and 16 or 18,maxWidth=available})
    end)
    local key=selected or "empty"
    local page=math.max(1,math.min(packed.pageCount,state.pages[key] or 1))
    state.pages[key]=page;state.pageCount=packed.pageCount
    for _,entry in ipairs(packed.pages[page]) do
        if extraCategory then options.renderExtra(row,entry.card,entry.metrics,entry.x,entry.y)
        else row:AddChild(strip(ctx,state,entry.card,entry.metrics,entry.x,entry.y,options)) end
    end
    local mounted=#items
    local pager=UI.Panel {id="wordTrayPager",position="absolute",left=layout.pager.x,top=layout.pager.y,
        width=layout.pager.w,height=44,flexDirection="row",alignItems="center",justifyContent="space-between",
        pointerEvents="box-none",zIndex=5}
    holder:AddChild(pager)
    local function turn(delta)
        local target=math.max(1,math.min(packed.pageCount,page+delta))
        if target==(state.pages[key] or page) then return end
        state.pages[key]=target;state.selected=false;ctx.model.dirty=true
        if ctx.PlayObjectSound then ctx.PlayObjectSound("ui_click_01") end
    end
    pager:AddChild(Harbor.Button {id="wordTrayPrev",text="‹",width=44,height=44,minHeight=44,fontSize=24,padding=0,
        disabled=page==1,onClick=function() turn(-1) end})
    local pageLabel=text(pager,page.." / "..packed.pageCount,12,"wordTrayPage",light)
    Widget.SetStyle(pageLabel,{width=60,height=44,textAlign="center",verticalAlign="middle",whiteSpace="nowrap",alignSelf="center"})
    pager:AddChild(Harbor.Button {id="wordTrayNext",text="›",width=44,height=44,minHeight=44,fontSize=24,padding=0,
        disabled=page==packed.pageCount,onClick=function() turn(1) end})
    if #collected==0 then
        text(row,"尚未收集词卡。阅读来信并剪下标记词后，会按来源收在这里。",16,"wordTrayEmpty",light)
    end
    local footer=UI.Panel {id="wordTrayFooter",position="absolute",left=12,right=100,bottom=8,
        height=ctx.brewDrag and 86 or 56,gap=2,overflow="hidden",pointerEvents="box-none"}
    content:AddChild(footer)
    ---@type table|false
    local active=false
    for _,category in ipairs(collected) do if category.id==selected then active=category end end
    if picked then
        footer:AddChild(Harbor.Tag {id="wordTraySource",text="来源："..picked.sourceTitle,fontSize=compact and 12 or 13,
            alignSelf="flex-start"})
        if not compact then
            footer:AddChild(Harbor.Tag {id="wordTrayStatus",text=(options.statusText or D.StatusText)(picked),fontSize=12,alignSelf="flex-start"})
        end
        if ctx.brewDrag then
            local action=ctx.model.Action("UpdateDraft")
            footer:AddChild(Harbor.Button {id="brewSelectWord",text=picked.selectedRole and "取出词卡" or "投入词卡",
                minHeight=44,fontSize=13,disabled=not action.enabled or not picked.available,onClick=function()
                    if picked.selectedRole then ctx.model.TakeOut("word",picked.tokenId)
                    else ctx.model.Drop("word",picked.tokenId) end
                end})
        end
    else
        if active then
            footer:AddChild(Harbor.Tag {id="wordTraySource",text=options.footerText and options.footerText(active) or active.title.." · 可用 "..active.availableCount,
                fontSize=compact and 12 or 13,alignSelf="flex-start"})
        end
        if mounted>0 then
            footer:AddChild(Harbor.Tag {id="wordTrayHint",text=options.hint or "点纸条查看来源",fontSize=12,alignSelf="flex-start"})
        end
    end
    return panel
end
return D
