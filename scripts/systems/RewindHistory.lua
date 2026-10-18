-- 逐日回溯的纯计划与校验。日开头快照只保存可重建的业务投影：
-- 已确认订单和回信归档不可变，快照只存 ID，恢复时从当前存档复制并完整重验；
-- 试做记录的状态会从 pending 变为 shipped/reset，所以带 pending 的当前进度点保存完整记录。
-- 回溯前备份保留一份完整状态，因为回溯会截断后续分支的记录。
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local D=require "systems.RecipeDraft"
local R={}
R.VERSION=1

local function idList(list,path)
    G.Array(list,path,"STATE_INVALID")
    local seen={}
    for _,id in ipairs(list) do
        G.Need(U.String(id) and not seen[id],"STATE_INVALID",path,"ID 为空或重复")
        seen[id]=true
    end
end

local function compact(snapshot,path,point)
    local at=point.at or "day_start"
    G.Need(at=="day_start" or at=="current","STATE_INVALID",path..".at","回溯节点类型不合法")
    G.Keys(snapshot,{format=true,contentVersion=true,revision=true,nextOrderSerial=true,day=true,live=true,
        currentOrder=true,journalAttemptIds=true,journalRecords=true,chapter=true},path,"STATE_INVALID")
    G.Need(snapshot.format==1 and U.String(snapshot.contentVersion) and U.Integer(snapshot.revision)
        and U.Integer(snapshot.nextOrderSerial,1) and U.Integer(snapshot.day,1),"STATE_INVALID",path,"回溯快照版本或数值不合法")
    G.Need(snapshot.day==point.day and snapshot.revision==point.revision
        and snapshot.contentVersion==point.contentVersion,"STATE_INVALID",path,"快照与节点摘要不一致")
    G.Keys(snapshot.live,{gameFlow=true,letters=true,wordTokens=true,economy=true,world=true,narrative=true,orders=true},
        path..".live","STATE_INVALID")
    G.Keys(snapshot.live.gameFlow,{day=true,phase=true,canSalvage=true,mainStoryStage=true,deliveredOrders=true,
        salvageUsedToday=true},path..".live.gameFlow","STATE_INVALID")
    G.Need(snapshot.live.gameFlow.day==snapshot.day and snapshot.live.gameFlow.phase=="day","STATE_INVALID",
        path..".live.gameFlow","回溯快照必须是经营中的白天")
    if at=="day_start" then
        G.Need(snapshot.live.gameFlow.salvageUsedToday==0,"STATE_INVALID",path..".live.gameFlow","日开头快照不能已消耗捕捞次数")
    else
        G.Need(U.Integer(snapshot.live.gameFlow.salvageUsedToday),"STATE_INVALID",path..".live.gameFlow",
            "当前进度快照的捕捞计数不合法")
    end
    G.Keys(snapshot.live.letters,{byId=true,bottleQueue=true},path..".live.letters","STATE_INVALID")
    G.Need(type(snapshot.live.letters.byId)=="table","STATE_INVALID",path..".live.letters.byId","缺少来信集合")
    idList(snapshot.live.letters.bottleQueue,path..".live.letters.bottleQueue")
    G.Keys(snapshot.live.wordTokens,{byId=true},path..".live.wordTokens","STATE_INVALID")
    G.Need(type(snapshot.live.wordTokens.byId)=="table","STATE_INVALID",path..".live.wordTokens.byId","缺少词条集合")
    G.Need(type(snapshot.live.economy)=="table" and type(snapshot.live.world)=="table"
        and type(snapshot.live.narrative)=="table","STATE_INVALID",path..".live","业务子表不完整")
    G.Keys(snapshot.live.orders,{acceptedById=true,confirmedByIdIds=true},path..".live.orders","STATE_INVALID")
    G.Need(type(snapshot.live.orders.acceptedById)=="table","STATE_INVALID",path..".live.orders.acceptedById","缺少接单集合")
    idList(snapshot.live.orders.confirmedByIdIds,path..".live.orders.confirmedByIdIds")
    G.Need(snapshot.currentOrder==false or type(snapshot.currentOrder)=="table","STATE_INVALID",
        path..".currentOrder","当前订单类型不合法")
    if type(snapshot.currentOrder)=="table" then
        G.Need(snapshot.currentOrder.phase=="accepted" or snapshot.currentOrder.phase=="pending","STATE_INVALID",
            path..".currentOrder","当前订单阶段不合法")
        if at=="day_start" then
            G.Need(snapshot.currentOrder.phase=="accepted" and type(snapshot.currentOrder.draft)=="table"
                and D.IsEmpty(snapshot.currentOrder.draft),"STATE_INVALID",path..".currentOrder",
                "日开头不能带炼制结果或未清空的草稿")
        elseif snapshot.currentOrder.phase=="pending" then
            G.Need(snapshot.journalRecords~=nil,"STATE_INVALID",path..".journalRecords",
                "待确认的当前进度快照必须保存试做记录")
        end
    end
    idList(snapshot.journalAttemptIds,path..".journalAttemptIds")
    if snapshot.journalRecords~=nil then
        -- 当前进度点可能带 pending 试做；记录状态之后会变，必须自包含而不能只引用当前存档。
        G.Need(type(snapshot.journalRecords)=="table","STATE_INVALID",path..".journalRecords","试做记录集合不合法")
        local known={}
        for _,id in ipairs(snapshot.journalAttemptIds) do
            G.Need(type(snapshot.journalRecords[id])=="table","STATE_INVALID",path..".journalRecords",
                "当前进度快照缺少试做记录")
            known[id]=true
        end
        for id in pairs(snapshot.journalRecords) do
            G.Need(known[id]==true,"STATE_INVALID",path..".journalRecords","试做记录超出索引")
        end
    end
    G.Keys(snapshot.chapter,{phase=true,wishDraftSourceIds=true,ending=true,endingTransactionId=true,started=true},
        path..".chapter","STATE_INVALID")
    G.Need(snapshot.chapter.phase=="operating" and snapshot.chapter.ending==false
        and snapshot.chapter.endingTransactionId==false and snapshot.chapter.started==true,
        "STATE_INVALID",path..".chapter","日开头快照只能是经营态")
    G.Array(snapshot.chapter.wishDraftSourceIds,path..".chapter.wishDraftSourceIds","STATE_INVALID")
