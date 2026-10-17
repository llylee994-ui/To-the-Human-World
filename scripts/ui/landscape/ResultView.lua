-- Stored story reading. Rating, prose and decisions use the original attempt only.
local UI=require "urhox-libs/UI"
local H=require "ui.landscape.HarborStyle"
local Hud=require "ui.landscape.HudLayout"
local Motion=require "ui.landscape.LetterMotion"
local Widget=require "urhox-libs/UI/Core/Widget"
local Style=require "ui.landscape.StoryStyle"
local R={}
local ink={72,55,38,255}
function R.Layout(viewport,safe,menu)
    local phone=viewport.h<620 or viewport.w/viewport.h>2
    local width=math.min(phone and 1400 or 960,viewport.w-safe.left-safe.right-32)
    local left=safe.left+(viewport.w-safe.left-safe.right-width)/2
    local top=safe.top+12
    local closeRight=10
    if menu then
        local r={x=left+width-54,y=top+8,w=44,h=44}
        local offsets=Hud.Compute(r,viewport,menu,44)
        if offsets.top>0 then closeRight=math.max(10,left+width-menu.left*viewport.w+12) end
    end
    local height=viewport.h-safe.bottom-12-top
    local compact=height<620
    return {left=left,top=top,width=width,height=height,compact=compact,closeRight=closeRight,
        paddingX=compact and 32 or 48,paddingTop=compact and 14 or 24,paddingBottom=compact and 14 or 24,
        headerHeight=compact and 76 or 112,actionsHeight=compact and 58 or 66}

end
local function text(parent,value,size,id,props)
    local p={id=id,text=tostring(value or ""),fontFamily=H.fontFamily,fontSize=size or 16,
        whiteSpace="normal",lineHeight=1.7,flexShrink=0,fontColor=ink,pointerEvents="none"}
    for k,v in pairs(props or {}) do p[k]=v end
    local label=UI.Label(p);parent:AddChild(label);return label
