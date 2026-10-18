local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local Art=require "ui.landscape.CalendarArt"
local Motion=require "ui.landscape.CalendarMotion"
local Responsive=require "ui.landscape.Responsive"
local C={}
local ink={74,43,21,255}
local function rect(id,x,y,w,h)
    return {id=id,position="absolute",left=x,top=y,width=w,height=h,pointerEvents="none"}
end
local function text(parent,id,value,size,x,y,w,h,color)
    local p=rect(id,x,y,w,h)
    p.text=value;p.fontFamily="story";p.fontSize=size;p.fontColor=color or ink
    p.textAlign="center";p.verticalAlign="middle";p.whiteSpace="nowrap"
    p.autoFitText=true;p.minFontSize=8
    local node=UI.Label(p);parent:AddChild(node);return node
end
local function button(parent,id,value,size,x,y,w,h,callback)
    local p=rect(id,x,y,w,math.max(44,h))
    p.text=value;p.fontFamily="story";p.fontSize=size;p.onClick=callback;p.pointerEvents="auto"
    p.padding=0;p.paddingHorizontal=0;p.borderWidth=0;p.borderRadius=0;p.pressedPadding=0
    p.autoFitText=true;p.minFontSize=10
    p.textColor=ink;p.disabledTextColor={121,110,91,220}
    p.backgroundColor={0,0,0,0};p.hoverBackgroundColor={239,210,160,65}
    p.pressedBackgroundColor={189,149,92,65};p.disabledBackgroundColor={0,0,0,0}
    p.boxShadow=false;p.hoverBoxShadow=false;p.pressedBoxShadow=false;p.disabledBoxShadow=false;p.glowShadow={}
    p.variantBackgroundGradient={};p.variantHoverBackgroundGradient={};p.variantPressedBackgroundGradient={};p.variantDisabledBackgroundGradient={}
    local node=UI.Button(p);parent:AddChild(node);return node
