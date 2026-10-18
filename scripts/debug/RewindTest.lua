-- 逐日回溯：真实日开头、原子提交、失败注入、旧档/跨周目/结局与标题界面。
local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local T={}
local must=R.Must

local function byDay(view,day)
    for _,point in ipairs(view.points) do if point.day==day then return point end end
end
local function maxPointDay(data)
    local max=0
    for _,point in ipairs(data.chapter.rewind.points) do if point.day>max then max=point.day end end
    return max
end
local function day3(cash)
    local x=R.New(cash)
    must(x.state.StartJourney({expectedRevision=0}))
    R.Ship(x,1)
    must(x.state.NextDay())
    local day2Start=x.state.GetSnapshot()
    R.Ship(x,2)
    must(x.state.NextDay())
    return x,day2Start
end
local function day4Draft()
    local x=day3()
    R.Ship(x,3)
    must(x.state.NextDay())
    local request=R.Accept(x,4)
    must(x.order.UpdateDraft({orderId=request.orderId,draft=require("systems.RecipeDraft").Project(request)}))
    return x,request
end

function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    local record,finish=R.Checks("Rewind")
    local function check(name,fn)
        local filter=rawget(_G,"REWIND_FILTER")
        if not filter or name:find(filter,1,true) then record(name,fn) end
    end

    check("days 1-3 keep real start snapshots; restore survives reload and backup",function()
        local x,day2Start=day3()
        local before=x.state.GetSnapshot()
        local view=must(x.session.queries.GetRewindView())
        assert(view.currentDay==3 and view.canOpen and #view.points==3)
        local day1=assert(byDay(view,1));assert(day1.storyTitle=="铁锚巷的一夜")
        local day2=assert(byDay(view,2));assert(day2.available and day2.storyTitle=="面包坊与抄写铺")
        assert(day2.label=="第 2 天：面包坊与抄写铺")
        local day3=assert(byDay(view,3));assert(day3.storyTitle=="两个人的晚饭")
        assert(require("systems.RewindHistory").DayTitle(x.content,12)==false,"days without an order have no story title")
        local restored=must(x.state.RestoreDay({pointId=day2.id,expectedRevision=before.revision}))
        assert(restored.restoredDay==2)
        local after=x.state.GetSnapshot()
        assert(after.revision==before.revision+1 and after.live.gameFlow.day==2)
        assert(U.Equal(day2Start.live,after.live),"restored live state must equal day 2 start")
        assert(U.Equal(day2Start.currentOrder,after.currentOrder),"restored current order must equal day 2 start")
        assert(U.Equal(day2Start.journal,after.journal),"restored journal must equal day 2 start")
        assert(day2Start.nextOrderSerial==after.nextOrderSerial,"restored order serial")
        assert(after.chapter.rewind.backup and after.chapter.rewind.backup.day==3)
        assert(maxPointDay(after)==2,"later branch points must be truncated")
        assert(x.Reload())
        local reloaded=x.state.GetSnapshot()
        assert(reloaded.revision==after.revision)
        assert(U.Equal(after.live,reloaded.live) and U.Equal(after.currentOrder,reloaded.currentOrder)
            and U.Equal(after.journal,reloaded.journal),"restored business projection must survive reload")
        local back=must(x.state.RestoreBeforeRewind({expectedRevision=reloaded.revision}))
        assert(back.restoredDay==3)
        local recovered=x.state.GetSnapshot()
        assert(recovered.revision==reloaded.revision+1 and recovered.live.gameFlow.day==3)
        assert(U.Equal(before.live,recovered.live),"backup must restore the exact pre-rewind business state")
        assert(U.Equal(before.currentOrder,recovered.currentOrder) and U.Equal(before.journal,recovered.journal))
    end)

    check("rewind isolates old confirm and reset requests from the new branch",function()
        local x=R.New()
        must(x.state.StartJourney({expectedRevision=0}))
        local day1=assert(byDay(must(x.session.queries.GetRewindView()),1))
        local firstRequest=R.Accept(x,1)
        local firstPending=R.Preview(x,firstRequest)
        local oldConfirm={orderId=firstRequest.orderId,transactionId=firstPending.transactionId}
        local oldBaseline=x.state.GetSnapshot().currentOrder.baseline.id
        must(x.state.RestoreDay({pointId=day1.id,expectedRevision=x.state.GetSnapshot().revision}))

        local secondRequest=R.Accept(x,1)
        local stalePreview=x.order.Preview(U.Copy(firstRequest))
        assert(not stalePreview.ok and (stalePreview.error.code=="STALE_DRAFT"
            or stalePreview.error.code=="INVALID_ORDER_STATE"),"an old preview must not create a new pending")
        local alt
        for _,case in ipairs(x.content.recipes) do
            if case.letterId=="letter_pa_01" and #case.recipe.auxWordIds>0 then alt=case;break end
        end
        assert(alt,"a second first-order recipe is required")
        local request={orderId=secondRequest.orderId,equipmentId=alt.recipe.equipmentId,
            mainTokenId=assert(x.tokens[alt.recipe.mainWordId]),auxTokenIds={},
            ingredients=U.Copy(alt.recipe.ingredients),specialItemIds={}}
        for _,wordId in ipairs(alt.recipe.auxWordIds) do
            request.auxTokenIds[#request.auxTokenIds+1]=assert(x.tokens[wordId])
        end
        local secondPending=R.Preview(x,request)
        assert(secondPending.transactionId~=firstPending.transactionId,"a new branch must not reuse the old transaction")
        assert(not U.Equal(firstPending.potion,secondPending.potion),"the two recipes must produce different potions")

        local before=x.state.GetSnapshot()
        local staleConfirm=x.order.Confirm(oldConfirm)
        assert(not staleConfirm.ok and (staleConfirm.error.code=="STALE_TRANSACTION"
            or staleConfirm.error.code=="INVALID_ORDER_STATE"),"an old confirmation must not reach the new branch")
        assert(U.Equal(before,x.state.GetSnapshot()))
        local staleReset=x.order.Reset({orderId=oldConfirm.orderId,baselineId=oldBaseline,
            transactionId=oldConfirm.transactionId})
        assert(not staleReset.ok and (staleReset.error.code=="STALE_TRANSACTION"
            or staleReset.error.code=="STALE_BASELINE" or staleReset.error.code=="INVALID_ORDER_STATE"),
            "an old reset must not reach the new branch")
        assert(U.Equal(before,x.state.GetSnapshot()))

        local model=require("ui.PlayModel").New(x.session,x.content)
        local staleUI=model.Resolve(true,firstPending.transactionId)
        assert(not staleUI.ok and U.Equal(before,x.state.GetSnapshot()),
            "an old result-screen callback must not confirm the new pending")
        local delivered=must(model.Resolve(true,secondPending.transactionId))
        assert(delivered.phase=="confirmed")
        assert(U.Equal(x.state.GetSnapshot().live.orders.confirmedById[secondRequest.orderId].potion,secondPending.potion),
            "the new branch confirmation still works")
    end)

    check("write, readback and uncertain failures never install a half rewind",function()
        local x=day3()
        local before=x.state.GetSnapshot()
        local day2=assert(byDay(must(x.session.queries.GetRewindView()),2))
        local function attempt(fault)
            -- 提交不确定只在真正写 commit 时触发；清理上次提交标记，避免预读阶段先报损坏。
            if fault=="uncertain" then x.commitWritten=false end
            x.fault=fault
            local result=x.state.RestoreDay({pointId=day2.id,expectedRevision=before.revision})
            x.fault=false
            return result
        end
        assert(not attempt("write").ok)
        assert(U.Equal(before,x.state.GetSnapshot()),"write failure must keep the current state")
        assert(not attempt("readback").ok)
        assert(U.Equal(before,x.state.GetSnapshot()),"readback failure must keep the current state")
        assert(x.Reload() and x.state.GetSnapshot().live.gameFlow.day==3)
        local uncertain=attempt("uncertain")
        assert(not uncertain.ok and x.state.GetStatus().status=="recovery_required")
        assert(x.state.ReloadCurrent())
        local committed=x.state.GetSnapshot()
        assert(committed.live.gameFlow.day==2 and committed.chapter.rewind.backup.day==3)
        local back=must(x.state.RestoreBeforeRewind({expectedRevision=committed.revision}))
        assert(back.restoredDay==3)
        assert(U.Equal(before.live,x.state.GetSnapshot().live),"uncertain commit must remain recoverable from the backup")
    end)

    check("legacy save has no invented days; the next crossing starts the history",function()
        local x=day3()
        local data=x.state.GetSnapshot();data.chapter.rewind=nil
        assert(x.save.Save("b5_flow",data,4));assert(x.Reload())
        local legacyState=x.state.GetSnapshot()
        local view=must(x.session.queries.GetRewindView())
        assert(view.canOpen and #view.points==1 and view.currentDay==3)
        local currentPoint=assert(byDay(view,3))
        assert(currentPoint.at=="current" and currentPoint.label:find("启用回溯时",1,true))
        local missing=x.state.RestoreDay({pointId="run:1:day:1:1",expectedRevision=x.state.GetSnapshot().revision})
        assert(not missing.ok and missing.error.code=="UNKNOWN_REWIND_POINT")
        R.Ship(x,3)
        assert(x.state.NextDay().ok)
        local after=x.state.GetSnapshot()
        assert(after.live.gameFlow.day==4)
        assert(#after.chapter.rewind.points==2)
        assert(byDay(must(x.session.queries.GetRewindView()),4) and not byDay(must(x.session.queries.GetRewindView()),1))
        local nextView=must(x.session.queries.GetRewindView())
        local day4=assert(byDay(nextView,4));assert(day4.at=="day_start")
        local legacyPoint=assert(byDay(nextView,3));assert(legacyPoint.at=="current")
        -- 旧档的“当前进度”点可以恢复启用回溯时的完整业务状态，而不是只改天数。
        local loaded=must(x.state.RestoreDay({pointId=legacyPoint.id,expectedRevision=after.revision}))
        assert(loaded.restoredDay==3)
        local restored=x.state.GetSnapshot()
        assert(restored.live.gameFlow.day==3)
        assert(U.Equal(legacyState.live,restored.live) and U.Equal(legacyState.currentOrder,restored.currentOrder)
            and U.Equal(legacyState.journal,restored.journal),"legacy current point restores the enabled-time state")
        assert(restored.chapter.rewind.backup and restored.chapter.rewind.backup.day==4)
    end)

    check("title labels the legacy current point as the enabled moment",function()
        local x=day3()
        local data=x.state.GetSnapshot();data.chapter.rewind=nil
        assert(x.save.Save("b5_flow",data,4));assert(x.Reload())
        local View=require "ui.PlayView"
        local v=View.New(x.session,x.content)
        assert(v.ShowTitle());v.Update()
        v.root:FindById("openRewind").props.onClick();v.Update()
        local title=assert(v.root:FindById("rewindDetailTitle"))
        assert(title:GetText():find("启用回溯时",1,true),"current point must not be labelled as day start")
        assert(title:GetText():find("两个人的晚饭",1,true),"current point keeps the day's story title")
        assert(not v.root:FindById("rewindRestore").props.disabled)
    end)

    check("legacy current point can restore an unfinished pending result",function()
        local x=day3()
        R.Ship(x,3)
        must(x.state.NextDay())
        local request=R.Accept(x,4)
        local pending=R.Preview(x,request)
        local data=x.state.GetSnapshot()
        assert(data.currentOrder and data.currentOrder.pending)
        data.chapter.rewind=nil
        assert(x.save.Save("b5_flow",data,4));assert(x.Reload())
        local view=must(x.session.queries.GetRewindView())
        local point=assert(byDay(view,4))
        assert(point.at=="current")
        -- 启用回溯后玩家继续确认了这锅结果；当前进度点仍应恢复为 pending。
        must(x.order.Confirm({orderId=request.orderId,transactionId=pending.transactionId}))
        local confirmed=x.state.GetSnapshot()
        assert(confirmed.currentOrder==false)
        assert(confirmed.journal.byAttemptId[pending.transactionId].status=="shipped")
        local restored=must(x.state.RestoreDay({pointId=point.id,expectedRevision=confirmed.revision}))
        assert(restored.restoredDay==4)
        local after=x.state.GetSnapshot()
        assert(after.currentOrder and after.currentOrder.pending
            and after.currentOrder.pending.transactionId==pending.transactionId,
            "the enabled-time point must keep a pending result intact")
        assert(after.journal.byAttemptId[pending.transactionId].status=="pending",
            "mutable journal status must come from the snapshot, not the later save")
        local back=must(x.state.RestoreBeforeRewind({expectedRevision=after.revision}))
        assert(back.restoredDay==4)
        local recovered=x.state.GetSnapshot()
        assert(recovered.currentOrder==false and recovered.live.orders.confirmedById[request.orderId]~=nil)
        assert(recovered.journal.byAttemptId[pending.transactionId].status=="shipped")
        assert(U.Equal(confirmed.live,recovered.live) and U.Equal(confirmed.journal,recovered.journal),
            "the full pre-rewind backup must restore the later confirmed state")
    end)

    check("ending disables day rewind; the existing checkpoint still restores it",function()
        local x=day3(1000)
        local day2=assert(byDay(must(x.session.queries.GetRewindView()),2))
        local quote=R.Quote(x,"travel_ticket",666)
        local ended=must(x.state.PurchaseTravelTicket(quote))
        assert(ended.departed)
        local endedView=must(x.session.queries.GetRewindView())
        assert(not endedView.canOpen)
        local refused=x.state.RestoreDay({pointId=day2.id,expectedRevision=x.state.GetSnapshot().revision})
        assert(not refused.ok and refused.error.code=="INVALID_CHAPTER_STATE")
        must(x.state.RestoreEndingCheckpoint({expectedRevision=x.state.GetSnapshot().revision}))
        local restored=x.state.GetSnapshot()
        assert(restored.chapter.phase=="operating" and restored.live.gameFlow.day==3)
        local restoredView=must(x.session.queries.GetRewindView())
        assert(restoredView.canOpen and #restoredView.points>=1)
    end)

    check("unfinished draft is discarded by rewind, preserved by backup, and old quotes expire",function()
        local x=day4Draft()
        local before=x.state.GetSnapshot()
        assert(before.currentOrder and before.currentOrder.draft.mainTokenId)
        local staleQuote=R.Quote(x,"decor_tablecloth",60)
        local view=must(x.session.queries.GetRewindView())
        local day3Point=assert(byDay(view,3))
        must(x.state.RestoreDay({pointId=day3Point.id,expectedRevision=before.revision}))
        local after=x.state.GetSnapshot()
        assert(after.live.gameFlow.day==3)
        assert(after.currentOrder==false or not after.currentOrder.draft.mainTokenId,"rewind discards the later draft")
        local stale=x.state.PurchaseHomeItem(staleQuote)
        assert(not stale.ok and (stale.error.code=="STALE_REVISION" or stale.error.code=="STALE_DAY"),
            "old callbacks cannot overwrite the new branch")
        must(x.state.RestoreBeforeRewind({expectedRevision=after.revision}))
        local recovered=x.state.GetSnapshot()
        assert(U.Equal(before.currentOrder,recovered.currentOrder),"backup must preserve the unfinished draft")
        assert(U.Equal(before.journal,recovered.journal))
    end)

    check("new playthrough clears the old run nodes and keeps memories and device settings",function()
        local x=day3()
        local oldView=must(x.session.queries.GetRewindView())
        local oldId=oldView.points[1].id
        local fresh=must(x.state.StartNewPlaythrough({expectedRevision=x.state.GetSnapshot().revision}))
        assert(fresh.startedNew)
        local data=x.state.GetSnapshot()
        assert(data.live.gameFlow.day==1 and data.chapter.rewind.run==2)
        assert(#data.chapter.rewind.points==1 and data.chapter.rewind.points[1].day==1)
        local gone=x.state.RestoreDay({pointId=oldId,expectedRevision=data.revision})
        assert(not gone.ok and gone.error.code=="UNKNOWN_REWIND_POINT")

        local ended=E.LegacyClosing("ended")
        local memoryCount=0
        must(ended.state.StartNewPlaythrough({expectedRevision=ended.state.GetSnapshot().revision}))
        local remembered=ended.state.GetSnapshot()
        for _ in ipairs(remembered.chapter.memories) do memoryCount=memoryCount+1 end
        assert(memoryCount==1)
        R.Ship(ended,1)
        must(ended.state.NextDay())
        ended.files["music_settings.json"]='{"version":1,"enabled":true,"volume":60}'
        ended.files["sound_settings.json"]='{"version":1,"enabled":true,"volume":40}'
        local music=ended.files["music_settings.json"];local sound=ended.files["sound_settings.json"]
        local target=assert(byDay(must(ended.session.queries.GetRewindView()),1))
        must(ended.state.RestoreDay({pointId=target.id,expectedRevision=ended.state.GetSnapshot().revision}))
        assert(U.Equal(remembered.chapter.memories,ended.state.GetSnapshot().chapter.memories),
            "memories are global and must not roll back")
        assert(ended.files["music_settings.json"]==music and ended.files["sound_settings.json"]==sound,
            "device preferences are outside the business save")
    end)

    check("closing keeps the run number so the next journey is the third",function()
        local x=E.New()
        must(x.state.StartJourney({expectedRevision=0}))
        must(x.state.StartNewPlaythrough({expectedRevision=x.state.GetSnapshot().revision}))
        assert(x.state.GetSnapshot().chapter.rewind.run==2)
        x.content.release.requiredOrderIds={x.content.release.requiredOrderIds[1]}
        x.content.release.minThreeStarOrders=1
        R.Ship(x,1)
        must(x.state.BeginClosing({expectedRevision=x.state.GetSnapshot().revision}))
        local closing=x.state.GetSnapshot()
        assert(closing.chapter.rewind and closing.chapter.rewind.run==2,
            "closing must keep the current run identity")
        E.OpenWish(x)
        local token=must(x.session.queries.GetWishView()).samples[1].sourceTokenId
        must(x.state.UpdateWishDraft({sourceTokenIds={token},expectedRevision=x.state.GetSnapshot().revision}))
        must(x.state.ConfirmEnding({kind="wish",expectedRevision=x.state.GetSnapshot().revision}))
        local ended=x.state.GetSnapshot()
        assert(ended.chapter.phase=="ended" and ended.chapter.rewind.run==2)
        local legacy=E.Clone(x)
        must(x.state.StartNewPlaythrough({expectedRevision=ended.revision}))
        assert(x.state.GetSnapshot().chapter.rewind.run==3,
            "the third journey must not be recorded as the second")
        local legacyData=legacy.state.GetSnapshot();legacyData.chapter.rewind=nil
        assert(legacy.save.Save("b5_flow",legacyData,4));assert(legacy.Reload())
        must(legacy.state.StartNewPlaythrough({expectedRevision=legacy.state.GetSnapshot().revision}))
        assert(legacy.state.GetSnapshot().chapter.rewind.run==3,
            "an old ending save can read the run from its pre-ending checkpoint")
    end)

    check("content-version mismatch keeps the point visible but unavailable",function()
        local x=day3()
        local data=x.state.GetSnapshot()
        local point=data.chapter.rewind.points[1]
        point.contentVersion="old-story";point.snapshot.contentVersion="old-story"
        assert(x.save.Save("b5_flow",data,4));assert(x.Reload())
        local view=must(x.session.queries.GetRewindView())
        local old=assert(byDay(view,1))
        assert(not old.available and old.reason:find("旧版本",1,true))
        assert(old.storyTitle==false and old.label=="第 1 天（旧版本不可恢复）")
        local refused=x.state.RestoreDay({pointId=old.id,expectedRevision=x.state.GetSnapshot().revision})
        assert(not refused.ok and refused.error.code=="CONTENT_VERSION_MISMATCH")
    end)

    check("title rewind opens, restores, cancels without writing and offers the backup",function()
        local x=day3()
        local View=require "ui.PlayView"
        local v=View.New(x.session,x.content)
        assert(v.ShowTitle());v.Update()
        local open=assert(v.root:FindById("openRewind"))
        open.props.onClick();v.Update()
        assert(v.panel=="rewind" and v.root:FindById("rewindDay_2"))
        v.root:FindById("rewindDay_2").props.onClick();v.Update()
        local story=assert(v.root:FindById("rewindStory_2"))
        assert(story:GetText()=="面包坊与抄写铺")
        local detailTitle=assert(v.root:FindById("rewindDetailTitle"))
        assert(detailTitle:GetText()=="第 2 天：面包坊与抄写铺")
        local restore=assert(v.root:FindById("rewindRestore"))
        assert(not restore.props.disabled)
        restore.props.onClick();v.Update()
        assert(v.panel==false and x.state.GetSnapshot().live.gameFlow.day==2)
        assert(v.model.GetDraft().mainTokenId==false and v.root:FindById("brewWordPanel")==nil,
            "rewind must drop the old recipe view and draft")

        assert(v.ShowTitle());v.Update()
        v.root:FindById("openRewind").props.onClick();v.Update()
        local writes=x.writes
        v.root:FindById("rewindCancel").props.onClick();v.Update()
        assert(v.panel=="title" and x.writes==writes,"cancel must not write")

        v.root:FindById("openRewind").props.onClick();v.Update()
        local backup=assert(v.root:FindById("rewindBackupRestore"))
        assert(not backup.props.disabled)
        backup.props.onClick();v.Update()
        assert(x.state.GetSnapshot().live.gameFlow.day==3)
    end)

    check("title rewind paginates long histories without shrinking every node",function()
        local x=day3()
        local View=require "ui.PlayView"
        local v=View.New(x.session,x.content)
        local original=v.session.queries.GetRewindView
        local points={}
        for day=1,14 do
            points[#points+1]={id="fake:"..day,day=day,label="第 "..day.." 天",available=true,reason="",
                stats={day=day,currency=day*10,letters=day,tokens=day,purchases=day,delivered=day,confirmed=day},
                summary="第 "..day.." 天"}
        end
        v.session.queries.GetRewindView=function()
            return U.Ok({run=1,currentDay=14,phase="operating",contentVersion=x.content.contentVersion,canOpen=true,
                reason="",points=points,backup=false,current={day=14,stats=points[14].stats,summary=""}})
        end
        assert(v.ShowTitle());v.Update()
        v.root:FindById("openRewind").props.onClick();v.Update()
        -- 默认选中第 13 天会落在第二页；先回到第一页核对窗口。
        if v.root:FindById("rewindPrev") and not v.root:FindById("rewindPrev").props.disabled then
            v.root:FindById("rewindPrev").props.onClick();v.Update()
        end
        assert(v.root:FindById("rewindDay_1") and v.root:FindById("rewindDay_7") and not v.root:FindById("rewindDay_8"))
        v.root:FindById("rewindNext").props.onClick();v.Update()
        assert(v.root:FindById("rewindDay_8") and v.root:FindById("rewindDay_14") and not v.root:FindById("rewindDay_1"))
        v.session.queries.GetRewindView=original
    end)

    check("title rewind failure keeps the screen and reports the save error",function()
        local x=day3()
        local View=require "ui.PlayView"
        local v=View.New(x.session,x.content)
        assert(v.ShowTitle());v.Update()
        v.root:FindById("openRewind").props.onClick();v.Update()
        v.root:FindById("rewindDay_2").props.onClick();v.Update()
        local before=x.state.GetSnapshot()
        x.fault="write"
        v.root:FindById("rewindRestore").props.onClick();v.Update()
        x.fault=false
        assert(v.panel=="rewind" and U.Equal(before,x.state.GetSnapshot()))
        assert(v.model.message:find("保存失败",1,true))
    end)

    return finish()
end
return T
