-- Real entry callbacks, pointer dispatch and workbench; explicit audio/clock adapters.
local T={}
function T.Run()
    Stop()
    package.loaded["debug.DeveloperMode"]=false
    local saved={Node=Node,cache=cache,effect=SOUND_EFFECT,music=SOUND_MUSIC,audio=audio}
    local Host=require("ui.landscape.tests.ZoomTestHost").New()
    MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT=0,1,2 -- Explicit headless enum adapters, as in HomeZoomTest.
    local Engine=require "urhox-libs/UI/Core/UI"
    local Event=require "urhox-libs/UI/Core/PointerEvent"
    local Geometry=require "ui.landscape.LayoutGeometry"
    local R=require "debug.fixtures.ReleaseFixtures"
    local App=require "ui.landscape.AppView"
    local hearth="audio/bgm/hearth-warmth-loop.wav"
    local sea="audio/bgm/seaside-path-loop.wav"
    local brew="audio/bgm/brewing-mystery-loop.wav"
    local n,plays=0,0
    local events,voices,nodes={},{},{}
    ---@type table
    local view
    local function check(value,why) n=n+1;assert(value,why) end
    SOUND_EFFECT="Effect";SOUND_MUSIC="Music"
    audio={Stop=function() error("global stop") end,SetMasterGain=function() error("global gain") end}
    cache={GetResource=function(_,kind,path)
        check(kind=="Sound" and path:match("^audio/"),"project resource")
        return {path=path,SetLooped=function(self,v) self.looped=v end}
    end}
    Node=function()
        local node={removed=0};nodes[#nodes+1]=node
        function node:CreateComponent(kind)
            check(kind=="SoundSource","non-positional source")
            local source={playing=false};voices[#voices+1]=source
            function source:SetSoundType(v) self.kind=v end
            function source:SetGain(v) self.gain=v end
            function source:IsPlaying() return self.playing and (self.kind==SOUND_MUSIC or Host.now<self.finish) end
            function source:Stop() self.playing=false end
            function source:Play(sound,frequency,gain)
                check(frequency==0 and gain>=0 and gain<=1,"unchanged rate and base mix")
                if self.kind==SOUND_MUSIC then
                    for _,other in ipairs(voices) do check(other.kind~=SOUND_MUSIC or not other:IsPlaying(),"stop previous before replacement") end
                    check(sound.looped,"BGM loops");plays=plays+1
                else
                    check(not sound.looped and self.kind==SOUND_EFFECT,"one-shot effect")
                    events[#events+1]={id=sound.path:match("/([^/]+)%.wav$"),gain=gain,scene=view and view.scene}
                end
                self.playing=true;self.sound=sound.path;self.gain=gain;self.finish=Host.now+.6
            end
            return source
        end
        function node:RemoveAllComponents() self.removed=self.removed+1 end
        return node
    end
    local function music(path)
        local found
        for _,voice in ipairs(voices) do if voice.kind==SOUND_MUSIC and voice:IsPlaying() then
            check(not found,"one playing BGM");found=voice
        end end
        check(found and found.sound==path,"expected music "..path)
        return found
    end
    local function bind() Host.Bind(view.root);Engine.SetRoot(view.root) end
    local function update() view.Update();bind() end
    local function step(count) for _=1,count or 1 do Host.Step(view,1/60);bind() end end
    local function control(id) return assert(view.root:FindById(id),id) end
    local function click(id) control(id).props.onClick();update() end
    local function rawEntry(id) control(id).props.onClick() end
    local function tap(id)
        local px,py
        for _,item in ipairs(view.home.manifest.objects) do if item.id==id then
            local r=item.regions[1];px,py=Geometry.ToScreen(view.home.manifest.layers[item.layer],view.home.Fit(),r.cx,r.cy)
        end end
        for _,kind in ipairs({"PointerDown","PointerUp"}) do
            Engine["Handle"..kind](Event.new(kind,{x=px,y=py,button=MOUSEB_LEFT,pointerType="mouse"}))
        end
    end
    local function total(id) local count=0;for _,e in ipairs(events) do if e.id==id then count=count+1 end end;return count end
    local function finishZoom(destination)
        local guard=0
        while view.zoom.active do step();guard=guard+1;check(guard<180,"bounded original transition") end
        check(view.scene==destination,"actual destination "..destination)
    end
    local function fresh()
        if view then view.root:Destroy() end
        local x=R.New(1000);local before=#events
        view=App.New(x.session,x.content);bind()
        check(#events==before,"initialization/restoration has no entrance sound")
        return x
    end
    local ok,err=pcall(function()
        fresh();music(hearth)
        for _,item in ipairs({{"home.stove","stove_touch","brew",brew},{"home.net","net_pick","seaside",sea}}) do
            local before,mp=#events,plays
            tap(item[1]);for _=1,5 do tap(item[1]);rawEntry("home.net");rawEntry("home.stove") end
            check(#events==before+1 and events[#events].id==item[2],"one dedicated entrance, no generic or cross sound")
            check(view.scene=="home" and view.zoom.active and plays==mp,"sound at accepted entrance, BGM waits for destination")
            music(hearth);finishZoom(item[3]);local source=music(item[4])
            check(plays==mp+1,"one destination track start")
            mp=plays;for _=1,10 do view.Refresh();update() end
            check(plays==mp and music(item[4])==source,"same scene refresh does not restart")
            if item[3]=="brew" then
                local failed=view.brew.Start();update()
                check(not (failed and failed.ok) and plays==mp,"failed empty brew keeps track")
                view.Open("journal");update();check(plays==mp,"recipe book keeps track")
                view.Open("shop");update();music(sea);check(plays==mp+1,"shop overrides brew")
                view.Refresh();update();check(plays==mp+1,"shop refresh keeps track")
                click("closePanel");check(view.scene=="brew" and music(brew)==source and plays==mp+2,"shop close restores brewing on same source")
            else
                local lift=total("bottle_lift");click("startSalvage")
                check(view.salvage.active and total("bottle_lift")==lift,"lowering does not lift")
                local guard=0
                while view.salvage.active and view.salvage.Pose().phase~="lifting" do step();guard=guard+1;check(guard<150,"lifting reached") end
                check(total("bottle_lift")==lift+1,"original actual lifting sound")
                click("skipSalvage");check(total("bottle_lift")==lift+1 and plays==mp,"skip does not replay or restart BGM")
                view.Close();update()
            end
            click("returnHome");music(hearth)
        end
        -- Native pointer dispatch must reject disabled and covered hotspots.
        local before=#events
        control("home.net").props.disabled=true;tap("home.net")
        check(#events==before and not view.zoom.active,"disabled hotspot silent")
        control("home.net").props.disabled=false
        view.OpenSettings();update();before=#events
        tap("home.net");rawEntry("home.stove");rawEntry("home.net")
        check(#events==before and not view.zoom.active,"settings overlay blocks stale callbacks too")
        click("closeMusicSettings")
        view.Open("shop");update();before=#events;rawEntry("home.net");rawEntry("home.stove")
        check(#events==before and not view.zoom.active,"modal panel silent");click("closePanel")
        for _,field in ipairs({"atTitle","portrait","yawProbe"}) do
            before=#events;view[field]=true;rawEntry("home.net");rawEntry("home.stove");view[field]=false
            check(#events==before and not view.zoom.active,"guard "..field)
        end
        view.calendar={motion={active=true}};before=#events;rawEntry("home.stove")
        check(#events==before and not view.zoom.active,"calendar transition silent");view.calendar=false
        local start=view.zoom.Start;view.zoom.Start=function() return false end
        before=#events;rawEntry("home.net");rawEntry("home.stove");view.zoom.Start=start
        check(#events==before,"rejected transition silent")
        -- Programmatic navigation and refresh cannot impersonate entrance clicks.
        before=#events;view.Navigate("brew");update();view.Navigate("home");update()
        check(#events==before,"programmatic navigation silent")
        rawEntry("home.net");before=#events;Host.focused=false;step();Host.focused=true
        check(not view.zoom.active and view.scene=="home" and #events==before,"cancelled accepted entry never replays")

        -- Real workbench draft, failed save, pending result and recipe inspection.
        local x=fresh();local request=R.Accept(x,1)
        for _,ingredient in ipairs(request.ingredients) do
            local shortage=ingredient.quantity-(x.state.GetSnapshot().live.economy.ingredients[ingredient.ingredientId] or 0)
            if shortage>0 then R.Must(x.state.Shop({ingredientId=ingredient.ingredientId,quantity=shortage})) end
        end
        view.Refresh();update()
        tap("home.stove");finishZoom("brew");local source=music(brew);local mp=plays
        local result=view.brew.Throw("word",request.mainTokenId);check(result and result.ok,"real main-word drop");step(30)
        for _,id in ipairs(request.auxTokenIds) do check(view.brew.Throw("word",id).ok,"real auxiliary drop");step(30) end
        for _,ingredient in ipairs(request.ingredients) do
            for _=1,ingredient.quantity do
                check(view.brew.Throw("ingredient",ingredient.ingredientId).ok,"real recipe ingredient drop");step(30)
            end
        end
        x.fault="write";result=view.brew.Start();x.fault=false;update()
        check(result and not result.ok and result.error.code=="SAVE_WRITE_FAILED" and plays==mp,"failed brew save does not restart")
        result=view.brew.Start();check(result and result.ok and view.brew.interaction.active,"real successful brew accepted")
        step(150);view.Open("journal");update();view.Refresh();update()
        check(music(brew)==source and plays==mp,"ingredients, result, book and refresh retain music")

        -- Independent settings apply to old and new tracks/effects, including muted navigation.
        view.Navigate("home");update();click("openSettings")
        control("musicVolume"):SetValue(31);control("soundVolume"):SetValue(27)
        control("musicEnabled"):SetValue(false);click("closeMusicSettings")
        before=#events;tap("home.stove");check(#events==before+1 and events[#events].gain==.27,"effect uses SFX volume while music muted")
        finishZoom("brew");source=music(brew);check(source.gain==0,"muted destination")
        mp=plays;click("openSettings");control("musicEnabled"):SetValue(true);control("soundEnabled"):SetValue(false)
        check(source.gain==.31 and plays==mp,"unmute without restart; independent controls")
        click("closeMusicSettings");view.Navigate("home");update();before=#events;tap("home.net")
        check(#events==before and view.zoom.active,"muted effect does not block entry")
        finishZoom("seaside");check(music(sea).gain==.31,"music volume preserved across scenes")
        click("openSettings");control("soundEnabled"):SetValue(true);control("soundVolume"):SetValue(0)
        control("musicVolume"):SetValue(0);click("closeMusicSettings")
        view.Navigate("home");update();before=#events;tap("home.stove");finishZoom("brew")
        check(#events==before and music(brew).gain==0,"zero levels remain silent")
        mp=plays;view.root:Destroy();view.root:Destroy();view.Update()
        check(plays==mp and not view.PlayObjectSound("stove_touch"),"destroy cannot replay")
        for _,voice in ipairs(voices) do check(not voice:IsPlaying(),"all owned audio stopped") end
        for _,node in ipairs(nodes) do check(node.removed==1,"each node released once") end
    end)
    if view then view.root:Destroy() end
    Node=saved.Node;cache=saved.cache;SOUND_EFFECT=saved.effect;SOUND_MUSIC=saved.music;audio=saved.audio
    assert(ok,err)
    print("[BrewingAudioTest] PASS assertions="..n.."; actual entry/workbench/scene callbacks, isolated audio and saves; NOT native listening evidence")
    return n
end
return T
