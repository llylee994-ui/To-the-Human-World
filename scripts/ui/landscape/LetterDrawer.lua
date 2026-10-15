-- 独立来信抽屉：方形俯视素材、下滑开合；所有业务仍走同一 ctx.Read。
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local Harbor=require "ui.landscape.HarborStyle"
local Art=require "ui.landscape.LetterDrawerArt"
local D={AnimationSeconds=.34,HeightRatio=.94}

---@class LetterDrawerState
---@field open number
---@field target number
---@field settled boolean
---@field panel Widget|false
---@field closing boolean

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
local function panelSize(ctx)
    local safe=insets(ctx)
    return math.max(1,math.floor(math.min(viewportWidth(ctx)-safe.left-safe.right-24,
        (viewportHeight(ctx)-safe.top-safe.bottom)*D.HeightRatio)))
end
local function panelTop(ctx,state)
    return math.floor(insets(ctx).top-(1-ease(state.open))*(panelSize(ctx)+18))
end
---@return LetterDrawerState
function D.State(ctx)
    if not ctx.letterDrawer then ctx.letterDrawer={open=0,target=0,settled=true,panel=false,closing=false} end
    return ctx.letterDrawer --[[@as LetterDrawerState]]
end
function D.Progress(ctx) return ctx.letterDrawer and ctx.letterDrawer.open or 0 end
function D.Settled(ctx) return not ctx.letterDrawer or ctx.letterDrawer.settled end
function D.Open(ctx)
    local state=D.State(ctx)
    if not state.closing then state.target=1;state.settled=false end
    return state
end
function D.Reset(ctx)
    local state=ctx.letterDrawer --[[@as LetterDrawerState?]]
    if not state then return end
    state.open=0;state.target=0;state.settled=true;state.panel=false;state.closing=false
end
function D.RequestClose(ctx)
    local state=ctx.letterDrawer --[[@as LetterDrawerState?]]
    if not state or state.closing then return end
    if state.open<=0 then ctx.Close();return end
    state.closing=true;state.target=0;state.settled=false
end
function D.Update(ctx,dt)
    local state=ctx.letterDrawer --[[@as LetterDrawerState?]]
    if not state or state.settled then return end
    local step=(dt or 0)/D.AnimationSeconds
    if state.target>=state.open then state.open=math.min(state.target,state.open+step)
    else state.open=math.max(state.target,state.open-step) end
    if state.open==state.target then state.settled=true end
    if state.panel then Widget.SetStyle(state.panel,{top=panelTop(ctx,state)}) end
    if state.closing and state.settled then state.closing=false;ctx.Close() end
end
function D.StatusText(row)
    if not row.read then return "未读" end
    local remaining=tonumber(row.remainingCutCount) or 0
    return remaining>0 and ("可剪 "..remaining.." 处") or "已读"
end
local function text(parent,value,size,id,color)
    local label=UI.Label {id=id,text=tostring(value or ""),fontFamily=Harbor.fontFamily,fontSize=size or 16,
        fontColor=color or Art.Colors.ink,whiteSpace="normal",lineHeight=1.3,flexShrink=0,pointerEvents="none",alignSelf="stretch",zIndex=3}
    parent:AddChild(label);return label
end
local function box(parent,id,r,props)
    local p={id=id,position="absolute",left=r.x,top=r.y,width=r.w,height=r.h,pointerEvents="none"}
    for key,value in pairs(props or {}) do p[key]=value end
    local node=UI.Panel(p);parent:AddChild(node);return node
end
local function card(ctx,row,allowed,layout,index)
    local columns=layout.card.columns
    local node=UI.Panel {id="read_"..row.letterInstanceId,position="absolute",
        left=((index-1)%columns)*(layout.card.w+layout.card.gap),
        top=math.floor((index-1)/columns)*layout.card.rowStep,
        width=layout.card.w,height=layout.card.h,flexShrink=0,
        onClick=allowed and function() ctx.Read(row.letterInstanceId) end or nil}
    local _,paper=Art.Image(node,"letterDrawerCardArt_"..row.letterInstanceId,row.read and "read" or "unread",
        {x=0,y=0,w=layout.card.w,h=layout.card.h},false,allowed and 1 or .5)
    local title=text(node,row.title,layout.card.w<190 and 12 or 14,"letterDrawerCardTitle_"..row.letterInstanceId)
    Widget.SetStyle(title,{position="absolute",left=paper.x+paper.w*.07,top=paper.y+paper.h*.10,
        width=paper.w*.72,height=paper.h*.53,maxLines=2,lineHeight=1.12})
    local sender=text(node,row.senderName,11,"letterDrawerCardSender_"..row.letterInstanceId,Art.Colors.muted)
    Widget.SetStyle(sender,{position="absolute",left=paper.x+paper.w*.07,top=paper.y+paper.h*.69,
        width=paper.w*.42,height=paper.h*.25,maxLines=1,whiteSpace="nowrap"})
    local status=text(node,D.StatusText(row),10,"letterDrawerCardState_"..row.letterInstanceId,Art.Colors.muted)
    Widget.SetStyle(status,{position="absolute",left=paper.x+paper.w*.50,top=paper.y+paper.h*.69,
        width=paper.w*.28,height=paper.h*.25,textAlign="right",maxLines=1,whiteSpace="nowrap"})
    return node
