-- Real 3D Bootstrap/controller/shared pages; only clock, widgets and camera are adapters.
local T={}
local U=require "core.StateUtil"
local Bootstrap=require "v035.lab35.Bootstrap"
local function must(result) assert(result and result.ok,cjson.encode(result));return result.value end
function T.Run()
    local n=0
    local function check(value,message) n=n+1;assert(value,message) end
    local bundle=Bootstrap.New()
    check(bundle.content==require("data.content"),"3D must load current shared content")
    check(bundle.content.contentVersion=="ordinary-release-v2","current release is active")
    check(bundle.session.state.GetStatus().schema==4,"actual 3D session must be schema4")
    check(bundle.session.state.GetSnapshot().chapter.phase=="operating","release chapter initialized")
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local camera={}
    function camera.Start(_,target,done) camera.target=target;camera.done=done;return true end
    function camera.Cancel() camera.done=nil end
    local controller=require("v035.lab35.Controller").New(bundle,camera)
    local view=require("v035.lab35.AppView").New(bundle.session,bundle.content,nil,{
        model=bundle.model,bind=function(ctx)
            controller.Bind(ctx);host.Bind(ctx.root)
        end,
        homeFactory=function(_,developer,releaseMode)
            return require("v035.lab35.HomeView").New(controller,{
                hideCase=releaseMode and not developer,
                ray=function() return {0,0,0},{0,0,1} end,picker={Pick=function() return nil end},
                project=function() return {x=100,y=100} end,hintOccluded=function() return false end})
        end})
    require("urhox-libs/UI").SetRoot(view.root)
    local function finish()
        if camera.done then local done=camera.done;camera.done=nil;done(true) end
        host.Step(view,0)
    end
    local function click(id)
        local w=assert(view.root:FindById(id),"missing actual control "..id)
        check(not w.props.disabled,"disabled actual control "..id)
        w.props.onClick();host.Step(view,0)
    end
    local function home()
        if view.panel then view.Close();host.Step(view,0) end
        if view.scene~="home" then view.Navigate("home");finish() end
    end
    check(view.model==bundle.model and view.session==bundle.session,"one shared model/session")
    check(view.root.props.backgroundColor[4]==0,"3D home stays transparent")
    local before=U.Copy(bundle.session.state.GetSnapshot())
    local count=0
    for id,route in pairs(require "v035.lab35.Ids") do
        home();count=count+1
        check(controller.Activate(id,count,false),"3D entry rejected: "..id)
        if camera.done then
            check(controller.busy,"native camera owns navigation lock")
            host.Step(view,.5)
            check(controller.busy,"flat 2D zoom must not complete native navigation")
        end
        finish()
        local target=route.target
        if target=="case" then
            check(not view.panel and not view.root:FindById("v035Hint."..id),"release case entry and hint must stay hidden")
        else
            check((target=="brew" or target=="seaside") and view.scene==target
                or view.panel==(target=="paper" and "letters" or target),"wrong 3D route "..id)
        end
    end
    check(count==8,"eight semantic objects retained: seven entries and one hidden case")
    home();check(U.Equal(before,bundle.session.state.GetSnapshot()),"opening all entries must not mutate progress")
    click("toggleHomeHints");check(controller.HintsVisible(),"hint toggle remains connected")
    click("toggleHomeHints");check(not controller.HintsVisible(),"hints can be hidden")
    view.Open("shop");host.Step(view,0)
    check(view.root:FindById("shopTab_furniture") and view.root:FindById("shopTab_tickets"),"current main shop tabs present")
    local writes=bundle.storage.WriteCount();local money=before.live.economy.currency
    click("shop_select_ing_night_dew")
    check(bundle.storage.WriteCount()==writes,"selection must not purchase")
    click("buy_ing_night_dew")
    check(bundle.session.state.GetSnapshot().live.economy.currency==money-12,"selected purchase debits exact price")
    click("closePanel");view.Navigate("seaside");finish()
    must(view.StartSalvage());check(view.salvage.active,"real received bottle starts presentation")
    view.SkipSalvage();host.Step(view,0)
    check(view.panel=="reader" and view.readerCache.presentation,"bottle opens main letter presentation")
    host.Step(view,.6)
    local presentation=view.readerCache.presentation
    local letter=must(bundle.session.modules.letters.GetView(bundle.model.selectedLetter))
    local first=assert(letter.spans[1]);must(presentation.Cut(first.spanId));host.Step(view,0)
    check(presentation.motion.flight,"successful cut starts main paper-strip motion")
    local afterCut=bundle.session.state.GetSnapshot()
    view.Open("words");host.Step(view,0)
    check(not presentation.motion.flight,"changing panel cancels display motion")
    check(U.Equal(afterCut,bundle.session.state.GetSnapshot()),"canceling display never repeats or rolls back cut")
    view.Close();host.Step(view,0);view.Read(bundle.model.selectedLetter);host.Step(view,.6)
    letter=must(bundle.session.modules.letters.GetView(bundle.model.selectedLetter))
    local tokens={}
    for _,span in ipairs(letter.spans) do
        if not span.cut then must(bundle.model.Cut(span.spanId)) end
    end
    for _,card in ipairs(must(bundle.session.queries.GetWordTray()).cards) do tokens[card.wordId]=card.tokenId end
    must(bundle.model.Accept())
    local recipe=require("debug.fixtures.NumericV02Cases")[1].recipe
    must(bundle.model.Drop("word",assert(tokens[recipe.mainWordId])))
    for _,id in ipairs(recipe.auxWordIds) do must(bundle.model.Drop("word",assert(tokens[id]))) end
    for _,item in ipairs(recipe.ingredients) do for _=1,item.quantity do must(bundle.model.Drop("ingredient",item.ingredientId)) end end
    view.Navigate("brew");finish()
    check(must(bundle.session.queries.GetOrderSummary()).potionPreview,"real current potion preview available")
    check(view.root:FindById("brewEffectsTitle"),"main potion effects displayed in native brew panel")
    must(bundle.model.Preview());must(bundle.model.Resolve(true))
    home();view.Open("shop");host.Step(view,0);click("shopTab_furniture")
    local offer=must(bundle.session.queries.GetFurnitureShopView()).items[1]
    money=bundle.session.state.GetSnapshot().live.economy.currency
    click("buy_"..offer.furnitureId)
    local purchased=bundle.session.state.GetSnapshot()
    check(purchased.live.economy.currency==money-offer.price,"3D furniture uses schema4 quoted debit")
    check(#purchased.live.economy.itemPurchases==1,"schema4 purchase ledger is populated")
    must(bundle.model.BuyFurniture(offer.furnitureId,offer.quote))
    check(U.Equal(purchased,bundle.session.state.GetSnapshot()),"retrying same furniture cannot double debit")
    assert(bundle.session.state.ReloadCurrent());home()
    click("nextDay");local confirm=assert(view.root:FindById("confirmNextDay")).props.onClick
    local day=bundle.session.state.GetSnapshot().live.gameFlow.day
    confirm();confirm();host.Step(view,0)
    check(bundle.session.state.GetSnapshot().live.gameFlow.day==day+1,"double confirmation advances only one day")
    check(view.root:FindById("playLedger"):GetText():find(tostring(day+1),1,true),"HUD reflects current day")
    local other=Bootstrap.New()
    check(other.session.state.GetSnapshot().live.gameFlow.day==1 and other.storage.WriteCount()==0,"new launch has independent memory progress")
    for _,op in ipairs(bundle.storage.Audit()) do check(op.path:match("^save_d3_lab_v035"),"storage escaped isolated slot") end
    check(not package.loaded["v035.data.content"] and not package.loaded["v035.ui.PlayModel"],"old business snapshot must not be active")
    view.root:Destroy()
    print("[3D shared main] PASS assertions="..n.."; eight entry callbacks, schema4, bottle/reader/cut, main shop/furniture, potion preview, day and memory isolation")
    return true
end
return T
