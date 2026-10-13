-- Real shop transactions with isolated File/widget adapters; no native layout evidence.
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local View=require "ui.PlayView"
local T={}
local count=0
local function check(value,message) count=count+1;assert(value,message) end
local function must(result) assert(result.ok,cjson.encode(result.error));return result.value end
function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    require("ui.landscape.tests.ZoomTestHost").New()
    local content=U.Copy(Data);content.stage1.initialEconomy.currency=1000
    local x=F.New(content,{targetSchema=3});local view=View.New(x.session,content)
    local function control(id) return assert(view.root:FindById(id),"missing control "..id) end
    local function click(id)
        if not view.root:FindById(id) and (id=="shop_select_ing_dried_petal" or id=="shop_select_ing_sea_salt") then
            local pageId=id=="shop_select_ing_sea_salt" and "shopPreviousPage" or "shopNextPage"
            control(pageId).props.onClick();view.Update()
        end
        if id=="shop_select_travel_ticket" and not view.root:FindById(id) then
            control("shopTab_tickets").props.onClick();view.Update()
        end
        local w=control(id);check(not w.props.disabled,"unexpectedly disabled "..id)
        w.props.onClick();view.Update()
    end
    view.Open("shop");view.Update()
    check(view.root:FindById("shop_select_ing_night_dew"),"shop needs selection separate from purchase")
    local before,writes=x.state.GetSnapshot(),x.writes
    click("shop_select_ing_night_dew")
    check(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes,"selection must not buy or save")
    check(control("shopItemName"):GetText()=="夜露","selected detail must follow selected product")
    check(not view.root:FindById("buy_ing_sea_salt"),"buy command must follow selection")
    click("buy_ing_night_dew")
    local after=x.state.GetSnapshot();local economy=after.live.economy
    check(economy.currency==before.live.economy.currency-12,"purchase charges actual selected price once")
    check(economy.ingredients.ing_night_dew==before.live.economy.ingredients.ing_night_dew+1,"night dew bought")
    check(economy.ingredients.ing_sea_salt==before.live.economy.ingredients.ing_sea_salt,"other inventory unchanged")
    check(control("shopItemName"):GetText()=="夜露","selection survives purchase refresh")
    check(control("shopItemStock"):GetText():find("5",1,true),"today stock updates after purchase")
    before=x.state.GetSnapshot();x.fault="write";click("buy_ing_night_dew");x.fault=false
    check(U.Equal(before,x.state.GetSnapshot()),"failed save must not install purchased inventory")
    check(control("panelMessage"):GetText()==view.model.message,"failed save stays visible inside shop")
    for _=1,5 do click("buy_ing_night_dew") end
    check(control("buy_ing_night_dew").props.disabled,"daily stock stops purchase")
    check(control("shopItemReason"):GetText():find("售完",1,true),"sold out reason visible")
    before=x.state.GetSnapshot();click("closePanel")
    check(view.scene=="home" and U.Equal(before,x.state.GetSnapshot()),"close returns home without mutation")
    view.Navigate("seaside");view.Update();view.Open("shop");view.Update();click("closePanel")
    check(view.scene=="seaside","shop returns to seaside source")
    -- Existing pending transaction owns shop gate; selection remains read-only.
    local received=must(x.state.ReceiveLetter({letterId="letter_pa_01"}))
    must(view.model.Read(received.letterInstanceId));local parsed=must(x.modules.letters.GetView(received.letterInstanceId))
    local tokens={};for _,span in ipairs(parsed.spans) do tokens[span.wordId]=must(view.model.Cut(span.spanId)).tokenId end
    must(view.model.Accept())
    local sample=assert(require("debug.fixtures.NumericV02Cases")[1]).recipe
    must(view.model.Drop("word",assert(tokens[sample.mainWordId])))
    for _,wordId in ipairs(sample.auxWordIds) do must(view.model.Drop("word",assert(tokens[wordId]))) end
    for _,item in ipairs(sample.ingredients) do for _=1,item.quantity do must(view.model.Drop("ingredient",item.ingredientId)) end end
    local draft=U.Copy(view.model.GetDraft());view.Navigate("brew");view.Update()
    local art=require "ui.landscape.IngredientArt"
    for _,item in ipairs(content.ingredients) do
        check(control("brewArt_"..item.id).props.backgroundImage==art.Get(item.id),"brewing shares same ingredient texture")
    end
    view.Open("shop");view.Update();click("shop_select_ing_dried_petal");click("closePanel")
    check(U.Equal(draft,view.model.GetDraft()) and view.scene=="brew","shop selection preserves saved draft/source")
    must(view.model.Preview());view.Open("shop");view.Update();click("shop_select_ing_sea_salt")
    check(control("buy_ing_sea_salt").props.disabled,"pending blocks purchases")
    check(control("shopItemReason"):GetText()~="","pending reason visible")
    click("shop_select_travel_ticket")
    check(control("buy_travel_ticket").props.disabled,"pending also blocks ticket confirmation entry")
    check(control("shopItemReason"):GetText()~="","ticket pending reason visible")
    before=x.state.GetSnapshot();writes=x.writes;click("closePanel")
    check(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes,"close cannot settle pending")
    -- A normal new game has 30 coins; two purchases leave 6, less than another dew.
    local poor=F.New(Data,{targetSchema=3});view=View.New(poor.session,Data);view.Open("shop");view.Update()
    click("shop_select_ing_night_dew");click("buy_ing_night_dew");click("buy_ing_night_dew")
    check(control("buy_ing_night_dew").props.disabled,"insufficient balance blocks purchase")
    check(control("shopItemReason"):GetText():find("金币不足",1,true),"balance reason visible")
    click("shop_select_ing_sea_salt");check(not control("buy_ing_sea_salt").props.disabled,"affordable alternative remains available")
    -- Query failures and empty stock remain closable and never display stale products.
    local original=poor.session.queries.GetShopView
    poor.session.queries.GetShopView=function() return U.Fail("STATE_LOCKED","shop","测试读取失败") end
    view.Refresh();view.Update();check(control("shopQueryError"),"failed query displays error")
    check(not view.root:FindById("buy_ing_sea_salt"),"failed query cannot leave buy control")
    poor.session.queries.GetShopView=function() return U.Ok({currency=6,items={},enabled=true,message=""}) end
    view.Refresh();view.Update();check(control("shopEmpty"),"empty shop states no products")
    click("closePanel");poor.session.queries.GetShopView=original
    print("[ShopViewTest] PASS assertions="..count.."; actual selected purchase/stock/insufficient/save failure/pending/draft/source; native/mobile separate")
    return true
end
return T
