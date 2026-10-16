-- 记录书：右侧布料底衬 + 摊开的左半页 + 左缘索引贴（一个故事一个标签）。
-- 只读查询；切换故事立即更新，回看后续使用独立信纸。
-- 布局与滑动沿用 WordTrayDrawer 的约定：状态存在 ctx，重建控件树后由 Update 重新贴位。
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local Theme=require "urhox-libs/UI/Core/Theme"
local Harbor=require "ui.landscape.HarborStyle"
local Art=require "ui.landscape.JournalBookArt"
local PanelArt=require "ui.landscape.PanelArt"
local B={}
local ink,inkFaint={72,52,36,255},{128,106,78,255}

---@class JournalBookState
---@field open number 布料滑入进度 0~1
---@field target number
---@field settled boolean
---@field panel Widget|false
---@field page Widget|false
---@field story string|false 当前故事（来源信 id）
---@field entry string|false 详情页的分支片段 id；false 表示目录
---@field closing boolean
---@field art table|false Physical book widgets, isolated from collected records.

B.AnimationSeconds=.22
-- 面板宽度与词条托盘一致（可用宽度的 26%）：左右两侧各留出一条，中间留给药锅。
B.WidthRatio=.26
B.ShowLockedTitles=false -- 未收集分支是否露出短名：false 时显示“？？？”

local function ease(t) t=math.max(0,math.min(1,t));return t*t*(3-2*t) end
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
    return math.floor(math.max(0,viewportWidth(ctx)-safe.left-safe.right)*B.WidthRatio)
end
-- 关闭态整个面板推到屏外，把右安全区一起算进去，边界上也不露一条。
local function panelRight(ctx,state)
    local safe=insets(ctx)
    return math.floor(safe.right-(1-ease(state.open))*(panelWidth(ctx)+safe.right+8))
end

---@return JournalBookState
function B.State(ctx)
    local state=ctx.journalBook
    if not state then
        state={open=0,target=0,settled=true,panel=false,page=false,
            story=ctx.storyId or false,entry=false,closing=false,art=false}
        ctx.journalBook=state
    end
    return state --[[@as JournalBookState]]
end
function B.Progress(ctx)
    local state=ctx.journalBook --[[@as JournalBookState?]]
    return state and state.open or 0
end
function B.Settled(ctx)
    local state=ctx.journalBook --[[@as JournalBookState?]]
    return not state or state.settled
end
function B.Open(ctx)
    local state=B.State(ctx)
    if state.closing then return state end
    state.target=1;state.settled=false
    if ctx.storyId then state.story=ctx.storyId end
    return state
end
-- 切场景/换面板/销毁时复位，别把动画状态带进下一次打开。
function B.Reset(ctx)
    local state=ctx.journalBook --[[@as JournalBookState?]]
    if not state then return end
    state.open=0;state.target=0;state.settled=true;state.panel=false;state.page=false
    state.story=false;state.entry=false;state.closing=false
    state.art=false
end
-- 关闭按钮先滑出再真正关面板。
function B.RequestClose(ctx)
    local state=ctx.journalBook --[[@as JournalBookState?]]
    if not state or state.open<=0 then return end
    state.closing=true;state.target=0;state.settled=false
end
function B.Update(ctx,dt)
    local state=ctx.journalBook --[[@as JournalBookState?]]
    if not state then return end
    local step=(dt or 0)
    -- Yoga bounds become available after mounting; keep art and reading region aligned.
    if state.art and state.art.body.GetAbsoluteLayout then
        local a=state.art
        local bounds=a.body:GetAbsoluteLayout()
        if bounds.w>0 and bounds.h>0 and (a.lastW~=bounds.w or a.lastH~=bounds.h) then
            a.lastW=bounds.w;a.lastH=bounds.h
            local layout=Art.Fit(bounds.w,bounds.h)
            for _,key in ipairs({"cloth","book","content","title","tabs","flowers","grass","lavender"}) do
                local r=layout[key]
                Widget.SetStyle(a[key],{left=r.x,top=r.y,width=r.w,height=r.h})
            end
        end
    end
    if state.settled then return end
    local amount=step/B.AnimationSeconds
    if state.target>=state.open then state.open=math.min(state.target,state.open+amount)
    else state.open=math.max(state.target,state.open-amount) end
    if state.open==state.target then state.settled=true end
    if state.panel then Widget.SetStyle(state.panel,{right=panelRight(ctx,state)}) end
    if state.closing and state.settled then
        state.closing=false
        ctx.Close()
    end
