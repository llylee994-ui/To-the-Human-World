-- Real furniture transactions through the shop. Isolated file/widget host.
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local View=require "ui.PlayView"
local T={}
function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    require("ui.landscape.tests.ZoomTestHost").New()
    local content=U.Copy(Data);content.furniture=require "data.furniture"
    content.stage1.initialEconomy.currency=1000
    local x=F.New(content,{targetSchema=3});local view=View.New(x.session,content)
    local count=0
    local function check(value,why) count=count+1;assert(value,why) end
    local function widget(id) return assert(view.root:FindById(id),id) end
    local function click(id) local node=widget(id);check(not node.props.disabled,"disabled "..id);node.props.onClick();view.Update() end
    view.Open("shop");view.Update()
    check(view.root:FindById("shopTab_furniture"),"shop must offer furniture category without shrinking nine goods")
    local before,writes=x.state.GetSnapshot(),x.writes
    click("shopTab_furniture")
    for _,id in ipairs({"decor_tablecloth","decor_chair"}) do check(view.root:FindById("shop_select_"..id),"missing furniture "..id) end
    click("shopNextPage")
    for _,id in ipairs({"decor_lamp","decor_bookshelf"}) do check(view.root:FindById("shop_select_"..id),"missing furniture "..id) end
    click("shopPreviousPage")
    click("shop_select_decor_chair")
    check(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes,"category/selection never buys")
    check(widget("shopItemName"):GetText()=="椅子","detail follows furniture selection")
    click("buy_decor_chair")
    check(x.state.GetSnapshot().live.economy.currency==900,"chair costs exactly 100")
    check(widget("buy_decor_chair").props.disabled,"owned chair cannot buy twice")
    check(widget("shopItemOwned"):GetText():find("已拥有",1,true),"owned status remains visible")
    check(x.state.ReloadCurrent(),"purchase reload through same live coordinator")
    view.Refresh();view.Update();check(widget("buy_decor_chair").props.disabled,"ownership survives reload")
    click("shopNextPage");before,writes=x.state.GetSnapshot(),x.writes
    click("shop_select_decor_lamp");x.fault="write";click("buy_decor_lamp");x.fault=false
    check(U.Equal(before,x.state.GetSnapshot()),"save failure cannot debit lamp")
    check(not widget("buy_decor_lamp").props.disabled,"failed purchase can retry")
    click("buy_decor_lamp");check(x.state.GetSnapshot().live.economy.currency==760,"retry charges once")
    click("shopTab_ingredients");check(view.root:FindById("shop_select_ing_sea_salt"),"ingredients remain separate")
    click("shopTab_tickets");check(view.root:FindById("shop_select_travel_ticket"),"travel ticket remains separate")
    check(not view.root:FindById("shop_select_decor_curtain") and not view.root:FindById("shop_select_decor_bed") and not view.root:FindById("shop_select_decor_fireplace"),"superseded goods must not appear")
    local poorContent=U.Copy(content);poorContent.stage1.initialEconomy.currency=30
    local poor=F.New(poorContent,{targetSchema=3});view=View.New(poor.session,poorContent);view.Open("shop");view.Update()
    click("shopTab_furniture");click("shop_select_decor_tablecloth")
    check(widget("buy_decor_tablecloth").props.disabled,"30 coins cannot buy tablecloth")
    check(widget("shopItemReason"):GetText():find("金币不足",1,true),"insufficient funds explain disabled button")
    print("[FurnitureShopViewTest] PASS assertions="..count.."; actual purchase/save/reload through isolated widget host")
    return count
end
return T
