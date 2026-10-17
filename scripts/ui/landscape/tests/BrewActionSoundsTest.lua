-- Real UI commands, saved drafts and flight updates; explicit audio/clock adapters.
local T={}
function T.Run()
    Stop()
    package.loaded["debug.DeveloperMode"]=false
    local saved={Node=Node,cache=cache,effect=SOUND_EFFECT,music=SOUND_MUSIC,audio=audio}
    local U=require "core.StateUtil"
    local R=require "debug.fixtures.ReleaseFixtures"
    local App=require "ui.landscape.AppView"
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local events,voices,nodes={},{},{}
    local revised={word_cut="audio/sfx/objects/water-and-scissors-v2/word_cut.wav",
        ingredient_add="audio/sfx/objects/water-and-scissors-v2/ingredient_add.wav",
        ingredient_remove="audio/sfx/objects/water-and-scissors-v2/ingredient_remove.wav",
        word_select="audio/sfx/objects/word_select.wav"}
    local durations={word_cut=1.04,ingredient_add=.68,ingredient_remove=.72,word_select=.18}
    local n,plays,stops=0,0,0
    ---@type table, table, table
    local view,x,request
    local function check(ok,why) n=n+1;assert(ok,why) end
    local function must(result) check(result and result.ok,"accepted fixture/UI command");return result.value end
    SOUND_EFFECT="Effect";SOUND_MUSIC="Music"
    audio={Stop=function() error("global audio stop") end,SetMasterGain=function() error("global audio gain") end}
    cache={GetResource=function(_,kind,path)
        check(kind=="Sound" and path:match("^audio/"),"project resource path")
        return {path=path,SetLooped=function(self,value) self.looped=value end}
    end}
    Node=function()
        local node={removed=0};nodes[#nodes+1]=node
        function node:CreateComponent(kind)
            check(kind=="SoundSource","existing non-positional voice")
            local voice={playing=false};voices[#voices+1]=voice
            function voice:SetSoundType(value) self.kind=value end
            function voice:SetGain(value) self.gain=value end
            function voice:IsPlaying() return self.playing and (self.kind==SOUND_MUSIC or host.now<self.finish) end
            function voice:Stop() if self.kind==SOUND_MUSIC then stops=stops+1 end;self.playing=false end
            function voice:Play(sound,frequency,gain)
                check(frequency==0 and gain>=0 and gain<=1,"authored rate and shared volume")
                local id=sound.path:match("/([^/]+)%.wav$")
                self.playing=true;self.path=sound.path;self.gain=gain;self.finish=host.now+(durations[id] or .05)
                if self.kind==SOUND_MUSIC then
                    plays=plays+1;check(sound.looped,"music loop preserved")
                else
                    check(self.kind==SOUND_EFFECT and sound.looped==false,"single non-looped effect")
                    if revised[id] then check(sound.path==revised[id],"exact selected version for "..id) end
                    local reader=view and view.readerCache and view.readerCache.presentation
                    events[#events+1]={id=id,path=sound.path,gain=gain,flight=view and view.brew.interaction.flight,
                        cutTime=reader and reader.motion.flight and reader.motion.flight.time}
                end
            end
            return voice
        end
        function node:RemoveAllComponents() self.removed=self.removed+1 end
        return node
    end
    local function update() view.Update();host.Bind(view.root) end
    local function step(dt) host.Step(view,dt);host.Bind(view.root) end
    local function advance(time)
        while time>.00001 do local dt=math.min(.1,time);step(dt);time=time-dt end
    end
    local function control(id) return assert(view.root:FindById(id),id) end
    local function click(id)
        local widget=control(id);check(not widget.props.disabled,"enabled "..id)
        local event={x=100,y=100,pointerId=2,pointerType="touch",button=MOUSEB_LEFT}
        if widget.props.onPointerDown then widget.props.onPointerDown(event) end
        if widget.props.onPointerUp then widget.props.onPointerUp(event) end
        widget.props.onClick(widget);update()
        return widget
    end
    local function showWord(id)
        for _,card in ipairs(must(x.session.queries.GetWordTray()).cards) do
            if card.tokenId==id then click("wordTrayTab_"..card.categoryId);return end
        end
        error("missing word "..id)
    end
    local function expect(id,fn)
        local before,mp,ms=#events,plays,stops
        fn()
        check(#events==before+(id and 1 or 0),"exact sound count: "..tostring(id))
        if id then check(events[#events].id==id,"correct exclusive sound "..id) end
        check(plays==mp and stops==ms,"object operation does not restart/stop BGM")
    end
    local function fresh()
        if view then view.root:Destroy() end
        x=R.New(1000);x.content.stage1.recipePolicy.repeatIngredient=true
        request=R.Accept(x,1)
        for _,id in ipairs({"ing_sea_salt","ing_night_dew"}) do
            local shortage=3-(x.state.GetSnapshot().live.economy.ingredients[id] or 0)
            if shortage>0 then must(x.state.Shop({ingredientId=id,quantity=shortage})) end
        end
        local before=#events;view=App.New(x.session,x.content)
        host.Bind(view.root);view.Navigate("brew");update();step(0)
        check(#events==before,"initialization and navigation silent")
    end
    local function freshReader()
        if view then view.root:Destroy() end
        x=R.New(1000);view=App.New(x.session,x.content);host.Bind(view.root)
        local letter=must(view.model.Receive(x.content.release.requiredOrderIds[1])).letterInstanceId
        must(view.Read(letter));update();advance(.45)
        return view.readerCache.presentation,must(x.modules.letters.GetView(letter)).spans
    end
    local function land(id)
        local flight=assert(view.brew.interaction.flight,"accepted flight")
        expect(false,function() advance(math.max(0,flight.duration-flight.elapsed-.01)) end)
        expect(id,function() advance(.02) end)
        if id then check(not events[#events].flight,"sound follows actual flight completion") end
        expect(false,function() advance(.5);view.Refresh();update() end)
    end
    local function add(kind,id)
        expect(false,function() must(view.brew.Throw(kind,id)) end)
        land(kind=="word" and "word_add" or "ingredient_add")
    end
    local function e(px,py) return {x=px,y=py,pointerId=1,pointerType="touch",button=MOUSEB_LEFT} end
    local function drag(id,valid)
        local source=control(id);local target=view.brew.layout.drop
        source.props.onPointerDown(e(100,100))
        local event=e(valid and target.x+target.w/2 or 1,valid and target.y+target.h/2 or 1)
        source.props.onPointerMove(event);source.props.onPointerUp(event)
        source.props.onClick(source,event) -- A synthesized click after release must stay silent.
        update()
    end
    local ok,err=xpcall(function()
        -- Successful saved cuts play once at animation start, never three calls or a longer animation.
        local paper,spans=freshReader()
        check(#spans>=3,"reader fixture has at least three real spans")
        expect(false,function() check(not paper.Cut("missing-span").ok,"invalid cut rejected") end)
        local action=view.model.Action;view.model.Action=function() return {enabled=false} end
        expect(false,function() check(not paper.Cut(spans[1].spanId).ok,"disabled cut rejected") end)
        view.model.Action=action;x.fault="write"
        expect(false,function() check(not paper.Cut(spans[1].spanId).ok,"failed cut write rejected") end);x.fault=false
        check(not paper.motion.flight,"failure starts no animation")
        expect("word_cut",function() must(paper.Cut(spans[1].spanId));paper.Cut(spans[1].spanId) end)
        check(events[#events].cutTime==0,"sound at the actual animation start")
        expect(false,function() update();advance(1.01);paper.Cut(spans[1].spanId) end)
        check(not paper.motion.flight and require("ui.landscape.LetterMotion").cutDuration==1,"original one-second animation")
        local stillPlaying=false
        for _,voice in ipairs(voices) do if voice.path==revised.word_cut and voice:IsPlaying() then stillPlaying=true end end
        check(stillPlaying,"1.04s sound may finish after animation without blocking the next cut")
        expect("word_cut",function() must(paper.Cut(spans[2].spanId)) end)
        expect(false,function() update();advance(1.1) end)
        -- Real duplicate model command with a stale presentation must not pretend to change state.
        must(view.model.Cut(spans[3].spanId))
        expect(false,function() local result=paper.Cut(spans[3].spanId);check(result.ok and not result.value.changed,"unchanged model result");update() end)
        check(not paper.motion.flight,"unchanged cut starts no animation")
        local letter=view.model.selectedLetter
        expect(false,function() view.Close();update();paper.Cut(spans[1].spanId);view.Read(letter);update();advance(.45) end)
        check(not view.readerCache.presentation.motion.flight,"restoring the reader does not replay cuts")

        paper,spans=freshReader()
        click("openSettings");control("soundVolume"):SetValue(23)
        expect(false,function() check(not paper.Cut(spans[1].spanId).ok,"covered cut rejected") end)
        click("closeMusicSettings")
        expect("word_cut",function() must(paper.Cut(spans[1].spanId)) end)
        check(events[#events].gain==.23,"cut uses shared volume");advance(1.1)
        click("openSettings");control("soundEnabled"):SetValue(false);click("closeMusicSettings")
        expect(false,function() must(paper.Cut(spans[2].spanId));update();advance(1.1) end)
        click("openSettings");control("soundEnabled"):SetValue(true);control("soundVolume"):SetValue(0);click("closeMusicSettings")
        expect(false,function() must(paper.Cut(spans[3].spanId));update();advance(1.1) end)
        click("openSettings");control("soundVolume"):SetValue(100);click("closeMusicSettings")
        fresh()
        expect(false,function() paper.Cut(spans[1].spanId) end)
        showWord(request.mainTokenId)
        expect("word_select",function() click("wordTrayCard_"..request.mainTokenId) end)
        expect(false,function() click("wordTrayCard_"..request.mainTokenId);view.Refresh();update() end)
        -- A query adapter adds a second instance of the identical word for view-only selection.
        local query=x.session.queries.GetWordTray
        local twin=request.mainTokenId.."-selection-fixture"
        x.session.queries.GetWordTray=function()
            local result=query()
            for _,card in ipairs(result.value.cards) do if card.tokenId==request.mainTokenId then
                local other=U.Copy(card);other.tokenId=twin;table.insert(result.value.cards,other);break
            end end
            return result
        end
        view.Refresh();update()
        local before=x.state.GetSnapshot();local writes=x.writes
        expect("word_select",function() click("wordTrayCard_"..twin) end)
        expect(false,function() click("wordTrayCard_"..twin) end)
        expect("word_select",function() click("wordTrayCard_"..request.mainTokenId) end)
        check(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes,"selection uses token identity and never changes saved gameplay")
        x.session.queries.GetWordTray=query;view.Refresh();update()
        expect(false,function() showWord(request.mainTokenId) end)
        local card=control("wordTrayCard_"..request.mainTokenId)
        card.props.disabled=true
        expect(false,function() card.props.onClick(card) end);card.props.disabled=false
        expect(false,function() card.props.onPointerMove(e(120,100)) end)
        click("openSettings")
        expect(false,function() card.props.onClick(card) end);click("closeMusicSettings")
        expect(false,function() drag("wordTrayCard_"..request.mainTokenId,false);advance(.5) end)
        expect("word_select",function() click("wordTrayCard_"..request.mainTokenId) end)
        view.Navigate("home");update();view.Open("words");update();advance(.3);showWord(request.mainTokenId)
        expect(false,function() click("wordTrayCard_"..request.mainTokenId);view.Refresh();update() end)
        view.Navigate("brew");update();step(0)
        expect("ingredient_select",function() click("brewIngredient_ing_sea_salt") end)
        expect(false,function() view.Refresh();update();click("brewIngredient_ing_sea_salt") end)
        expect("ingredient_select",function() click("brewIngredient_ing_sea_salt") end)
        local button=control("add_ing_sea_salt")
        expect(false,function() button.props.onClick();button.props.onClick();update() end)
        land("ingredient_add")
        click("slot_ingredient_1")
        local remove=control("minus_ing_sea_salt")
        expect("ingredient_remove",function() remove.props.onClick();remove.props.onClick();update() end)

        -- Both animated paths use the same actual arrival event.
        expect(false,function() drag("brewIngredient_ing_night_dew",true) end);land("ingredient_add")
        showWord(request.mainTokenId)
        expect(false,function() drag("wordTrayCard_"..request.mainTokenId,true) end);land("word_add")
        click("wordTrayCard_"..request.mainTokenId)
        local trayRemove=control("brewSelectWord")
        expect("word_remove",function() trayRemove.props.onClick();trayRemove.props.onClick();update() end)
        local trayAdd=control("brewSelectWord")
        expect(false,function() trayAdd.props.onClick();trayAdd.props.onClick();update() end);land("word_add")
        click("slot_main");local withdraw=control("brewRemoveSlot")
        expect("word_withdraw",function() withdraw.props.onClick();withdraw.props.onClick();update() end)
        expect(false,function() drag("brewIngredient_ing_sea_salt",false);advance(.5) end)

        -- Quantity decreases one portion at a time; clearing a mixed draft is one aggregate sound.
        expect("draft_clear",function() click("clearDraft") end)
        add("ingredient","ing_sea_salt");add("ingredient","ing_sea_salt")
        click("slot_ingredient_1")
        expect("ingredient_remove",function() click("minus_ing_sea_salt") end)
        check(view.model.GetDraft().ingredients[1].quantity==1,"remove exactly one portion")
        add("word",request.mainTokenId);add("ingredient","ing_night_dew")
        local aux
        for _,token in pairs(x.tokens) do if token~=request.mainTokenId then aux=token;break end end
        add("word",assert(aux))
        local clear=control("clearDraft")
        expect("draft_clear",function() clear.props.onClick();clear.props.onClick();update() end)
        expect(false,function() click("clearDraft");view.Refresh();update() end)

        -- Failed writes and disabled operations do not acquire a pending sound.
        x.fault="write"
        expect(false,function() local r=view.brew.Throw("word",request.mainTokenId);check(r and not r.ok,"failed add");update() end)
        check(not view.brew.interaction.flight,"failed add has no flight");x.fault=false
        add("ingredient","ing_sea_salt");click("slot_ingredient_1");x.fault="write"
        expect(false,function() click("minus_ing_sea_salt");click("clearDraft") end);x.fault=false
        local action=view.model.Action;view.model.Action=function() return {enabled=false} end
        expect(false,function() view.brew.Throw("word",request.mainTokenId);view.brew.actions.Clear();view.brew.actions.TakeOut("ingredient","ing_sea_salt") end)
        view.model.Action=action
        local drop=view.model.Drop;view.model.Drop=function() return U.Ok({}) end
        expect(false,function() view.brew.Throw("word",request.mainTokenId);advance(.5) end);view.model.Drop=drop
        expect("draft_clear",function() click("clearDraft") end)

        -- No fixed delay: completion follows a deliberately varied flight duration in this test.
        expect(false,function() must(view.brew.Throw("word",request.mainTokenId)) end)
        view.brew.interaction.flight.duration=.83;land("word_add")
        expect("draft_clear",function() click("clearDraft") end)
        for _,mode in ipairs({"cancel","focus","gap","modal","invalidated","leave","resize"}) do
            expect(false,function() must(view.brew.Throw("ingredient","ing_sea_salt")) end)
            expect(false,function()
                if mode=="cancel" then view.brew.Cancel()
                elseif mode=="focus" then host.focused=false;step(.1);host.focused=true
                elseif mode=="gap" then step(.8)
                elseif mode=="modal" then view.panel="reader";step(.4);view.panel=false
                elseif mode=="invalidated" then must(view.model.TakeOut("ingredient","ing_sea_salt"))
                elseif mode=="resize" then view.brew.signature="invalid";step(.4)
                end
                if mode~="leave" then advance(.6) end
            end)
            if mode=="leave" then
                local before=#events;view.Navigate("home");update();advance(.6)
                view.Navigate("brew");update();step(0);check(#events==before,"leaving/reentering discards flight feedback")
            end
            view.model.Edit("clear");view.Refresh();update()
        end

        -- Retained immediate UI path also emits once after success, without a flight.
        local body=require("urhox-libs/UI").Panel {}
        require("ui.landscape.Panels").Brew(view,body)
        local immediate=assert(body:FindById("add_ing_sea_salt"))
        expect("ingredient_add",function() immediate.props.onClick();update() end)
        check(not view.brew.interaction.flight,"legacy UI is genuinely immediate")
        expect("word_add",function() must(view.brew.actions.Drop("word",request.mainTokenId)) end)
        expect(false,function() view.brew.actions.Drop("word",request.mainTokenId) end)
        expect("draft_clear",function() click("clearDraft") end)
        body:Destroy()

        -- Music and effect volume remain independent and no muted event is queued.
        click("openSettings");control("soundVolume"):SetValue(23);click("closeMusicSettings")
        expect("ingredient_select",function() click("brewIngredient_ing_sea_salt") end)
        check(events[#events].gain==.23,"shared sound volume")
        showWord(request.mainTokenId)
        expect("word_select",function() click("wordTrayCard_"..request.mainTokenId) end)
        check(events[#events].gain==.23,"word selection uses shared volume")
        add("word",request.mainTokenId);check(events[#events].gain==.23,"landing uses sound volume")
        expect("draft_clear",function() click("clearDraft") end)
        click("openSettings");control("soundEnabled"):SetValue(false);click("closeMusicSettings")
        showWord(request.mainTokenId)
        expect(false,function() click("wordTrayCard_"..request.mainTokenId) end)
        expect(false,function() view.brew.Throw("ingredient","ing_sea_salt");advance(.5);click("clearDraft") end)
        click("openSettings");control("soundEnabled"):SetValue(true);control("soundVolume"):SetValue(0);click("closeMusicSettings")
        expect(false,function() view.brew.Throw("word",request.mainTokenId);advance(.5);click("clearDraft") end)
        click("openSettings");control("soundVolume"):SetValue(100);control("musicEnabled"):SetValue(false);click("closeMusicSettings")
        add("ingredient","ing_sea_salt")
        for _,voice in ipairs(voices) do if voice.kind==SOUND_MUSIC and voice:IsPlaying() then check(voice.gain==0,"music remains independently muted") end end
        expect("draft_clear",function() click("clearDraft") end)
        expect(false,function() view.brew.Throw("word",request.mainTokenId) end)
        local before=#events;view.root:Destroy();view.Update()
        check(#events==before and not view.brew.interaction.flight,"destroy drops pending arrival")
        check(not view.PlayObjectSound("draft_clear"),"destroyed audio manager silent")
        for _,voice in ipairs(voices) do check(not voice:IsPlaying(),"voices stopped on destroy") end
        for _,node in ipairs(nodes) do check(node.removed==1,"each audio node released once") end
    end,debug.traceback)
    if view then view.root:Destroy() end
    Node=saved.Node;cache=saved.cache;SOUND_EFFECT=saved.effect;SOUND_MUSIC=saved.music;audio=saved.audio
    assert(ok,err)
    print("[BrewActionSoundsTest] PASS assertions="..n.."; cut/selection and brewing UI/draft/arrival paths, isolated audio/storage; NOT native or listening evidence")
    return n
end
return T
