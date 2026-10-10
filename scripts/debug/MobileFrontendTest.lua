-- 实际玩家入口和触屏按钮回调；显式File/UI替身，不作为手机或布局验收。
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local V=require "ui.PlayView"
local T={}
function T.Run()
    local UI=require "urhox-libs/UI"
    local root=assert(UI.GetRoot())
    for _,id in ipairs({"debugPanel","debugToggleButton","b2CheckButton"}) do
        assert(not root:FindById(id),"玩家入口不挂载 " .. id)
    end
    -- 此处传入显式事件替身；玩家入口应在读取事件前返回。
    local dispatch=HandleKeyDown --[[@as fun(name:string, data:table)]]
    dispatch("KeyDown",{Key={GetInt=function() return KEY_Z end}})
    assert(not root:FindById("debugPanel"))
    assert(RunB1Checks()==false and RunB2Checks()==false)
    local x=F.New(Data)
    local view=V.New(x.session,Data)
    local function must(r) assert(r.ok,cjson.encode(r.error));return r.value end
    local function control(id) return assert(view.root:FindById(id),id) end
    local function click(id)
        local props=control(id):GetProps();assert(not props.disabled,id)
        props.onClick();view.Update()
    end
    click("receive_letter_pa_01");click("read_letter:letter_pa_01")
    local paper=control("letterPaper")
    local scroll=control("playScroll")
    -- 仅检查没有主动重置滚动；真实像素位置依赖原生布局，不能由替身证明。
    scroll.testScrollY=600
    local messageArea=control("playMessageArea")
    assert(messageArea:GetProps().height==52,"提示区固定高度，换行不挤压信纸")
    local parsed=must(x.modules.letters.ParseDefinition("letter_pa_01"))
    local firstButton=control("cut_" .. parsed.spans[1].spanId)
    local beforeCut=x.state.GetSnapshot()
    x.fault="write";click("cut_" .. parsed.spans[1].spanId)
    assert(U.Equal(beforeCut,x.state.GetSnapshot()),"剪词保存失败保留原状态")
    assert(control("letterPaper")==paper and control("cut_" .. parsed.spans[1].spanId)==firstButton,
        "剪词失败也保留信纸和按钮，避免重新定位")
    assert(scroll.testScrollY==600,"失败不主动重置阅读位置")
    x.fault=false
    for _,span in ipairs(parsed.spans) do
        local button=control("cut_" .. span.spanId)
        click("cut_" .. span.spanId)
        assert(control("letterPaper")==paper,"剪词保留信纸节点，不重建滚动内容")
        assert(control("cut_" .. span.spanId)==button and scroll.testScrollY==600,"连续剪词不重建按钮或重置阅读位置")
        assert(not paper:GetText():find("缺口",1,true))
        assert(control("cut_" .. span.spanId):GetProps().disabled)
    end
    local tokens={}
    for _,card in ipairs(must(x.modules.wordTokens.GetInventory())) do tokens[card.definition.id]=card.tokenId end
    local sleep=assert(tokens.word_candidate_elias_sleep)
    local dream=assert(tokens.word_candidate_elias_dream)
    local forget=assert(tokens.word_candidate_elias_forget)
    local extra=assert(tokens.word_candidate_elias_trust)
    click("acceptOrder")
    local before=x.state.GetSnapshot()
    assert(control("previewOrder"):GetProps().disabled,"空主词不可炼药")
    assert(not view.root:FindById("main_" .. sleep) and not view.root:FindById("aux_" .. sleep))
    x.fault="write";click("card_" .. sleep)
    assert(U.Equal(before,x.state.GetSnapshot()),"首次投料保存失败不产生基准或扣卡")
    assert(view.model.GetDraft().mainTokenId==false)
    x.fault=false;click("card_" .. sleep);click("card_" .. dream);click("card_" .. forget)
    local draft=view.model.GetDraft()
    assert(draft.mainTokenId==sleep and draft.auxTokenIds[1]==dream and draft.auxTokenIds[2]==forget)
    assert(control("card_" .. sleep):GetProps().disabled)
    assert(not view.model.SelectToken(sleep).ok,"同来源不可重复投入")
    click("card_" .. extra)
    assert(U.Equal(view.model.GetDraft(),draft),"满槽拒绝且配方不变")
    click("slot_main")
    draft=view.model.GetDraft()
    assert(draft.mainTokenId==false and draft.auxTokenIds[1]==dream and draft.auxTokenIds[2]==forget)
    assert(control("previewOrder"):GetProps().disabled)
    click("card_" .. sleep)
    assert(view.model.GetDraft().mainTokenId==sleep)
    click("slot_aux_2");click("slot_aux_1")
    click("add_ing_sea_salt")
    assert(U.Equal(before.live,x.state.GetSnapshot().live),"选入与取出不消耗正式资产")
    click("previewOrder")
    local pending=x.state.GetSnapshot()
    assert(pending.currentOrder.phase=="pending" and pending.currentOrder.pending.rating.stars==3)
    assert(not view.model.RemoveToken(sleep).ok and not view.model.SelectToken(extra).ok)
    assert(U.Equal(pending,x.state.GetSnapshot()),"待确认不能改选词或取卡")
    assert(x.Reload());assert(U.Equal(pending,x.state.GetSnapshot()),"待确认恢复相同结果")
    view=V.New(x.session,Data)
    click("resetOrder")
    assert(U.Equal(before.live,x.state.GetSnapshot().live),"撤回保留剪词与库存")
    assert(x.Reload());view=V.New(x.session,Data);click("tab_brew")
    assert(view.model.GetDraft().mainTokenId==false)
    click("card_" .. sleep);click("add_ing_sea_salt");click("previewOrder")
    local second=x.state.GetSnapshot()
    x.fault="write";click("confirmOrder")
    assert(U.Equal(second,x.state.GetSnapshot()),"确认保存失败没有扣卡或发奖")
    x.fault=false;click("confirmOrder")
    local confirmed=x.state.GetSnapshot()
    assert(confirmed.live.economy.currency==before.live.economy.currency+80)
    assert(confirmed.live.economy.ingredients.ing_sea_salt==before.live.economy.ingredients.ing_sea_salt-1)
    assert(not confirmed.live.wordTokens.byId[sleep].available)
    assert(confirmed.live.wordTokens.byId[dream].available and confirmed.live.wordTokens.byId[forget].available)
    local record=second.currentOrder
    x.order.Confirm({orderId=record.orderId,transactionId=record.pending.transactionId})
    assert(U.Equal(confirmed,x.state.GetSnapshot()),"重复确认不再结算")
    assert(x.Reload());assert(U.Equal(confirmed,x.state.GetSnapshot()),"确认后恢复账本不变")
    local debug=require "debug.DebugPanel"
    local debugRoot=UI.Panel {}
    debug.Attach(debugRoot,{gameFlow=require "core.GameFlow",save=function() return true end,load=function() return {},{status="loaded"} end,nextDay=function() return U.Ok({}) end,canMutate=function() return true end})
    debug.SetVisible(true)
    assert(debugRoot:FindById("debugCloseButton")):GetProps().onClick()
    assert(not debug.IsVisible(),"开发面板可通过触屏按钮关闭")
    print("[MobileFrontend] PASS player gate, cut-paper reuse, auto slots, remove-main rule, locks, save failures, reset/reload, exactly-once confirmation, touch close; NOT device/layout acceptance")
    return true
end
return T