end
function R.Render(ctx,overlay,history)
    local summary=ctx.session.queries.GetOrderSummary()
    local pending=summary.ok and summary.value.pending
    local id=history and ctx.model.selectedAttempt or pending and pending.transactionId
    local result=id and ctx.session.queries.GetAttempt(id)
    local record=result and result.ok and result.value
    local safe=ctx.safeInsets or {left=0,right=0,top=0,bottom=0}
    local viewport=ctx.viewport or {w=1280,h=720}
    local layout=R.Layout(viewport,safe,ctx.menuRect)
    local compact=layout.compact
    local panel=H.Paper {id="activePanel",position="absolute",left=layout.left,
        width=layout.width,top=layout.top,height=layout.height,compact=compact,
        paddingLeft=layout.paddingX,paddingRight=layout.paddingX,paddingTop=layout.paddingTop,paddingBottom=layout.paddingBottom,
        pointerEvents="auto",onClick=function() end}
    overlay:AddChild(panel)
    local motion=ctx.resultMotion
    if not motion or motion.id~=id then motion={id=id,motion=Motion.New(),panel=panel};ctx.resultMotion=motion
    else motion.panel=panel end
    panel:AddChild(H.Button {id="closePanel",text="×",position="absolute",top=8,right=layout.closeRight,width=44,height=44,minHeight=44,fontSize=22,onClick=ctx.Close})
    local header=UI.Panel {id="resultHeader",width="100%",height=layout.headerHeight,flexShrink=0,pointerEvents="box-none"}
    panel:AddChild(header)
    local source=record and ctx.content.GetLetter(record.sourceLetterId)
    local followup=record and ctx.content.GetLetter(record.followup.letterId)
    local npc=source and ctx.content.GetNpc(source.senderId)
    local heading=UI.Panel {width="100%",height="100%",paddingRight=compact and 126 or 180,pointerEvents="box-none"}
    header:AddChild(heading)
    text(heading,history and "试做记录 · 后续故事" or "后续故事",compact and 12 or 13,"resultSection",{fontColor={143,101,54,255},height=compact and 20 or 26})
    text(heading,followup and followup.title or source and source.title or "这锅药带来的回响",compact and 23 or 27,"resultTitle",{lineHeight=1.3,paddingTop=3,paddingBottom=6})
    local main=record and record.recipeDisplay and record.recipeDisplay.main
    if not compact then text(heading,(npc and npc.name or "寄信人")..(main and "  ·  主词「"..main.text.."」" or ""),13,"resultSender",{fontColor={126,108,82,255},lineHeight=1.5}) end
    if record then header:AddChild(Style.Seal(record.rating.stars,compact and .75 or 1)) end
    local message=UI.Label {id="panelMessage",text="",fontFamily=H.fontFamily,fontSize=13,
        fontColor={128,55,31,255},whiteSpace="normal",flexShrink=0,pointerEvents="none"}
    local notice=UI.ScrollView {position="absolute",left=layout.paddingX,right=layout.paddingX,bottom=layout.actionsHeight+layout.paddingBottom,zIndex=4,height=44,flexShrink=0,scrollY=true,visible=false,children={message}}
    panel:AddChild(notice);ctx.panelNotice=message;ctx.panelNoticeArea=notice
    local scroll=UI.ScrollView {id="resultScroll",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,scrollY=true,
        showScrollbar=true,scrollbarInteractive=true,paddingRight=12,pointerEvents="auto"}
    panel:AddChild(scroll)
    if not record then text(scroll,result and result.error.message or "当前没有待处理的试做结果。",17);return end
    local echo=UI.Panel {id="resultEcho",width="100%",flexShrink=0,padding={6,12},marginBottom=12,pointerEvents="none"}
    function echo:Render(vg)
        local r=self:GetAbsoluteLayout()
        nvgBeginPath(vg);nvgMoveTo(vg,r.x+3,r.y+2);nvgLineTo(vg,r.x+r.w-3,r.y)
        nvgLineTo(vg,r.x+r.w,r.y+r.h-4);nvgLineTo(vg,r.x+1,r.y+r.h);nvgClosePath(vg)
        nvgFillColor(vg,nvgRGBA(188,204,201,145));nvgFill(vg)
        nvgBeginPath(vg);nvgMoveTo(vg,r.x+3,r.y+8);nvgLineTo(vg,r.x+3,r.y+r.h-8)
        nvgStrokeColor(vg,nvgRGBA(111,135,128,140));nvgStrokeWidth(vg,2);nvgStroke(vg)
    end
    scroll:AddChild(echo)
    text(echo,"药效回响 · "..record.rating.feedback,16,"resultFeedback",{fontColor={58,80,78,255},lineHeight=1.6})
    text(scroll,record.followup.renderedText,compact and 18 or 20,history and "historyBody" or "pendingBody",{lineHeight=1.55,paddingBottom=16})
    if history then
        text(scroll,"第 "..record.attemptDay.." 天 · "..({pending="待处理",reset="已重置",shipped="已发货"})[record.status],13)
        if record.recipeDisplay then
            local recipe=record.recipeDisplay
            if recipe.main then text(scroll,"主词 · "..recipe.main.text,13) end
            for _,card in ipairs(recipe.aux or {}) do text(scroll,"辅词 · "..card.text,13) end
            for _,item in ipairs(recipe.ingredients or {}) do text(scroll,item.name.." × "..item.quantity,13) end
        end
        return
    end
    local actions=UI.Panel {id="resultActions",width="100%",flexShrink=0,paddingTop=compact and 10 or 14,height=layout.actionsHeight,
        flexDirection="row",gap=12,justifyContent="center",pointerEvents="box-none"}
    panel:AddChild(actions)
    actions:AddChild(Style.Button({id="resetOrder",text="重新调配",width="38%",minWidth=0,height=compact and 44 or 52,minHeight=44,fontSize=16,
        disabled=not summary.value.actions.Reset.enabled,onClick=function()
            if ctx.model.Resolve(false).ok then ctx.Navigate("brew") end
        end},"secondary"))
    actions:AddChild(Style.Button({id="confirmOrder",text="确认发货",width="56%",minWidth=0,height=compact and 44 or 52,minHeight=44,fontSize=18,
        disabled=not summary.value.actions.Confirm.enabled,onClick=function()
            if ctx.model.Resolve(true).ok then ctx.storyId=record.sourceLetterId;ctx.Open("journal") end
        end}))
end
function R.Update(ctx,dt,focused)
    local state=ctx.resultMotion
    if not state or (ctx.panel~="result" and ctx.panel~="attempt") then return end
    state.motion.Update(dt,focused)
    local pose=state.motion.OpenPose()
    Widget.SetStyle(state.panel,{translateY=pose.translateY,opacity=pose.opacity})
end
return R
