-- 点击真实 PlayView 的按钮，业务全走生产 GameSession；控件为 HeadlessUI，非视觉验收。
local U=require "core.StateUtil"
local F=require "debug.fixtures.B5Fixtures"
local C=require "debug.fixtures.B4Fixtures"
local V=require "ui.PlayView"
local T={}
function T.Run()
    local total,failed=0,0
    local function check(name,actual,expected)
        total=total+1
        if not U.Equal(actual,expected) then failed=failed+1; print("[B6] FAIL " .. name .. " actual=" .. cjson.encode(actual)) end
    end
    local flow=require "core.GameFlow"; local original=flow.GetSnapshot()
    local ok,err=pcall(function()
        local x=F.New(C.Content())
        local view=V.New(x.session,x.content)
        local function widget(id) return assert(view.root:FindById(id),"missing button " .. id) end
        local function click(id)
            local w=widget(id); assert(not w:GetProps().disabled,"disabled button " .. id)
            w:GetProps().onClick(); view.Update()
        end
        local function collect(id)
            click("tab_mail"); click("receive_" .. id); click("read_letter:" .. id)
            for _,span in ipairs(C.Must(x.modules.letters.ParseDefinition(id)).spans) do click("cut_" .. span.spanId) end
            for _,span in ipairs(C.Must(x.modules.letters.ParseDefinition(id)).spans) do check("cut disabled " .. span.spanId,widget("cut_" .. span.spanId):GetProps().disabled,true) end
            click("acceptOrder")
        end
        local function token(word,letterId)
            for _,card in ipairs(C.Must(x.modules.wordTokens.GetInventory())) do
                if card.definition.id==word and card.available and (not letterId or card.source.sourceLetterInstanceId=="letter:" .. letterId) then return card.tokenId end
            end
            error("missing available " .. word)
        end
        collect("letter_pa_01")
        local sleepWord=x.content.GetWord("word_sleep")
        check("word card shows literal and category",widget("wordGroup_word_sleep"):GetText():find(sleepWord.displayText .. " · " .. sleepWord.category,1,true)~=nil,true)
        local before=x.state.GetSnapshot()
        x.fault="write"
        click("main_" .. token("word_sleep"))
        check("baseline save failure remains accepted",x.state.GetSnapshot(),before)
        check("failed first selection not kept",view.model.GetDraft().mainTokenId,false)
        check("save failure visible",#widget("playMessage"):GetText()>0,true)
        x.fault=false
        click("main_" .. token("word_sleep"))
        click("aux_" .. token("word_sleep"))
        check("same token rejected in UI",#view.model.GetDraft().auxTokenIds,0)
        click("add_ing_sea_salt"); click("add_ing_night_dew")
        click("add_ing_dried_petal")
        check("UI respects two ingredient slots",#view.model.GetDraft().ingredients,2)
        local base=x.state.GetSnapshot()
        check("draft never consumes",base.live,before.live)
        click("previewOrder")
        local pending=x.state.GetSnapshot()
        check("UI previews pending",pending.currentOrder.phase,"pending")
        check("preview no formal settlement",pending.live,base.live)
        check("consumption preview exists",#pending.currentOrder.pending.consumption.consumedTokenIds,1)
        click("tab_mail")
        check("pending blocks cross day",widget("nextDay"):GetProps().disabled,true)
        click("tab_result")
        x.fault="write"; click("confirmOrder")
        check("failed confirmation retains result",x.state.GetSnapshot(),pending)
        check("failed confirmation stays result",view.model.page,"result")
        x.fault=false
        -- 模拟新装配读取同一隔离文件介质，直接回待确认页。
        assert(x.Reload()); view=V.New(x.session,x.content)
        check("pending restart opens result",view.model.page,"result")
        check("pending restart unchanged",x.state.GetSnapshot(),pending)
        click("resetOrder")
        check("reset returns brewing",view.model.page,"brew")
        check("reset cards and gaps",x.state.GetSnapshot().live,base.live)
        check("reset clears trial selection",view.model.GetDraft().mainTokenId,false)
        click("main_" .. token("word_sleep")); click("add_ing_sea_salt"); click("add_ing_night_dew")
        click("previewOrder"); click("confirmOrder")
        check("first reward once",x.state.GetSnapshot().live.economy.currency,110)
        local confirmed=x.state.GetSnapshot(); local writes=x.writes
        click("history_order:1")
        check("reopen result no write",x.writes,writes)
        check("reopen result no consumption",x.state.GetSnapshot(),confirmed)
        click("continueGame"); click("nextDay")
        collect("letter_n01")
        click("main_" .. token("word_steady_hands")); click("add_ing_sea_salt"); click("add_ing_night_dew")
        click("previewOrder"); click("confirmOrder"); click("continueGame")
        click("nextDay"); click("nextDay")
        collect("letter_n02")
        local firstSmile=token("word_smile","letter_pa_01")
        local n02Smile=token("word_smile","letter_n02")
        check("same literal keeps two source cards",firstSmile~=n02Smile,true)
        click("main_" .. n02Smile); click("add_ing_sea_salt"); click("add_ing_night_dew")
        click("previewOrder"); click("confirmOrder")
        local final=x.state.GetSnapshot()
        check("buttons finish three real orders",final.live.gameFlow.deliveredOrders,3)
        check("buttons balance",final.live.economy.currency,270)
        check("buttons remaining definitions",C.Must(x.modules.wordTokens.GetInventoryView()).availableDefinitionCount,11)
        check("N02 uses selected source",final.live.wordTokens.byId[n02Smile].consumedByOrderId,"order:3")
        check("first letter smile remains available",token("word_smile","letter_pa_01"),firstSmile)
        assert(x.Reload()); view=V.New(x.session,x.content); click("tab_result"); click("history_order:3")
        check("confirmed reload no reward",x.state.GetSnapshot(),final)
        -- 独立新档：字面失败可见，调整后可再试，不跳过失败。
        x=F.New(C.Content()); view=V.New(x.session,x.content)
        collect("letter_pa_01")
        click("main_" .. token("word_tired")); click("add_ing_sea_salt"); click("add_ing_night_dew")
        before=x.state.GetSnapshot(); writes=x.writes; click("previewOrder")
        check("failed requirement remains brewing",view.model.page,"brew")
        check("failed requirement has reasons",#view.model.failure.failures>0,true)
        check("failed requirement no writes to formal",x.state.GetSnapshot(),before)
        check("failed trial does not save",x.writes,writes)
        check("failed trial exposes calculated effects",view.model.trialPotion.effects,{sleep=0.6,calm=0.6})
        ---@type table|nil
        local sleepEffect
        for _,effect in ipairs(x.content.effects) do if effect.id=="sleep" then sleepEffect=effect end end
        assert(sleepEffect,"missing sleep effect definition")
        check("failed trial shows named effect and intensity",widget("trialEffect_sleep"):GetText(),sleepEffect.name .. "：微弱（0.6）")
        click("main_" .. token("word_sleep"))
        check("editing clears stale trial",view.model.trialPotion,nil)
        click("previewOrder")
        check("adjustment can preview",view.model.page,"result")
        -- 调试隔离时，页面和绕过控件禁用的直接命令都不能操作生产协调器。
        local disabled=V.New(x.session,x.content,function() return false end)
        before=x.state.GetSnapshot()
        check("debug isolated action disabled",disabled.model.Action("Confirm").enabled,false)
        check("debug isolated direct confirm denied",disabled.model.Resolve(true).ok,false)
        check("debug isolated unchanged",x.state.GetSnapshot(),before)
        -- 实际按钮：漏剪后先投原料，返回准备，再补剪；空锅清空不会再次锁住。
        x=F.New(C.Content()); view=V.New(x.session,x.content)
        click("receive_letter_pa_01"); click("read_letter:letter_pa_01"); click("acceptOrder")
        click("clearDraft")
        check("empty clear button leaves preparation",x.state.GetSnapshot().currentOrder.phase,"accepted")
        click("add_ing_sea_salt"); click("cancelBrew")
        check("return preparation button opens reader",view.model.page,"letter")
        local spans=C.Must(x.modules.letters.ParseDefinition("letter_pa_01")).spans
        click("cut_" .. spans[1].spanId)
        check("can cut after preparation button",#C.Must(x.modules.wordTokens.GetInventory()),1)
        -- 提交结果不确定后，实际恢复按钮读取原非默认槽，不能打开另一个新档。
        x=F.New(C.Content()); x.Prepare(); x.Pending("A"); view=V.New(x.session,x.content)
        x.fault="uncertain"; x.commitWritten=false; click("confirmOrder")
        check("uncertain confirmation locks UI",x.state.CanMutate(),false)
        x.fault=false; click("reloadProgress")
        check("reload button restores original slot",x.state.GetSnapshot().live.gameFlow.deliveredOrders,1)
        check("reload button restores confirmed balance",x.state.GetSnapshot().live.economy.currency,110)
        check("reload button unlocks UI",x.state.CanMutate(),true)
        require("debug.BrewPreparationTest").Run(check)
    end)
    flow.Restore(original)
    if not ok then check("runtime " .. tostring(err),false,true) end
    print("[B6] button-adapter checks=" .. total .. " failures=" .. failed .. "; NOT engine/UI rendering acceptance")
    return failed==0
end
return T
