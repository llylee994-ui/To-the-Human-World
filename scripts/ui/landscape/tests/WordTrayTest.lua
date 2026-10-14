-- 托盘抽屉只动视图状态：浏览、切分类、点纸条都不写快照；投入/取出沿用模型动作。
local U=require "core.StateUtil"
local T={}

function T.Run()
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    -- The headless Widget adapter does not load native font measurement.
    local testUI=require "urhox-libs/UI"
    testUI.MeasureTextWidth=testUI.MeasureTextWidth or function(value,size) return utf8.len(value)*size end
    local Data=require "data.content"
    local F=require "debug.fixtures.B5Fixtures"
    local View=require "ui.PlayView"
    local Drawer=require "ui.landscape.WordTrayDrawer"
    local x=F.New(Data,{targetSchema=3})
    -- Browsing needs collected cards, not the deprecated schema-2 BeginBrew.
    local received=F.Must(x.state.ReceiveLetter({letterId="letter_pa_01"}))
    F.Must(x.state.ReadLetter({letterInstanceId=received.letterInstanceId}))
    for _,span in ipairs(F.Must(x.modules.letters.ParseDefinition("letter_pa_01")).spans) do
        F.Must(x.state.CutWord({letterInstanceId=received.letterInstanceId,spanId=span.spanId}))
    end
    local function collect()
        local used={}
        for _, token in pairs(x.state.GetSnapshot().live.wordTokens.byId) do
            local word=Data.GetWord(token.wordId)
            if word then used[word.category]=true end
        end
        local n=0
        for _ in pairs(used) do n=n+1 end
        return n,used
    end
    -- 再剪几封来信的词，让抽屉至少有两个分类可以对照切换。
    for _, definition in ipairs(Data.letters) do
        local distinct=collect()
        if distinct<2 and definition.kind=="order" then
            local received=x.state.ReceiveLetter({letterId=definition.id})
            if received.ok then
                F.Must(x.state.ReadLetter({letterInstanceId=received.value.letterInstanceId}))
                for _, span in ipairs(F.Must(x.modules.letters.ParseDefinition(definition.id)).spans) do
                    x.state.CutWord({letterInstanceId=received.value.letterInstanceId,spanId=span.spanId})
                end
            end
        end
    end
    local distinct,usedCategories=collect()
    local view=View.New(x.session,Data)
    local count=0
    local function check(ok,why) count=count+1;assert(ok,why) end
    local function find(id) return view.root:FindById(id) end
    local function text(id) local node=assert(find(id),"missing "..id);return node:GetText() end
    local function click(id)
        local node=assert(find(id),"missing "..id)
        check(not node.props.disabled,"disabled "..id)
        node.props.onClick();view.Update()
    end
    local function settle(frames)
        for _=1,frames or 20 do host.Step(view,1/60) end
    end
    check(distinct>=2,"fixture collects at least two word categories")
    check(not find("wordTrayFrame"),"drawer stays closed until the tray is used")
    local tray=x.session.queries.GetWordTray().value
    local used=0
    for _ in pairs(usedCategories) do used=used+1 end
    check(#tray.categories==used,"tray query lists exactly the collected categories")
    local collected={}
    for _, category in ipairs(tray.categories) do
        local n=0
        for _, card in ipairs(tray.cards) do if card.categoryId==category.id then n=n+1 end end
        if n>0 then collected[#collected+1]=category end
    end
    check(#collected==#tray.categories and #collected>=2,"every collected category is browsable")
    local before,writes=x.state.GetSnapshot(),x.writes
    view.Open("words");view.Update()
    check(find("wordTrayFrame"),"opening words mounts the tray drawer")
    check(not find("wordTrayEmpty"),"a collected tray is not empty")
    check(Drawer.Progress(view)==0,"drawer starts pulled out of the left edge")
    check(not Drawer.Settled(view),"drawer animates instead of popping in")
    for _, category in ipairs(collected) do
        check(find("wordTrayTab_"..category.id),"tab exists for "..category.id)
        check(find("wordTrayTab_"..category.id).props.text==Drawer.ShortTitle(category.title),"tab label is the short category name")
    end
    settle(20)
    check(Drawer.Progress(view)==1 and Drawer.Settled(view),"drawer slides fully in and settles")
    local panel=assert(find("activePanel"),"drawer keeps the overlay panel id")
    check(panel.props.width>=math.floor(1280*0.3) and panel.props.width<=math.floor(1280*0.5),"drawer keeps the narrow left column")
    check(type(panel.props.backgroundImage)=="string","drawer is dressed with the generated cloth image")
    check(type(find("wordTrayFrame").props.backgroundImage)=="string","strips sit in the generated wooden tray image")
    local first=collected[1]
    local function mounted(categoryId)
        local ids={}
        for _, card in ipairs(tray.cards) do
            if card.categoryId==categoryId and find("wordTrayCard_"..card.tokenId) then ids[#ids+1]=card.tokenId end
        end
        return ids
    end
    check(#mounted(first.id)>0,"selected category mounts its strips")
    for _, category in ipairs(collected) do
        if category.id~=first.id then check(#mounted(category.id)==0,"other categories stay unmounted") end
    end
    check(text("wordTraySource")==first.title.." · 可用 "..first.availableCount,"footer reports the active category stock")
    check(find("wordTrayHint"),"footer invites picking a strip")
    local second=collected[2]
    click("wordTrayTab_"..second.id)
    check(view.wordTray.category==second.id,"tab click switches the category")
    check(view.wordTray.selected==false,"switching category clears the picked strip")
    check(#mounted(second.id)>0 and #mounted(first.id)==0,"only the active category is shown")
    ---@type table|false
    local card=false
    for _, candidate in ipairs(tray.cards) do if candidate.categoryId==second.id then card=candidate end end
    assert(card,"selected category must own at least one strip")
    click("wordTrayCard_"..card.tokenId)
    check(view.wordTray.selected==card.tokenId,"strip click picks it")
    check(text("wordTraySource")=="来源："..card.sourceTitle,"footer names the source letter")
    check(text("wordTrayStatus")==Drawer.StatusText(card),"footer repeats the strip state")
    check(find("wordTrayAction_"..card.tokenId)==nil,"the tray no longer drops words; dragging will own that")
    check(find("closePanel").props.text=="×","the drawer closes with a ×")
    check(Drawer.StatusText({available=true})=="可用","available strips read 可用")
    check(Drawer.StatusText({available=false})=="已消耗","consumed strips read 已消耗")
    check(Drawer.StatusText({available=true,selectedRole="main"})=="已投入 · 主词","main role reads 已投入 · 主词")
    check(Drawer.StatusText({available=true,selectedRole="aux"})=="已投入 · 辅词","aux role reads 已投入 · 辅词")
    check(Drawer.MarkText({available=false})=="已用" and Drawer.MarkText({available=true})==false,"only marked strips carry a corner chip")
    check(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes,"browsing and picking never write a snapshot")
    click("closePanel")
    check(not Drawer.Settled(view),"close slides out before leaving")
    settle(20)
    check(Drawer.Progress(view)==0 and view.panel==false,"drawer leaves the room closed")
    view.Open("words");settle(20)
    view.Navigate("brew")
    check(Drawer.Settled(view) and Drawer.Progress(view)==0,"leaving the scene cancels the drawer")
    local empty=F.New(Data,{targetSchema=3})
    local emptyView=View.New(empty.session,Data)
    emptyView.Open("words");emptyView.Update()
    for _=1,20 do host.Step(emptyView,1/60) end
    check(emptyView.root:FindById("wordTrayEmpty"),"an empty tray explains how words arrive")
    check(emptyView.root:FindById("wordTrayTabs")==nil,"an empty tray shows no category tabs")
    print("[WordTrayTest] PASS assertions="..count.."; real query/session, view-state browsing, drawer animation cancel; native evidence separate")
    return count
end
return T
