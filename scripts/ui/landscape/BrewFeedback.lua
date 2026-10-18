-- Successful business commands trigger trails; this view never saves or awards.
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local H=require "ui.landscape.HarborStyle"
local Motion=require "ui.landscape.FeedbackMotion"
local F={}
local function clamp(t) return math.max(0,math.min(1,t)) end
local function point(ctx,id,fallback)
    local node=ctx.root:FindById(id)
    local r=node and node.GetAbsoluteLayout and node:GetAbsoluteLayout()
    if r and r.w>0 and r.h>0 then return {x=r.x+r.w/2,y=r.y+r.h/2} end
    return fallback
end
local function trail(vg,motion,event,color)
    local head=motion.Sample(event);if not head then return end
    for i=18,1,-1 do
        local a=motion.Sample(event,i*.013);local b=motion.Sample(event,(i-1)*.013)
        if a and b then
            local opacity=(1-i/20)
            nvgBeginPath(vg);nvgMoveTo(vg,a.x,a.y);nvgLineTo(vg,b.x,b.y)
            nvgStrokeWidth(vg,10*opacity);nvgStrokeColor(vg,nvgRGBA(color[1],color[2],color[3],math.floor(65*opacity)));nvgStroke(vg)
            nvgStrokeWidth(vg,2.5*opacity);nvgStrokeColor(vg,nvgRGBA(255,245,215,math.floor(240*opacity)));nvgStroke(vg)
            if i%3==0 then
                nvgBeginPath(vg);nvgCircle(vg,a.x+math.sin(i*3+event.time*6)*8,a.y+math.cos(i*4)*6,1.4)
                nvgFillColor(vg,nvgRGBA(color[1],color[2],color[3],math.floor(230*opacity)));nvgFill(vg)
            end
        end
    end
    nvgBeginPath(vg);nvgCircle(vg,head.x,head.y,19)
    nvgFillPaint(vg,nvgRadialGradient(vg,head.x,head.y,1,19,nvgRGBA(color[1],color[2],color[3],190),nvgRGBA(color[1],color[2],color[3],0)));nvgFill(vg)
    nvgBeginPath(vg);nvgCircle(vg,head.x,head.y,3.5);nvgFillColor(vg,nvgRGBA(255,251,222,255));nvgFill(vg)
end
local function pulse(vg,event,color)
    if not event or not event.started then return end
    local t=event.time-event.duration;if t<0 or t>.65 then return end
    local p=event.target;local radius=18+t*75
    nvgBeginPath(vg);nvgCircle(vg,p.x,p.y,radius)
    nvgStrokeWidth(vg,2*(1-t/.65));nvgStrokeColor(vg,nvgRGBA(color[1],color[2],color[3],math.floor(220*(1-t/.65))));nvgStroke(vg)
