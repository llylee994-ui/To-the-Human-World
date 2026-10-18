-- CSS/base-pixel geometry and real game-state regressions. No Yoga/device claim.
local T={}
function T.Run()
    local UI=require "urhox-libs/UI" --[[@as table]]
    local U=require "core.StateUtil"
    local R=require "ui.landscape.Responsive"
    local B=require "ui.landscape.BrewLayout"
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local n=0
    local function check(value,why) n=n+1;assert(value,why) end
    local sizes={{568,320},{640,360},{800,360},{844,390},{960,540},{1024,768},{1280,720},{1920,1080}}
    local safe={left=28,right=64,top=0,bottom=16}
    local function inside(r,m)
        return r.w>0 and r.h>0 and r.x>=m.x and r.y>=m.y
            and r.x+r.w<=m.x+m.w+.01 and r.y+r.h<=m.y+m.h+.01
    end
    for _,size in ipairs(sizes) do
        local vp={w=size[1],h=size[2]};local m=R.Metrics(vp,safe);local l=B.Compute(vp.w,vp.h,safe)
        for _,key in ipairs({"wish","pot","summary","shelf","controls"}) do
            check(inside(l[key],m),key.." outside usable "..vp.w.."x"..vp.h)
        end
        check(l.shelf.y+l.shelf.h<=l.controls.y,"ingredients must not cover brew action")
        for _,slot in ipairs(l.slots) do
            check(inside(slot,m),"slot outside safe viewport")
            if m.short then check(slot.w>=44 and slot.h>=44,"phone slots need a full touch target") end
        end
        if m.short then
            local width=R.SideWidth(vp,safe)
            local tray=require("ui.landscape.WordTrayArt").Fit(width,m.h-24,true)
            local book=require("ui.landscape.JournalBookArt").Fit(width,m.h-24,true)
            check(tray.cards.w>=160 and tray.cards.h>=44,"short tray must keep readable cards")
            check(tray.cards.x+tray.cards.w<=tray.tabs.x,"category buttons must not overlap cards")
            check(tray.pager.y+44<=m.h-24-86,"paging must not cover the selection action")
            check(book.content.w>=160 and book.content.h>=140,"short book must have a usable reading region")
        end
    end

    -- Explicit scroll API adapter; production uses the engine ScrollView methods.
    local originalScroll=UI.ScrollView
    UI.ScrollView=function(props)
        local node=originalScroll(props) --[[@as table]]
        function node:GetScroll() return self.testScrollX or 0,self.testScrollY or 0 end
        function node:SetScrollDirect(x,y) self.testScrollX=x;self.testScrollY=y end
        return node
    end
    local oldViewport,oldInsets=UI.GetViewportSize,UI.GetSafeAreaInsets
    local vp={w=1280,h=720}
    UI.GetViewportSize=function() return vp.w,vp.h end
    UI.GetSafeAreaInsets=function() return safe end
    local Data=U.Copy(require "data.content");Data.release=nil
    local F=require "debug.fixtures.B5Fixtures"
    local x=F.New(Data,{targetSchema=3})
    local v=require("ui.PlayView").New(x.session,Data)
    local function update()
        host.width=vp.w;host.height=vp.h;host.Bind(v.root);v.Update()
    end
    local function must(r) return F.Must(r) end
    local received=must(v.model.Receive("letter_pa_01"));must(v.Read(received.letterInstanceId));update()
    local before,writes=x.state.GetSnapshot(),x.writes
    local scroll=assert(v.root:FindById("playScroll"));scroll:SetScrollDirect(0,145)
    for _,size in ipairs(sizes) do
        vp={w=size[1],h=size[2]};update();update();update()
        local paper=assert(v.root:FindById("letterPaper"))
        check(paper.props.fontSize==18,"reflow must not shrink letter font")
        check(v.root:FindById("playScroll").testScrollY==145,"rebuild must retain reading offset")
        check(v.root:FindById("closePanel").props.minHeight>=44,"reader close remains touchable")
    end
    check(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes,"resizing a letter must not save or cut")
    for _,span in ipairs(must(x.modules.letters.GetView(received.letterInstanceId)).spans) do must(v.model.Cut(span.spanId)) end
    must(v.model.Accept())
    v.Open("shop");update()
    local goods=must(x.session.queries.GetShopView()).items
    local chosen=goods[#goods].ingredientId
    v.shopPage=math.ceil(#goods/v.shopPerPage);v.shopSelectedId=chosen;v.Refresh();update()
    check(v.shopSelectedId==chosen,"test must select a visible shop item before resize")
    before,writes=x.state.GetSnapshot(),x.writes
    vp={w=640,h=360};update();update()
    check(v.shopSelectedId==chosen and v.shopPerPage==1,"compact pagination preserves selected good: "..tostring(v.shopSelectedId).." / "..chosen.." page size "..tostring(v.shopPerPage).." viewport "..v.viewport.w)
    check(v.root:FindById("buy_"..chosen)~=nil,"selected good remains purchasable after reflow")
    vp={w=1280,h=720};update();update()
    check(v.shopSelectedId==chosen and v.shopPerPage==2,"wide pagination preserves selected good")
    check(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes,"shop reflow must not purchase or save")
    v.Close();v.Navigate("brew");update()
    local recipe=assert(require("debug.fixtures.NumericV02Cases")[1]).recipe
    local tokens={};for _,card in ipairs(must(x.session.queries.GetWordTray()).cards) do tokens[card.wordId]=card.tokenId end
    must(v.model.Drop("word",assert(tokens[recipe.mainWordId])))
    for _,id in ipairs(recipe.auxWordIds or {}) do must(v.model.Drop("word",assert(tokens[id]))) end
    for _,row in ipairs(recipe.ingredients) do for _=1,row.quantity do must(v.model.Drop("ingredient",row.ingredientId)) end end
    update();check(v.brew.Start(),"fixture must begin an actual saved trial")
    before,writes=x.state.GetSnapshot(),x.writes
    for _,size in ipairs(sizes) do
        vp={w=size[1],h=size[2]};update();update()
        check(v.brew.interaction.active,"viewport resize must not cancel the brew animation")
        check(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes,"viewport resize must not repeat trial/consume/reward")
    end
    v.root:Destroy()
    UI.GetViewportSize,UI.GetSafeAreaInsets,UI.ScrollView=oldViewport,oldInsets,originalScroll

    -- Official launch arguments carry layout only; the console marker acknowledges this page.
    local oldPlatform,oldArgs,oldPrint=GetPlatform,GetArguments,print
    local markerCount=0
    print=function(message) if tostring(message):find("[HumanWorldResponsiveReady]test-session",1,true) then markerCount=markerCount+1 else oldPrint(message) end end
    GetPlatform=function() return "Web" end
    local args={"-human_world_layout=1","-human_world_layout_session=test-session",
        "-human_world_safe_left=28","-human_world_safe_right=64","-human_world_safe_top=0","-human_world_safe_bottom=16"}
    GetArguments=function() return args end
    package.loaded["ui.landscape.HostViewport"]=nil
    local H=require "ui.landscape.HostViewport"
    local reported=assert(H.Read({w=800,h=360}))
    check(reported.left==28 and reported.right==64 and reported.bottom==16,"launch insets are UI CSS pixels")
    reported=assert(H.Read({w=568,h=320}))
    check(reported.right==64 and markerCount==1,"resize retains touch-size insets without another handshake")
    for _,bad in ipairs({"-human_world_safe_left=-1","-human_world_safe_left=513","-human_world_safe_left=oops"}) do
        args[3]=bad;package.loaded["ui.landscape.HostViewport"]=nil
        check(require("ui.landscape.HostViewport").Read({w=800,h=360})==nil,"invalid launch insets fall back safely")
    end
    args={};package.loaded["ui.landscape.HostViewport"]=nil
    check(require("ui.landscape.HostViewport").Read({w=800,h=360})==nil and markerCount==1,"ordinary Maker/browser does not acknowledge APK contract")
    GetPlatform,GetArguments,print=oldPlatform,oldArgs,oldPrint
    print("[ResponsiveTest] PASS assertions="..n.."; 8 CSS sizes, read/shop/trial state, safe-area handshake; NOT Yoga or phone evidence")
    return n
end
return T