end

local function full(snapshot,path,backup)
    G.Keys(snapshot,{contentVersion=true,revision=true,nextOrderSerial=true,live=true,currentOrder=true,journal=true,
        chapter=true},path,"STATE_INVALID")
    G.Need(U.String(snapshot.contentVersion) and U.Integer(snapshot.revision)
        and U.Integer(snapshot.nextOrderSerial,1),"STATE_INVALID",path,"回溯前备份版本或数值不合法")
    G.Keys(snapshot.chapter,{phase=true,wishDraftSourceIds=true,ending=true,endingTransactionId=true,started=true,
        checkpoint=true},path..".chapter","STATE_INVALID")
    G.Need(snapshot.chapter.phase=="operating" and snapshot.chapter.ending==false
        and snapshot.chapter.endingTransactionId==false and snapshot.chapter.started==true
        and snapshot.chapter.checkpoint==false,"STATE_INVALID",path..".chapter","回溯前备份只能是经营态")
    G.Array(snapshot.chapter.wishDraftSourceIds,path..".chapter.wishDraftSourceIds","STATE_INVALID")
    G.Need(type(snapshot.live)=="table" and type(snapshot.live.gameFlow)=="table"
        and type(snapshot.journal)=="table" and snapshot.currentOrder~=nil,"STATE_INVALID",path,"备份业务子表不完整")
    G.Need(snapshot.live.gameFlow.day==backup.day and snapshot.revision==backup.revision
        and snapshot.contentVersion==backup.contentVersion,"STATE_INVALID",path,"备份与摘要不一致")
end

