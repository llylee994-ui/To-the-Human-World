-- Paging is view state only; actual purchase/save/ownership still use real modules.
local U=require "core.StateUtil"
local T={}
function T.Run()
    require("ui.landscape.tests.ZoomTestHost").New()
    local content=U.Copy(require "data.content");content.furniture=require "data.furniture"
    content.stage1.initialEconomy.currency=1000
    local x=require("debug.fixtures.B5Fixtures").New(content,{targetSchema=3})
    local view=require("ui.PlayView").New(x.session,content)
    local count=0
    local function check(v,why) count=count+1;assert(v,why) end
    local function find(id) return view.root:FindById(id) end
    local function click(id)
        local node=assert(find(id),"missing "..id);check(not node.props.disabled,"disabled "..id)
        node.props.onClick();view.Update()
    end
    view.Open("shop");view.Update()
    check(not find("shopGoodsScroll"),"goods must use pages instead of scrolling")
    check(find("shopPageNumber") and find("shopPageNumber"):GetText()=="1 / 2","four ingredients make two pages")
    check(find("shopPreviousPage").props.disabled and not find("shopNextPage").props.disabled,"first page bounds")
    check(find("shop_select_ing_sea_salt") and find("shop_select_ing_night_dew") and not find("shop_select_ing_dried_petal"),"only two goods mounted")
    local before,writes=x.state.GetSnapshot(),x.writes
    click("shopNextPage")
    check(find("shopPageNumber"):GetText()=="2 / 2","next page label")
    check(find("shop_select_ing_ashen_herb") and find("shop_select_ing_dried_petal") and not find("shop_select_ing_sea_salt"),"second page goods")
    check(find("shopNextPage").props.disabled and not find("shopPreviousPage").props.disabled,"last page bounds")
    check(find("shopItemName"):GetText()=="灰烬草","new page selects a visible good")
    click("shop_select_ing_dried_petal")
    check(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes,"paging and selection cannot buy/save")
    click("buy_ing_dried_petal")
    check(x.state.GetSnapshot().live.economy.currency==985,"paged product charges exactly its price")
    check(find("shopPageNumber"):GetText()=="2 / 2" and find("shopItemName"):GetText()=="干花瓣","purchase retains page/selection")
    click("shopTab_furniture")
    check(find("shopPageNumber"):GetText()=="1 / 2","category resets page")
    click("shopNextPage");click("shop_select_decor_bookshelf");click("buy_decor_bookshelf")
    check(x.state.GetSnapshot().live.economy.currency==805 and find("buy_decor_bookshelf").props.disabled,"furniture page ownership")
    click("shopTab_tickets")
    check(find("shopPageNumber"):GetText()=="1 / 1" and find("shopPreviousPage").props.disabled and find("shopNextPage").props.disabled,"one-page ticket")
    click("shopTab_ingredients")
    check(find("shop_select_ing_sea_salt") and find("shopPageNumber"):GetText()=="1 / 2","return to category starts at first page")
    print("[ShopPaginationTest] PASS assertions="..count.."; real queries/transactions, isolated File/widget host")
    return count
end
return T