end
-- 切故事立即换页，避免移动端折页遮住目录。
function B.Select(ctx,storyId)
    local state=B.State(ctx)
    if not storyId or state.story==storyId then return end
    state.story=storyId;state.entry=false
    ctx.storyId=storyId
    ctx.model.dirty=true
end
function B.OpenEntry(ctx,fragmentId)
    local state=B.State(ctx)
    if not fragmentId or not state.story then return end
    local page=ctx.session.queries.GetJournalPage(state.story)
    if not page.ok then ctx.model.Notify(page);return end
    for _,entry in ipairs(B.Entries(page.value)) do
        if entry.fragmentId==fragmentId and entry.collected and entry.transactionId then
            ctx.model.selectedAttempt=entry.transactionId
            local open=ctx.Push or ctx.Open
            open("attempt")
            return
        end
    end
end
function B.CloseEntry(ctx)
    local state=B.State(ctx)
    if not state.entry then return end
    state.entry=false
    ctx.model.dirty=true
end

-- 分支目录与实际记录合成列表条目；未收集的分支保留空位。
-- 纯函数，便于无头测试；不读 ctx、不写快照。
function B.Entries(page)
    local byBranch={}
    for _,outcome in ipairs(page and page.outcomes or {}) do
        local attempts=outcome.attempts or {}
        local latest=attempts[#attempts]
        if latest then
            local slot=byBranch[outcome.branchFragmentId]
            if not slot or (latest.day or 0)>=(slot.day or 0) then
                byBranch[outcome.branchFragmentId]={transactionId=latest.transactionId,day=latest.day,stars=latest.stars,text=latest.text,
                    recipeSummary=latest.recipeSummary,count=0}
            end
            byBranch[outcome.branchFragmentId].count=byBranch[outcome.branchFragmentId].count+#attempts
        end
    end
    local rows={}
    for _,branch in ipairs(page and page.branches or {}) do
        local hit=byBranch[branch.fragmentId]
        rows[#rows+1]={fragmentId=branch.fragmentId,shortName=branch.shortName or false,collected=hit~=nil,
            transactionId=hit and hit.transactionId or false,day=hit and hit.day or false,stars=hit and hit.stars or false,text=hit and hit.text or false,
            attemptCount=hit and hit.count or 0,recipeSummary=hit and hit.recipeSummary or false}
    end
    return rows
end

local function queryError(ctx)
    local result=ctx.session.queries.GetJournalStories()
    if result.ok then return nil end
    return result.error.message or "记录暂时读不到"
end

local function text(parent,value,size,id,color,style)
    local props={id=id,text=tostring(value or ""),fontFamily=Harbor.fontFamily,fontSize=size or 15,
        fontColor=color or ink,whiteSpace="normal",lineHeight=1.6,flexShrink=0,pointerEvents="none",alignSelf="stretch"}
    for key,v in pairs(style or {}) do props[key]=v end
    local label=UI.Label(props)
    parent:AddChild(label);return label
end
local function storyLabel(row)
    if row.received then return row.title end
    if B.ShowLockedTitles then return row.title end
    return "？？？"
end
local function branchLabel(entry)
    if entry.collected or B.ShowLockedTitles then return entry.shortName or "未命名分支" end
    return "？？？"
end
local function metaText(entry)
    if not entry.collected then return "未收集" end
    local parts={"第 "..tostring(entry.day or 1).." 天"}
    if entry.stars then parts[#parts+1]=tostring(entry.stars).." 星" end
    if entry.attemptCount>1 then parts[#parts+1]="试做 "..tostring(entry.attemptCount).." 次" end
    return table.concat(parts," · ")
end

-- The source has transparent top/bottom margins and a folded right end.
-- Keep handwriting centered on the broad paper face, independently of Button defaults.
local function indexTab(ctx,state,parent,row,active,slot,origin)
    local label=storyLabel(row)
    -- A compact index identifies the story; the page heading keeps its full title.
    local short=label
    if row.received and utf8.len(label)>4 then short=utf8.char(utf8.codepoint(label,1,utf8.offset(label,3)-1)) end
    local button=UI.Button {id="bookTab_"..row.sourceLetterId,text="",
        position="absolute",left=slot.x-origin.x,top=slot.y-origin.y,width=slot.w,height=slot.h,
        fontFamily=Harbor.fontFamily,fontSize=12,fontWeight="normal",
        backgroundImage=Art.tabImage,backgroundFit="fill",
        backgroundImageOpacity=not row.received and .38 or (active and 1 or .72),
        hoverBackgroundImageOpacity=1,pressedBackgroundImageOpacity=.82,disabledBackgroundImageOpacity=.38,
        backgroundColor={0,0,0,0},hoverBackgroundColor={0,0,0,0},pressedBackgroundColor={0,0,0,0},
        variantBackgroundGradient={},variantHoverBackgroundGradient={},variantPressedBackgroundGradient={},
        borderWidth=0,hoverBorderWidth=0,pressedBorderWidth=0,borderRadius=0,boxShadow=false,glowShadow={},
        textColor=active and ink or inkFaint,disabledTextColor=inkFaint,
        paddingTop=0,paddingRight=0,paddingBottom=0,paddingLeft=0,pressedPadding=0,
        disabled=not row.received,
        onClick=function() if row.received then B.Select(ctx,row.sourceLetterId,label) end end}
    button:AddChild(UI.Label {id="bookTabText_"..row.sourceLetterId,text=short,
        position="absolute",left="7%",top="13%",width="72%",height="73%",fontFamily=Harbor.fontFamily,
        fontSize=11,lineHeight=1,textAlign="center",verticalAlign="middle",whiteSpace="nowrap",fontColor=active and ink or inkFaint,
        flexShrink=0,pointerEvents="none"})
    parent:AddChild(button)
    return button
end

-- 目录：一行一支，含未收集空位。
local function renderCatalog(ctx,page,host,entries)
    local width=host.props.width or 180
    local measured=UI.MeasureTextWidth and UI.MeasureTextWidth(page.title,Theme.FontSize(18),Harbor.fontFamily) or 0
    if measured<=0 then measured=(utf8.len(page.title) or 0)*18 end
    text(host,page.title,math.min(18,18*math.max(1,width-4)/math.max(1,measured)),"bookStoryTitle",nil,
        {whiteSpace="nowrap",lineHeight=1.25,maxLines=1})
    local collected=0
    for _,entry in ipairs(entries) do if entry.collected then collected=collected+1 end end
    text(host,"已收集 "..tostring(collected).." / "..tostring(#entries).." 支",12,"bookProgress",inkFaint)
    local list=UI.ScrollView {id="bookEntryList",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,scrollY=true,
        showScrollbar=true,gap=6,minHeight=0,pointerEvents="box-none"}
    host:AddChild(list)
    for index,entry in ipairs(entries) do
        local row=UI.Panel {id="bookEntry_"..entry.fragmentId,width="100%",gap=2,padding={7,0},
            minHeight=44,flexShrink=0,flexDirection="column"}
        local clickable=entry.collected
        row.props.onClick=clickable and function() B.OpenEntry(ctx,entry.fragmentId) end or function() end
        list:AddChild(row)
        text(row,tostring(index)..". "..branchLabel(entry),16,"bookEntryName_"..entry.fragmentId,
            entry.collected and ink or inkFaint)
        text(row,metaText(entry),12,"bookEntryMeta_"..entry.fragmentId,inkFaint)
        row:AddChild(UI.Panel {width="100%",height=1,marginTop=5,backgroundColor={130,104,74,65},pointerEvents="none"})
    end
    return list
end

-- 详情：一条分支的后续全文与当时用料。
local function renderEntry(ctx,state,page,host,entry)
    local back=Harbor.Button {id="bookEntryBack",text="返回目录",width="100%",minHeight=40,fontSize=14,
        onClick=function() B.CloseEntry(ctx) end}
    host:AddChild(back)
    text(host,branchLabel(entry),19,"bookEntryTitle")
    text(host,metaText(entry),13,"bookEntryMeta",inkFaint)
    local scroll=UI.ScrollView {id="bookEntryBody",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,scrollY=true,
        showScrollbar=true,minHeight=0,paddingRight=3,pointerEvents="box-none"}
    host:AddChild(scroll)
    text(scroll,entry.text or "这条后续还没有正文。",16,"bookEntryText")
    local recipe=entry.recipeSummary
    if recipe and recipe.main then
        text(scroll,"当时用料",14,"bookEntryRecipeTitle",inkFaint)
        text(scroll,"主词 "..tostring(recipe.main.text or "—"),14,"bookEntryRecipeMain",inkFaint)
        for index,aux in ipairs(recipe.aux or {}) do
            text(scroll,"辅词 "..tostring(index).." "..tostring(aux.text or "—"),14,"bookEntryRecipeAux"..index,inkFaint)
        end
        for index,row in ipairs(recipe.ingredients or {}) do
            text(scroll,tostring(row.name or "原料").." × "..tostring(row.quantity or 1),14,"bookEntryRecipeIng"..index,inkFaint)
        end
    end
    return scroll
end

function B.Render(ctx,overlay)
    local state=B.State(ctx)
    local safe=insets(ctx)
    local width=panelWidth(ctx)
    local panel=UI.Panel {id="activePanel",position="absolute",right=panelRight(ctx,state),top=safe.top+12,
        width=width,height=viewportHeight(ctx)-(safe.top+12)-(safe.bottom+12),padding=0,
        overflow="hidden",pointerEvents="auto",onClick=function() end}
    overlay:AddChild(panel)
    state.panel=panel
    local header=UI.Panel {id="journalBookHeader",position="absolute",left=8,top=ctx.workbench and 58 or 8,width=56,height=48,flexShrink=0,flexDirection="row",
        alignItems="center",gap=8,pointerEvents="box-none"}
    -- 交给 UpdateChrome 按主机胶囊与安全区加内边距（和其它右栏面板同一路径）。
    ctx.panelHeader=header
    header:AddChild(Harbor.Button {id="closePanel",text="×",width=44,height=48,minHeight=44,fontSize=22,
        onClick=function() B.RequestClose(ctx) end})
    local noticeArea=UI.ScrollView {id="journalBookMessageArea",width="100%",height=40,flexShrink=0,scrollY=true,
        visible=false,paddingLeft=8,paddingRight=8,pointerEvents="box-none"}
    ctx.panelNotice=text(noticeArea,ctx.model.message,13,"panelMessage",inkFaint);ctx.panelNoticeArea=noticeArea

    local body=UI.Panel {id="journalBookBody",position="absolute",left=0,top=0,width="100%",height="100%",
        pointerEvents="box-none"}
    panel:AddChild(body)
    local layout=Art.Fit(width,panel.props.height)
    local function box(r) return {position="absolute",left=r.x,top=r.y,width=r.w,height=r.h} end
    local cloth=PanelArt.Image(body,"bookCloth",layout.cloth)
    local frame=PanelArt.Image(body,"bookArtFrame",layout.book)
    local pageProps=box(layout.content)
    pageProps.id="bookPage";pageProps.gap=6;pageProps.overflow="hidden";pageProps.onClick=function() end
    local page=UI.Panel(pageProps)
    body:AddChild(page)
    local grass=PanelArt.Image(body,"bookDriedGrass",layout.grass)
    local flowers=PanelArt.Image(body,"bookDriedFlowers",layout.flowers)
    local lavender=PanelArt.Image(body,"bookLavender",layout.lavender)
    local titleProps=box(layout.title)
    titleProps.id="journalBookTitle";titleProps.text="记录书";titleProps.fontFamily=Harbor.fontFamily
    titleProps.fontSize=13;titleProps.fontColor=inkFaint;titleProps.verticalAlign="middle";titleProps.pointerEvents="none"
    local title=UI.Label(titleProps);body:AddChild(title)
    local tabProps=box(layout.tabs)
    tabProps.id="bookTabs";tabProps.scrollY=true;tabProps.gap=5;tabProps.pointerEvents="box-none"
    local tabs=UI.ScrollView(tabProps);body:AddChild(tabs)
    state.art={body=body,cloth=cloth,book=frame,content=page,title=title,tabs=tabs,flowers=flowers,grass=grass,lavender=lavender,
        lastW=width,lastH=panel.props.height}
    state.page=page
    -- Chrome is above all art, without shrinking the designer canvas below it.
    panel:AddChild(header)
    Widget.SetStyle(noticeArea,{position="absolute",left=8,right=8,top=58})
    panel:AddChild(noticeArea)
    local stories=ctx.session.queries.GetJournalStories()
    if not stories.ok then
        text(page,"记录暂时读不到："..tostring(stories.error.message or ""),15,"bookQueryError",inkFaint)
        return
    end
    local rows=stories.value
    local active=false
    for _,row in ipairs(rows) do
        if not active and state.story==row.sourceLetterId then active=true end
    end
    if not active then
        state.story=false;state.entry=false
        for _,row in ipairs(rows) do
            if not state.story and row.received then state.story=row.sourceLetterId end
        end
        ctx.storyId=state.story
    end
    local indexContent=UI.Panel {width="100%",height=math.max(layout.tabs.h,(#rows*55+20)*layout.scale),pointerEvents="box-none"}
    tabs:AddChild(indexContent)
    for i,row in ipairs(rows) do
        local slot=layout.tabSlots[i]
        if not slot then
            local last=layout.tabSlots[#layout.tabSlots]
            slot={x=last.x,y=last.y+(i-#layout.tabSlots)*55*layout.scale,w=last.w,h=last.h}
        end
        indexTab(ctx,state,indexContent,row,row.sourceLetterId==state.story,slot,layout.tabs)
    end
    if not state.story then
        text(page,"还没有收到任何故事。剪开漂流瓶里的信，这里会记下每一支后续。",16,"bookEmpty",inkFaint)
        return
    end
    local active_row=false --[[@as table|false]]
    for _,row in ipairs(rows) do if row.sourceLetterId==state.story then active_row=row end end
    if active_row and not active_row.received then
        text(page,"这一页还空着。收到这封信以后，它记的分支会出现在这里。",16,"bookLocked",inkFaint)
        return
    end
    local result=ctx.session.queries.GetJournalPage(state.story)
    if not result.ok then
        text(page,"这一页暂时读不到："..tostring(result.error.message or ""),15,"bookPageError",inkFaint)
        return
    end
    local pageData=result.value
    local entries=B.Entries(pageData)
    if state.entry then
        local selected=false --[[@as table|false]]
        for _,entry in ipairs(entries) do if entry.fragmentId==state.entry then selected=entry end end
        if selected and selected.collected then
            renderEntry(ctx,state,pageData,page,selected)
            return
        end
        state.entry=false
    end
    renderCatalog(ctx,pageData,page,entries)
end

return B