function R.ValidateStructure(data)
    return G.Run(function()
        local history=data.chapter and data.chapter.rewind
        if history==nil then return true end
        G.Keys(history,{version=true,run=true,branch=true,points=true,backup=true},"chapter.rewind","STATE_INVALID")
        G.Need(history.version==R.VERSION and U.Integer(history.run,1)
            and (history.branch==nil or U.Integer(history.branch)),"STATE_INVALID",
            "chapter.rewind","回溯历史版本、轮次或分支不合法")
        G.Array(history.points,"chapter.rewind.points","STATE_INVALID")
        local seen,last={},0
        for i,point in ipairs(history.points) do
            local path="chapter.rewind.points."..i
            G.Keys(point,{id=true,day=true,label=true,revision=true,contentVersion=true,snapshot=true,at=true},path,"STATE_INVALID")
            G.Need(U.String(point.id) and not seen[point.id] and U.Integer(point.day,1) and U.String(point.label)
                and U.Integer(point.revision) and U.String(point.contentVersion),"STATE_INVALID",path,"回溯节点摘要不合法")
            G.Need(point.day>last,"STATE_INVALID",path..".day","日开头节点必须按天递增")
            G.Need(point.day<=data.live.gameFlow.day,"STATE_INVALID",path..".day","回溯节点超过当前天数")
            seen[point.id]=true;last=point.day
            compact(point.snapshot,path..".snapshot",point)
        end
        local backup=history.backup
        if backup==false then return true end
        G.Need(type(backup)=="table","STATE_INVALID","chapter.rewind.backup","回溯前备份类型不合法")
        G.Keys(backup,{day=true,label=true,revision=true,contentVersion=true,snapshot=true,points=true,run=true},
            "chapter.rewind.backup","STATE_INVALID")
        G.Need(U.Integer(backup.day,1) and U.String(backup.label) and U.Integer(backup.revision)
            and U.String(backup.contentVersion) and U.Integer(backup.run,1) and backup.run==history.run,
            "STATE_INVALID","chapter.rewind.backup","回溯前备份摘要不合法")
        full(backup.snapshot,"chapter.rewind.backup.snapshot",backup)
        G.Array(backup.points,"chapter.rewind.backup.points","STATE_INVALID")
        local seenBackup,lastBackup={},0
        for i,point in ipairs(backup.points) do
            local path="chapter.rewind.backup.points."..i
            G.Keys(point,{id=true,day=true,label=true,revision=true,contentVersion=true,snapshot=true,at=true},path,"STATE_INVALID")
            G.Need(U.String(point.id) and not seenBackup[point.id] and U.Integer(point.day,1) and U.String(point.label)
                and U.Integer(point.revision) and U.String(point.contentVersion),"STATE_INVALID",path,"备份节点摘要不合法")
            G.Need(point.day>lastBackup and point.day<=backup.day,"STATE_INVALID",path..".day","备份节点日期不合法")
            seenBackup[point.id]=true;lastBackup=point.day
            compact(point.snapshot,path..".snapshot",point)
        end
        return true
    end)
end

function R.Compact(data,at)
    at=at or "day_start"
    return {
        format=1,
        contentVersion=data.contentVersion,
        revision=data.revision,
        nextOrderSerial=data.nextOrderSerial,
        day=data.live.gameFlow.day,
        live={
            gameFlow=U.Copy(data.live.gameFlow),
            letters={byId=U.Copy(data.live.letters.byId),bottleQueue=U.Copy(data.live.letters.bottleQueue)},
            wordTokens=U.Copy(data.live.wordTokens),
            economy=U.Copy(data.live.economy),
            world=U.Copy(data.live.world),
            narrative=U.Copy(data.live.narrative),
            orders={acceptedById=U.Copy(data.live.orders.acceptedById),
                confirmedByIdIds=G.Sorted(data.live.orders.confirmedById)},
        },
        currentOrder=U.Copy(data.currentOrder),
        journalAttemptIds=U.Copy(data.journal.attemptIds),
        journalRecords=at=="current" and U.Copy(data.journal.byAttemptId) or nil,
        -- 快照只在开局或跨天时生成，未显式开局的历史路径也视为已开始。
        chapter={phase=data.chapter.phase,wishDraftSourceIds=U.Copy(data.chapter.wishDraftSourceIds),
            ending=U.Copy(data.chapter.ending),endingTransactionId=data.chapter.endingTransactionId,
            started=true},
    }
end