end
---@param overlay Widget
function D.Render(ctx,overlay)
    local state=D.State(ctx)
    local safe=insets(ctx)
    local size=panelSize(ctx)
    local left=safe.left+(viewportWidth(ctx)-safe.left-safe.right-size)/2
    local panel=UI.Panel {id="activePanel",position="absolute",left=left,top=panelTop(ctx,state),
        width=size,height=size,padding=0,overflow="hidden",pointerEvents="auto",onClick=function() end}
    overlay:AddChild(panel);state.panel=panel
    local layout=Art.Fit(size,size)
    Art.Reference(panel,"letterDrawerBody","body",layout)
    box(panel,"letterDrawerCavity",layout.cavity,{overflow="hidden"})
    Art.Reference(panel,"letterDrawerScrolls","scrolls",layout)
    Art.Reference(panel,"letterDrawerFlowersTop","flowersTop",layout)
    Art.Reference(panel,"letterDrawerFlowersBottom","flowersBottom",layout)
    Art.Reference(panel,"letterDrawerPlate","plate",layout)
    local plate=box(panel,"letterDrawerTitleArea",layout.plate,{alignItems="center",justifyContent="center",zIndex=3})
    local title=text(plate,"来信抽屉",size<460 and 14 or 17,"letterDrawerTitle")
    title.props.textAlign="center"
    local function artButton(id,key,r)
        local button=box(panel,id,{x=r.x,y=r.y,w=math.max(44,r.w),h=math.max(44,r.h)},
            {pointerEvents="auto",zIndex=4,onClick=function() D.RequestClose(ctx) end})
        Art.Reference(button,id.."Art",key,layout,r)
    end
    artButton("closePanel","close",layout.close)
    local noticeArea=UI.ScrollView {id="letterDrawerMessageArea",position="absolute",left=layout.hint.x,top=layout.hint.y,
        width=layout.hint.w,height=layout.hint.h,zIndex=11,flexShrink=0,scrollY=true,visible=false,
        paddingLeft=8,paddingRight=8,pointerEvents="box-none"}
    ctx.panelNotice=text(noticeArea,ctx.model.message,13,"panelMessage",Art.Colors.light);ctx.panelNoticeArea=noticeArea
    panel:AddChild(noticeArea)
    box(panel,"letterDrawerHandle",layout.handle) -- 拉手已包含在抽屉图片中。
    artButton("letterDrawerBack","back",layout.back)
    local result=ctx.session.queries.GetLetters()
    if not result.ok then text(panel,result.error.message,16,"letterDrawerQueryError",Art.Colors.light);return end
    local rows=result.value
    local action=ctx.model.Action("ReadLetter")
    local hint=ctx.choosingLetter and "请选择要放到桌面阅读的信件。" or false
    if not hint then
        for _,row in ipairs(rows) do if not row.read and not action.enabled then hint=action.message;break end end
    end
    if #rows>0 or (hint and hint~="") then
        local label=text(panel,hint or ("已收 "..#rows.." 封来信 · 点击信纸阅读"),13,"letterDrawerHint",Art.Colors.light)
        Widget.SetStyle(label,{position="absolute",left=layout.hint.x+8,top=layout.hint.y+4,width=layout.hint.w-16})
    end
    local scroll=UI.ScrollView {id="letterDrawerCards",position="absolute",left=layout.cards.x,top=layout.cards.y,
        width=layout.cards.w,height=layout.cards.h,scrollY=true,scrollX=false,showScrollbar=false,bounces=false,pointerEvents="auto",zIndex=3}
    panel:AddChild(scroll)
    local row=UI.Panel {id="letterDrawerRows",width="100%",height=layout.cards.h,pointerEvents="box-none"}
    scroll:AddChild(row)
    for index,entry in ipairs(rows) do row:AddChild(card(ctx,entry,entry.read or action.enabled,layout,index)) end
    local contentHeight=math.max(layout.cards.h,math.ceil(#rows/layout.card.columns)*layout.card.rowStep)
    Widget.SetStyle(row,{height=contentHeight})
    Art.Image(panel,"letterDrawerRail","track",layout.rail,true)
    local thumbHeight=math.max(24,layout.rail.h*layout.cards.h/contentHeight)
    local thumb=Art.Image(panel,"letterDrawerThumb","thumb",{x=layout.rail.x+2,y=layout.rail.y+3,
        w=math.max(4,layout.rail.w-4),h=math.max(8,thumbHeight-6)},true)
    local maxScroll=math.max(0,contentHeight-layout.cards.h)
    thumb:SetVisible(maxScroll>0)
    scroll.props.onScroll=function(_,_,y)
        local fraction=maxScroll>0 and math.max(0,math.min(1,y/maxScroll)) or 0
        Widget.SetStyle(thumb,{top=layout.rail.y+3+fraction*(layout.rail.h-thumbHeight)})
    end
    if #rows==0 then text(row,"还没有收到信件。可点击捞网前往海边捕捞。",15,"lettersEmpty",Art.Colors.light) end
end
return D