end
local function date(parent,prefix,day,size)
    text(parent,prefix.."Prefix","第",size*.049,size*.345,size*.445,size*.10,size*.12)
    text(parent,prefix.."Day",tostring(day),size*(#tostring(day)>2 and .10 or .16),size*.445,size*.365,size*.245,size*.245)
    text(parent,prefix.."Suffix","天",size*.049,size*.705,size*.445,size*.10,size*.12)
end
local function shipped(data)
    -- Use saved confirmations; UI eligibility alone can also be blocked by a draft.
    for _,record in pairs(data.live.orders.confirmedById) do
        if record.deliveryDay==data.live.gameFlow.day then return true end
    end
    return false
end
---@param ctx table
function C.New(ctx)
    local data=assert(ctx.model.Refresh())
    local day,revision=data.live.gameFlow.day,data.revision
    local progress=data.chapter and ctx.session.queries.GetReleaseProgress()
    local final=progress and progress.ok and progress.value.canClose or false
    local apprentice=final and progress.value.canApprentice
    local action=ctx.model.Action("NextDay")
    local metrics=Responsive.Metrics(ctx.viewport,ctx.safeInsets)
    local fit=Art.Layout(ctx.viewport,ctx.safeInsets)
    if metrics.short then
        local side=math.min(metrics.h-16,metrics.w*.48)
        fit={x=metrics.x+8,y=metrics.y+8,w=side,h=side,noteX=metrics.x+side+20,noteY=metrics.y+20,
            noteW=math.max(1,metrics.w-side-32),noteH=math.max(44,metrics.h-180)}
    end
    local size=fit.w
    local root=UI.Panel {id="calendarOverlay",position="absolute",left=0,top=0,width="100%",height="100%",pointerEvents="box-none",zIndex=1}
    local canvas=UI.Panel(rect("calendarCanvas",fit.x,fit.y,size,size));canvas.props.pointerEvents="box-none";root:AddChild(canvas)
    local api={root=root,motion=Motion.New(),fromDay=day,toDay=day,disposed=false --[[@as boolean]],fit=fit,final=final}
    ctx.calendar=api
    local base=UI.Panel(rect("calendarBase",0,0,size,size));base.props.backgroundImage=Art.path;base.props.backgroundFit="fill";canvas:AddChild(base)
    local nextSheet=UI.Panel(rect("calendarTomorrow",0,0,size,size));nextSheet:SetVisible(false);canvas:AddChild(nextSheet)
    date(nextSheet,"calendarNext",day+1,size)
    text(nextSheet,"calendarMorning","新的一天",size*.022,size*.42,size*.66,size*.30,size*.075,{104,99,80,255})
    local leaf=UI.Panel(rect("calendarLeaf",0,0,size,size));leaf.props.pointerEvents="box-none";canvas:AddChild(leaf)
    date(leaf,"calendarCurrent",day,size)
    if shipped(data) or final then
        local stamp=UI.Panel(rect("calendarStamp",size*.477,size*.602,size*.18,size*.18));stamp.props.rotate=-12;leaf:AddChild(stamp)
        function stamp:Render(vg) Art.Stamp(vg,self:GetAbsoluteLayout()) end
        text(stamp,"calendarStampText","已寄出",size*.0225,0,size*.058,size*.18,size*.064,{163,53,35,255})
    else
        text(leaf,"calendarWaiting","今日信件 · 尚未寄出",math.max(10,size*.0195),size*.34,size*.65,size*.47,size*.10,{126,113,90,255})
    end
    local notice=text(root,"calendarNotice","",14,fit.noteX,fit.noteY,fit.noteW,fit.noteH,{255,242,213,255})
    Widget.SetStyle(notice,{whiteSpace="normal",backgroundColor={32,25,20,190},borderRadius=8,padding={4,12}})
    ---@type Button
    local confirm
    ---@type Button
    local cancel
    ---@type Button
    local reload
    local errorText=ctx.importantMessage and ctx.model.message or false
    local function hint()
        return errorText or (not action.enabled and action.message) or
            (final and "今天的信已寄出，明天再开门。" or "今天的信已寄出，明天也会有新的来信。")
    end
    notice:SetText(hint())
    local function current()
        return not api.disposed and not ctx.destroyed and ctx.calendar==api and ctx.panel=="day" and not api.motion.active
    end
    local function confirmDay()
        if not current() then return end
        local live=ctx.model.Refresh()
        if not live or live.revision~=revision or live.live.gameFlow.day~=day then
            ctx.model.message="日历对应的进度已更新，请重新确认。";ctx.model.dirty=true;return
        end
        action=ctx.model.Action("NextDay")
        if not action.enabled then notice:SetText(action.message);confirm:SetDisabled(true);return end
        local result=ctx.model.NextDay()
        if not result.ok then errorText=ctx.model.message;notice:SetText(errorText);return end
        if ctx.PlayObjectSound then ctx.PlayObjectSound("ui_confirm") end
        local saved=assert(ctx.model.Refresh())
        api.toDay=saved.live.gameFlow.day
        local closing=saved.chapter and saved.chapter.phase~="operating"
        api.motion.Begin(closing and "closing" or "next")
        nextSheet:SetVisible(not closing)
        -- Commit once, freeze the old date, then keep this widget tree through the animation.
        confirm:SetDisabled(true);cancel:SetDisabled(true);reload:SetVisible(false)
        notice:SetText(closing and not apprentice and "把这些日子，好好收起来。" or "晚安。明天见。")
        return result
    end
    local actions=metrics.short and root or leaf
    cancel=button(actions,"cancelNextDay","再待一会",metrics.short and 18 or math.max(12,size*.0255),size*.281,size*.778,size*.22,size*.09,function()
        if current() then ctx.Close() end
    end)
    confirm=button(actions,"confirmNextDay","结束今天",metrics.short and 18 or math.max(12,size*.0255),size*.749,size*.784,size*.18,size*.09,confirmDay)
    confirm:SetDisabled(not action.enabled)
    reload=button(root,"reloadCalendarSave","重新读取进度",16,fit.x+size*.30,fit.y+size*.88,size*.40,44,function()
        if current() then ctx.model.Reload() end
    end)
    reload.props.backgroundColor={237,221,185,255};reload:SetVisible(not ctx.session.state.CanMutate())
    if metrics.short then
        for i,node in ipairs({confirm,cancel,reload}) do
            Widget.SetStyle(node,{left=fit.noteX,top=metrics.y+metrics.h-156+(i-1)*50,width=fit.noteW,height=44,
                backgroundColor={237,221,185,255}})
        end
    end
    function leaf:Render(vg)
        if api.motion.active and api.motion.kind=="next" then Art.Paper(vg,canvas:GetAbsoluteLayout()) end
    end
    function canvas:CustomRenderChildren(vg,render)
        render(base,vg);render(nextSheet,vg)
        if api.motion.active and api.motion.kind=="next" then
            Art.Tear(vg,self:GetAbsoluteLayout(),api.motion.Pose(),function(nvg) render(leaf,nvg) end)
        else render(leaf,vg) end
    end
    function api.Update(dt,focused)
        if api.disposed or not api.motion.active then return false end
        local done=api.motion.Update(dt,focused)
        local pose=api.motion.Pose()
        Widget.SetStyle(canvas,{opacity=pose.alpha,translateY=pose.drop*size,scale=pose.scale})
        Widget.SetStyle(notice,{opacity=pose.alpha})
        return done
    end
    local destroy=root.Destroy
    function root:Destroy()
        api.disposed=true
        if ctx.calendar==api then ctx.calendar=false end
        destroy(self)
    end
    return api
end
return C