function R.Materialize(snapshot,current)
    return G.Run(function()
        local data={
            contentVersion=snapshot.contentVersion,
            revision=snapshot.revision,
            nextOrderSerial=snapshot.nextOrderSerial,
            live=U.Copy(snapshot.live),
            currentOrder=U.Copy(snapshot.currentOrder),
            journal={byAttemptId={},attemptIds=U.Copy(snapshot.journalAttemptIds)},
            chapter=U.Copy(snapshot.chapter),
        }
        data.chapter.checkpoint=false
        data.live.orders.confirmedById={}
        data.live.orders.confirmedByIdIds=nil
        data.live.letters.directArchive={}
        for _,id in ipairs(snapshot.live.orders.confirmedByIdIds) do
            local record=current.live.orders.confirmedById[id]
            G.Need(record~=nil,"STALE_REWIND_SNAPSHOT","confirmedById."..id,"回溯快照引用的发货记录已不存在")
            data.live.orders.confirmedById[id]=U.Copy(record)
            local archive=current.live.letters.directArchive[id]
            G.Need(archive~=nil,"STALE_REWIND_SNAPSHOT","directArchive."..id,"回溯快照引用的回信归档已不存在")
            data.live.letters.directArchive[id]=U.Copy(archive)
        end
        for _,id in ipairs(snapshot.journalAttemptIds) do
            local record=snapshot.journalRecords and snapshot.journalRecords[id] or current.journal.byAttemptId[id]
            G.Need(record~=nil,"STALE_REWIND_SNAPSHOT","journal."..id,"回溯快照引用的试做记录已不存在")
            data.journal.byAttemptId[id]=U.Copy(record)
        end
        return data
    end)
end

function R.FullSnapshot(data)
    local snapshot=U.Copy(data)
    snapshot.chapter.rewind=nil
    snapshot.chapter.memories=nil
    snapshot.chapter.checkpoint=false
    snapshot.chapter.epilogue=nil
    snapshot.chapter.wishLayout=nil
    snapshot.chapter.started=true
    return snapshot
end

