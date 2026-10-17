-- Actual view callbacks/state controllers with isolated audio, clock and storage.
local T={}
function T.Run()
    Stop()
    local original={Node=Node,cache=cache,effect=SOUND_EFFECT,music=SOUND_MUSIC,audio=audio}
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local U=require "core.StateUtil"
    local F=require "debug.fixtures.B5Fixtures"
    local Data=require "data.content"
    local App=require "ui.landscape.AppView"
    local Sounds=require "ui.landscape.ObjectSounds"
    local count=0
    local function check(ok,why) count=count+1;assert(ok,why) end
    local events,voices,nodes={},{},{}
    local durations={bottle_lift=.94,drawer_open=.62,drawer_close=.49,letter_pick=.32,
        tray_open=.22,tray_close=.20,recipe_book_open=.49,recipe_book_close=.36,ui_click_01=.14,ui_confirm=.43,
        net_pick=.40,stove_touch=.52,ingredient_select=.18,ingredient_add=.68,ingredient_remove=.72,
        word_add=.36,word_remove=.32,word_withdraw=.27,draft_clear=.62,word_cut=1.04,word_select=.18}
    local musicPlays,musicStops=0,0
    local missing=false --[[@as string|false]]
    ---@type table
    local view
    SOUND_EFFECT="Effect";SOUND_MUSIC="Music"
    audio={SetMasterGain=function() error("must preserve existing bus volume") end,
        Stop=function() error("must not globally stop audio") end}
    cache={GetResource=function(_,kind,path)
        check(kind=="Sound","load typed sound")
        if path==missing then return nil end
        local id=path:match("^audio/sfx/") and path:match("/([^/]+)%.wav$")
        check(id and durations[id] or path:match("^audio/bgm/"),"project resource path only")
        return {id=id,path=path,SetLooped=function(self,value) self.looped=value end}
    end}
    Node=function()
        local owner={sources={},removed=0};nodes[#nodes+1]=owner
        function owner:CreateComponent(kind)
            check(kind=="SoundSource","non-positional source")
            local source={playing=false,stops=0}
            voices[#voices+1]=source;self.sources[#self.sources+1]=source
            function source:SetSoundType(kind) self.kind=kind end
            function source:IsPlaying() return self.playing and (self.kind==SOUND_MUSIC or host.now<self.untilTime) end
            function source:SetGain(gain) self.gain=gain end
            function source:Play(sound,frequency,gain)
                check(frequency==0,"source rate unchanged")
                self.sound=sound;self.gain=gain;self.playing=true
                if self.kind==SOUND_MUSIC then
                    check(sound.looped,"BGM still loops");musicPlays=musicPlays+1
                else
                    check(self.kind==SOUND_EFFECT and sound.looped==false and gain==1,"one-shot, effect bus, authored gain")
                    self.untilTime=host.now+durations[sound.id]
                    events[#events+1]={id=sound.id,time=host.now,phase=view and view.salvage.Pose().phase}
                end
            end
            function source:Stop()
                self.playing=false;self.stops=self.stops+1
                if self.kind==SOUND_MUSIC then musicStops=musicStops+1 end
            end
            return source
        end
        function owner:RemoveAllComponents() self.removed=self.removed+1 end
        return owner
    end
    local function total(id) local n=0;for _,e in ipairs(events) do if e.id==id then n=n+1 end end;return n end
    local function refresh() view.Update();host.Bind(view.root) end
    local function step(frames) for _=1,frames or 30 do host.Step(view,1/60);host.Bind(view.root) end end
    local function click(id,times)
        local widget=assert(view.root:FindById(id),id)
        check(not widget.props.disabled,"enabled callback "..id)
        for _=1,times or 1 do widget.props.onClick() end
        refresh()
    end
    local function fresh()
        if view then view.root:Destroy() end
        local x=F.New(Data,{targetSchema=4})
        local before=#events;view=App.New(x.session,Data);host.Bind(view.root)
        check(#events==before,"initialization/restoration silent")
        return x
    end
    local ok,err=pcall(function()
        local x=fresh()
        local before=x.state.GetSnapshot();local writes=x.writes
        for _,item in ipairs({{"letters","drawer_open","drawer_close"},{"words","tray_open","tray_close"},{"journal","recipe_book_open","recipe_book_close"}}) do
            for _=1,3 do
                local open,close=total(item[2]),total(item[3]);local mp,ms=musicPlays,musicStops
                view.Open(item[1]);view.Open(item[1]);refresh()
                check(total(item[2])==open+1,"double open queues exactly one "..item[2])
                view.Refresh();refresh();step()
                check(total(item[2])==open+1,"refresh and updates silent "..item[2])
                click("closePanel",5)
                check(total(item[3])==close+1,"rapid close exactly once "..item[3])
                step();check(not view.panel,"original close animation completes")
                check(musicPlays==mp and musicStops==ms,"opening/closing does not touch BGM")
            end
        end
        check(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes,"open/close does not save gameplay")
        local silent=#events
        view.panel="letters";view.Refresh();refresh();step()
        check(#events==silent,"restored panel has no user open sound")
        view.Close();refresh()
        view.Open("letters");view.Navigate("home");refresh()
        check(#events==silent,"aborted queued open silent")
        view.zoom.active=true;view.Open("words");view.zoom.active=false;refresh()
        check(#events==silent,"blocked opening silent")
        local letter=F.Must(x.state.ReceiveLetter({letterId="letter_pa_01"})).letterInstanceId
        view.Open("letters");refresh();step()
        local picks=total("letter_pick")
        x.fault="write";click("read_"..letter)
        check(total("letter_pick")==picks and view.panel=="letters","failed read silent")
        x.fault=false;click("read_"..letter,4)
        check(total("letter_pick")==picks+1 and view.panel=="reader","one successful user read")
        view.Refresh();refresh();step();check(total("letter_pick")==picks+1,"reader rebuild silent")
        view.Read(letter,true);refresh();check(total("letter_pick")==picks+1,"same reader repeated callback silent")
        view.Navigate("home");view.Open("paper");refresh()
        check(total("letter_pick")==picks+2,"desk paper enters reader once")
        local opening=total("drawer_open")
        view.Close();refresh();check(total("drawer_open")==opening,"return stack silent")
        for _,scenario in ipairs({"normal","skip-before","cancel-before","focus-before","gap-before","skip-after","failed-receive"}) do
            x=fresh();view.Navigate("seaside");refresh()
            local lifts,papers,mp,ms=total("bottle_lift"),total("letter_pick"),musicPlays,musicStops
            if scenario=="failed-receive" then x.fault="write" end
            click("startSalvage",4)
            if scenario=="failed-receive" then
                check(not view.salvage.active and total("bottle_lift")==lifts,"failed Receive silent")
            else
                check(view.salvage.active and total("bottle_lift")==lifts,"Receive/lowering silent")
                if scenario=="skip-before" then click("skipSalvage")
                elseif scenario=="cancel-before" then view.CancelSalvage("test");refresh()
                elseif scenario=="focus-before" then host.focused=false;step(1);host.focused=true
                elseif scenario=="gap-before" then host.Step(view,.4)
                else
                    local guard=0
                    while view.salvage.active and view.salvage.Pose().phase~="lifting" do
                        check(total("bottle_lift")==lifts,"not before real lifting phase")
                        step(1);guard=guard+1;assert(guard<100)
                    end
                    check(total("bottle_lift")==lifts+1 and events[#events].phase=="lifting","exact lifting edge")
                    if scenario=="skip-after" then click("skipSalvage") else step(130) end
                end
                local expected=(scenario=="normal" or scenario=="skip-after") and 1 or 0
                check(total("bottle_lift")==lifts+expected,"no delayed/cancelled/skip catch-up sound "..scenario)
                check(total("letter_pick")==papers,"automatic reading does not impersonate user paper click")
                check(musicPlays==mp and musicStops==ms,"salvage/short sounds keep seaside BGM")
            end
        end
        view.root:Destroy();local length=#events
        check(not view.PlayObjectSound("tray_open") and #events==length,"destroyed view silent")
        local mp,ms=musicPlays,musicStops
        local player=Sounds.New()
        check(not player.Play("unknown"),"unknown event ignored")
        for _=1,8 do check(player.Play("drawer_open"),"overlapping valid effects have separate voices") end
        check(not player.Play("drawer_open"),"bounded pool drops excess without interrupting anything")
        host.now=host.now+1
        check(player.Play("tray_open"),"finished source reused at original rate")
        player.Destroy();player.Destroy()
        check(not player.Play("letter_pick"),"destroyed player cannot restart")
        check(musicPlays==mp and musicStops==ms,"effect destruction isolated from music")
        missing="audio/sfx/objects/letter_pick.wav"
        local unavailable=Sounds.New();check(not unavailable.Play("letter_pick"),"missing audio does not abort gameplay")
        local old=#events;missing=false
        check(unavailable.Play("letter_pick") and #events==old+1,"next explicit action retries, no queued catch-up")
        unavailable.Destroy()
        for _,owner in ipairs(nodes) do check(owner.removed==1,"each owned node released once") end
    end)
    if view then view.root:Destroy() end
    Node=original.Node;cache=original.cache;SOUND_EFFECT=original.effect;SOUND_MUSIC=original.music;audio=original.audio
    assert(ok,err)
    print("[ObjectSoundsTest] PASS assertions="..count.."; eight actions, real phase edges, duplicate/refresh/restore/failure/skip boundaries, isolated BGM; adapters NOT listening evidence")
    return count
end
return T