end
function F.New(ctx,ledger)
    local motion=Motion.New()
    local root=UI.Panel {id="brewFeedback",position="absolute",left=0,top=0,width="100%",height="100%",zIndex=1600,pointerEvents="none"}
    ctx.root:AddChild(root)
    local function notice(id,color)
        local label=UI.Label {id=id,position="absolute",visible=false,width=246,height=34,padding={4,10},
            fontFamily=H.fontFamily,fontSize=13,fontColor=color,backgroundColor={49,43,34,222},borderRadius=8,
            textAlign="center",verticalAlign="middle",whiteSpace="nowrap",pointerEvents="none"}
        root:AddChild(label);return label
    end
    local recordText=notice("brewRecordFeedback",{244,226,255,255})
    local rewardText=notice("brewRewardFeedback",{255,230,153,255})
    local f={motion=motion,root=root,day=1,actual=0,signature=""}
    function f.Cancel()
        motion.Cancel(f.actual);recordText:SetVisible(false);rewardText:SetVisible(false)
    end
    function f.Currency(actual,day)
        f.actual=actual;f.day=day
        return motion.Currency(actual)
    end
    local preview=ctx.model.Preview
    function ctx.model.Preview()
        local prior=ctx.session.queries.GetOrderSummary()
        local source=prior.ok and prior.value.sourceLetterId
        local seen={}
        if source then
            local page=ctx.session.queries.GetJournalPage(source)
            if page.ok then for _,outcome in ipairs(page.value.outcomes) do if outcome.outcomeKey then seen[outcome.outcomeKey]=true end end end
        end
        local result=preview()
        if result.ok and result.value.phase=="pending" and not (prior.ok and prior.value.pending) then
            local after=ctx.session.queries.GetOrderSummary()
            local pending=after.ok and after.value.pending
            local saved=pending and ctx.session.queries.GetAttempt(pending.transactionId)
            if saved and saved.ok then
                if motion.Record(pending.transactionId,not seen[saved.value.outcomeKey]) then motion.record.storyId=saved.value.sourceLetterId end
            end
        end
        return result
    end
    local resolve=ctx.model.Resolve
    function ctx.model.Resolve(confirm,expectedTransactionId)
        local before=ctx.model.Refresh()
        local pending=before and before.currentOrder and before.currentOrder.pending
        local viewport=ctx.viewport or {w=1280,h=720}
        local source=point(ctx,"confirmOrder",{x=viewport.w*.6,y=viewport.h*.8})
        local result=resolve(confirm,expectedTransactionId)
        if confirm and result.ok and pending then
            local after=ctx.model.Refresh()
            f.actual=after.live.economy.currency;f.day=after.live.gameFlow.day
            if motion.Reward(pending.transactionId,before.live.economy.currency,f.actual,source,
                point(ctx,"ledgerCard",{x=100,y=30})) and ctx.PlayObjectSound then
                ctx.PlayObjectSound("reward_coins")
            end
        end
        return result
    end
    function f.Update(dt)
        local viewport=ctx.viewport or {w=1280,h=720}
        local signature=viewport.w..":"..viewport.h
        if ctx.portrait or (f.signature~="" and signature~=f.signature) then f.Cancel() end
        f.signature=signature
        local record=motion.record
        if record and not record.started and ctx.scene=="brew" and (not ctx.panel or ctx.panel=="result") and
            not ctx.brew.interaction.active and ctx.brew.revealTail<=0 then
            ctx.brew.OpenJournal(record.storyId)
            motion.StartRecord(point(ctx,"resultStars",{x=viewport.w*.65,y=viewport.h*.28}),
                point(ctx,"bookProgress",{x=viewport.w*.87,y=viewport.h*.3}))
        end
        if motion.record and motion.record.started and motion.record.time<0 then
            motion.record.target=point(ctx,"bookProgress",motion.record.target)
        end
        motion.Update(dt)
        local r=motion.record
        local arrived=r and r.started and r.time>=r.duration
        recordText:SetVisible(arrived or false)
        if arrived then
            recordText:SetText(r.isNew and "新后续已收录" or "本次试做已记录")
            Widget.SetStyle(recordText,{left=math.min(viewport.w-254,math.max(8,r.target.x-123)),top=r.target.y+25,
                opacity=clamp((r.duration+1.2-r.time)/.35)})
        end
        local reward=motion.reward;rewardText:SetVisible(reward~=false)
        if reward then
            local head=motion.Sample(reward)
            rewardText:SetText(head and ("+"..reward.amount.." 金币") or ("报酬 +"..reward.amount.." 金币"))
            local p=head or reward.target
            Widget.SetStyle(rewardText,{left=math.min(viewport.w-254,math.max(8,p.x-55)),top=head and p.y+12 or p.y+28,
                opacity=clamp((reward.duration+1.1-reward.time)/.35)})
        end
        if motion.reward or motion.value~=false then
            ledger:SetText(string.format("金币 %d   ·   第 %d 天",motion.Currency(f.actual),f.day))
        end
    end
    function root:Render(vg)
        trail(vg,motion,motion.record,{212,182,255});trail(vg,motion,motion.reward,{255,205,94})
        pulse(vg,motion.record,{226,201,255});pulse(vg,motion.reward,{255,215,112})
    end
    return f
end
return F