function R.Stats(source)
    local live=source.live
    local orders=live.orders or {}
    local confirmed=orders.confirmedByIdIds
    local delivered=live.gameFlow.deliveredOrders
    local purchases=live.economy.itemPurchases
    local letters,tokens=0,0
    for _ in pairs(live.letters.byId) do letters=letters+1 end
    for _ in pairs(live.wordTokens.byId) do tokens=tokens+1 end
    G.Need(type(delivered)=="number" and type(purchases)=="table","STATE_INVALID","rewind.stats","回溯摘要业务字段不完整")
    local confirmedCount=0
    if confirmed then confirmedCount=#confirmed
    else for _ in pairs(orders.confirmedById or {}) do confirmedCount=confirmedCount+1 end end
    return {day=live.gameFlow.day,currency=live.economy.currency,letters=letters,tokens=tokens,
        purchases=#purchases,delivered=delivered,confirmed=confirmedCount}
end

function R.Summary(source)
    local stats=R.Stats(source)
    return string.format("第 %d 天 · 金币 %d · 已发货 %d 单",stats.day,stats.currency,stats.delivered)
end

-- 当天新增委托的标题；没有安排委托的日期返回 false。
function R.DayTitle(content,day)
    local required=content.release and content.release.requiredOrderIds
    if not required then return false end
    for _,id in ipairs(required) do
        local letter=content.GetLetter and content.GetLetter(id)
        local condition=letter and letter.appearCondition
        if letter and letter.kind=="order" and condition and condition.dayMin==day and U.String(letter.title) then
            return letter.title
        end
    end
    return false
end

function R.View(data,content)
    return G.Run(function()
        local history=data.chapter and data.chapter.rewind
        local phase=data.chapter and data.chapter.phase
        local allowed=phase=="operating"
        local reason=""
        if phase=="ended" then reason="旅程已结束；请使用“回到结局前”。"
        elseif phase~="operating" then reason="收尾阶段不能回到经营日。" end
        local points={}
        if history then
            for _,point in ipairs(history.points) do
                local versionOk=point.contentVersion==content.contentVersion
                local available=allowed and versionOk
                local storyTitle=versionOk and R.DayTitle(content,point.day) or false
                local label
                if not versionOk then
                    label=string.format("第 %d 天（旧版本不可恢复）",point.day)
                elseif point.at=="current" then
                    label=storyTitle and string.format("第 %d 天：%s · 启用回溯时",point.day,storyTitle)
                        or string.format("第 %d 天 · 启用回溯时",point.day)
                elseif storyTitle then
                    label=string.format("第 %d 天：%s",point.day,storyTitle)
                else
                    label=string.format("第 %d 天",point.day)
                end
                points[#points+1]={id=point.id,day=point.day,label=label,storyTitle=storyTitle,
                    at=point.at or "day_start",available=available,
                    reason=available and "" or (not versionOk and "旧版本记录不可恢复。" or reason),
                    stats=R.Stats(point.snapshot),summary=R.Summary(point.snapshot)}
            end
        end
        local backup=false
        if history and type(history.backup)=="table" then
            local row=history.backup
            local versionOk=row.contentVersion==content.contentVersion
            backup={day=row.day,label=row.label,available=allowed and versionOk,
                reason=allowed and versionOk and "" or (not versionOk and "旧版本记录不可恢复。" or reason),
                stats=R.Stats(row.snapshot),summary=R.Summary(row.snapshot)}
        end
        return {run=history and history.run or 1,currentDay=data.live.gameFlow.day,phase=phase,
            contentVersion=data.contentVersion,canOpen=allowed and (data.chapter.started==true or data.revision>0),
            reason=reason,points=points,backup=backup,
            current={day=data.live.gameFlow.day,stats=R.Stats(data),summary=R.Summary(data)}}
    end)
end

local function append(data,day)
    local history=data.chapter.rewind
    local point={id=string.format("run:%d:day:%d:%d",history.run,day,data.revision),day=day,
        label=string.format("第 %d 天",day),at="day_start",revision=data.revision,
        contentVersion=data.contentVersion,snapshot=R.Compact(data,"day_start")}
    history.points[#history.points+1]=point
end

-- 旧存档首次启用回溯时，只保留“此刻”的完整进度；不伪造更早的日开头。
function R.EnsureCurrent(data)
    if type(data)~="table" or type(data.chapter)~="table" or data.chapter.phase~="operating" then return data end
    if data.chapter.rewind then return data end
    -- 只有真正开始过的旅程才补“此刻”；未开局的旧测试态不能因此变形。
    if data.chapter.started~=true then return data end
    if not data.live or not data.live.gameFlow or data.live.gameFlow.phase~="day" then return data end
    local day=data.live.gameFlow.day
    data.chapter.rewind={version=R.VERSION,run=1,branch=0,points={{
        id=string.format("run:1:current:%d",data.revision),day=day,
        label=string.format("第 %d 天 · 启用回溯时",day),at="current",revision=data.revision,
        contentVersion=data.contentVersion,snapshot=R.Compact(data,"current")}},backup=false}
    return data
end

-- 收尾/结局时只保留本轮身份，完整历史已经在结局前 checkpoint 内。
function R.Identity(history)
    return {version=R.VERSION,run=history and history.run or 1,branch=history and history.branch or 0,
        points={},backup=false}
end

function R.Start(data)
    if type(data)~="table" or type(data.chapter)~="table" or data.chapter.phase~="operating" then return data end
    if data.chapter.rewind then return data end
    data.chapter.rewind={version=R.VERSION,run=1,branch=0,points={},backup=false}
    append(data,data.live.gameFlow.day)
    return data
end

function R.NewRun(data,oldRun)
    if type(data)~="table" or type(data.chapter)~="table" or data.chapter.phase~="operating" then return data end
    data.chapter.rewind={version=R.VERSION,run=math.max(1,oldRun or 1)+1,branch=0,points={},backup=false}
    append(data,data.live.gameFlow.day)
    return data
end

function R.Advance(data)
    if type(data)~="table" or type(data.chapter)~="table" or data.chapter.phase~="operating" then return data end
    local history=data.chapter.rewind
    if not history then
        history={version=R.VERSION,run=1,branch=0,points={},backup=false}
        data.chapter.rewind=history
    end
    -- 回到过去后重新跨天时，旧分支的后续日节点不能与今天混在一起。
    for i=#history.points,1,-1 do
        if history.points[i].day>=data.live.gameFlow.day then table.remove(history.points,i) end
    end
    append(data,data.live.gameFlow.day)
    return data
end

-- 回溯产生新 revision；待确认订单的基准必须同步到新版本，否则整档审计会判为过期。
local function rebase(candidate)
    local order=candidate.currentOrder
    if type(order)=="table" and order.phase=="pending" and type(order.baseline)=="table" then
        order.baseline.revision=candidate.revision
    end
    return candidate
end

function R.PlanRestoreDay(data,request,content,limit)
    return G.Run(function()
        G.Pure(request,"rewind.request")
        G.Keys(request,{pointId=true,expectedRevision=true},"rewind.request","INVALID_REQUEST")
        G.Need(U.String(request.pointId) and U.Integer(request.expectedRevision),"INVALID_REQUEST",
            "rewind.request","缺少回溯节点或存档版本")
        G.Need(data.chapter.phase=="operating","INVALID_CHAPTER_STATE","phase","收尾或结局阶段不能回到经营日")
        G.Need(request.expectedRevision==data.revision,"STALE_REVISION","expectedRevision","进度已变化，请重新查看回溯")
        local history=data.chapter.rewind
        G.Need(history and #history.points>0,"NO_REWIND_POINT","chapter.rewind","还没有可回到的日开头记录")
        local point
        for _,row in ipairs(history.points) do if row.id==request.pointId then point=row;break end end
        G.Need(point~=nil,"UNKNOWN_REWIND_POINT","pointId","该回溯节点不存在或已被截断")
        G.Need(point.contentVersion==content.contentVersion,"CONTENT_VERSION_MISMATCH","contentVersion","记录来自不同内容版本，不能恢复")
        local materialized=G.Value(R.Materialize(point.snapshot,data))
        G.Value(require("systems.OrderTrial").ValidateCheckpoint(materialized,content,limit))
        local backup={day=data.live.gameFlow.day,label=string.format("回溯前 · 第 %d 天",data.live.gameFlow.day),
            revision=data.revision,contentVersion=data.contentVersion,snapshot=R.FullSnapshot(data),
            points=U.Copy(history.points),run=history.run}
        G.Value(require("systems.OrderTrial").ValidateCheckpoint(backup.snapshot,content,limit))
        local candidate=U.Copy(materialized)
        candidate.chapter.memories=U.Copy(data.chapter.memories)
        candidate.chapter.started=true
        candidate.chapter.checkpoint=false
        local points={}
        for _,row in ipairs(history.points) do
            if row.day<=point.day then points[#points+1]=U.Copy(row) end
        end
        candidate.chapter.rewind={version=R.VERSION,run=history.run,branch=(history.branch or 0)+1,
            points=points,backup=backup}
        candidate.revision=data.revision+1
        rebase(candidate)
        return {data=candidate,value={restoredDay=point.day,backupDay=backup.day,revision=candidate.revision},
            events={"RewindRestored"},changed=true}
    end)
end

function R.PlanRestoreBackup(data,request,content,limit)
    return G.Run(function()
        G.Pure(request,"rewind.request")
        G.Keys(request,{expectedRevision=true},"rewind.request","INVALID_REQUEST")
        G.Need(U.Integer(request.expectedRevision),"INVALID_REQUEST","expectedRevision","缺少存档版本")
        G.Need(data.chapter.phase=="operating","INVALID_CHAPTER_STATE","phase","收尾或结局阶段不能恢复回溯前进度")
        G.Need(request.expectedRevision==data.revision,"STALE_REVISION","expectedRevision","进度已变化，请重新查看回溯")
        local history=data.chapter.rewind
        local backup=history and history.backup
        G.Need(type(backup)=="table","NO_REWIND_BACKUP","chapter.rewind.backup","没有可恢复的回溯前备份")
        G.Need(backup.contentVersion==content.contentVersion,"CONTENT_VERSION_MISMATCH","contentVersion","备份来自不同内容版本，不能恢复")
        G.Value(require("systems.OrderTrial").ValidateCheckpoint(backup.snapshot,content,limit))
        local candidate=U.Copy(backup.snapshot)
        candidate.chapter.memories=U.Copy(data.chapter.memories)
        candidate.chapter.started=true
        candidate.chapter.checkpoint=false
        candidate.chapter.rewind={version=R.VERSION,run=backup.run,branch=(history.branch or 0)+1,
            points=U.Copy(backup.points),backup=false}
        candidate.revision=data.revision+1
        rebase(candidate)
        return {data=candidate,value={restoredDay=backup.day,revision=candidate.revision,restoredBackup=true},
            events={"RewindBackupRestored"},changed=true}
    end)
end
return R
