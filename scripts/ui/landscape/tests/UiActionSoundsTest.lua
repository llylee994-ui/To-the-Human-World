-- Real UI callbacks and schema-4 transactions; explicit audio/clock/storage adapters.
local T={}
function T.Run()
    Stop()
    package.loaded["debug.DeveloperMode"]=false
    local saved={Node=Node,cache=cache,effect=SOUND_EFFECT,music=SOUND_MUSIC,audio=audio}
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local U=require "core.StateUtil"
    local F=require "debug.fixtures.B5Fixtures"
    local Data=require "data.content"
    local App=require "ui.landscape.AppView"
    local count=0
    local function check(value,why) count=count+1;assert(value,why) end
    local events,voices={},{}
    local musicPlays,musicStops=0,0
    ---@type table
    local view
    ---@type table
    local x
    SOUND_EFFECT="Effect";SOUND_MUSIC="Music"
    audio={SetMasterGain=function() error("global gain changed") end,Stop=function() error("global audio stopped") end}
    cache={GetResource=function(_,kind,path)
        check(kind=="Sound" and path:match("^audio/"),"packaged audio resource")
        return {path=path,SetLooped=function(self,value) self.looped=value end}
    end}
    Node=function()
        local node={}
        function node:CreateComponent(kind)
            check(kind=="SoundSource","independent source")
            local voice={playing=false,untilTime=0};voices[#voices+1]=voice
            function voice:SetSoundType(value) self.kind=value end
            function voice:SetGain(value) self.gain=value end
            function voice:IsPlaying() return self.playing and (self.kind==SOUND_MUSIC or host.now<self.untilTime) end
            function voice:Play(sound,frequency,gain)
                check(frequency==0,"original sample rate")
                self.playing=true;self.sound=sound;self.gain=gain;self.untilTime=host.now+.5
                if self.kind==SOUND_MUSIC then check(sound.looped,"BGM loops");musicPlays=musicPlays+1
                else
                    check(self.kind==SOUND_EFFECT and not sound.looped,"one-shot effects channel")
                    events[#events+1]={id=sound.path:match("/([^/]+)%.wav$"),gain=gain}
                end
            end
            function voice:Stop() self.playing=false;if self.kind==SOUND_MUSIC then musicStops=musicStops+1 end end
            return voice
        end
        function node:RemoveAllComponents() end
        return node
    end
    local function refresh() view.Update();host.Bind(view.root) end
    local function control(id) return assert(view.root:FindById(id),id) end
    local function rawClick(id,times)
        local button=control(id)
        check(not button.props.disabled,"enabled "..id)
        for _=1,times or 1 do button.props.onClick() end
    end
    local function expect(id,n,action,sceneChange)
        host.now=host.now+1
        local before,mp,ms=#events,musicPlays,musicStops
        action();refresh()
        check(#events-before==n,"sound count "..tostring(id)..": expected "..n..", got "..(#events-before))
        for i=before+1,#events do check(events[i].id==id,"only "..tostring(id)..", got "..events[i].id) end
        if not sceneChange then check(mp==musicPlays and ms==musicStops,"UI sounds never restart/stop BGM") end
    end
    local function click(id,sound,n,times,sceneChange)
        expect(sound,n or 1,function() rawClick(id,times) end,sceneChange)
    end
    local function fresh(currency)
        if view then view.root:Destroy() end
        local content=U.Copy(Data);content.stage1.initialEconomy.currency=currency or 1000
        x=F.New(content,{targetSchema=4})
        local before=#events;view=App.New(x.session,content);host.Bind(view.root)
        check(#events==before,"initialization and restore silent")
    end
    local ok,err=pcall(function()
        fresh()
        expect(nil,0,function() view.Refresh() end)
        click("openSettings","ui_click_01",1,5)
        expect(nil,0,function() view.OpenSettings();view.Refresh() end)
        click("closeMusicSettings",nil,0)
        click("toggleHomeHints","ui_click_01",1)
        click("toggleHomeHints","ui_click_01",5,5) -- each toggle really changes visibility
        view.zoom.active=true
        expect(nil,0,function() view.OpenSettings();rawClick("toggleHomeHints");rawClick("nextDay") end)
        view.zoom.active=false
        local before=x.state.GetSnapshot();local writes=x.writes
        click("nextDay","ui_click_01",1,5)
        expect(nil,0,function() view.Refresh();view.Open("day") end)
        local staleDay=control("confirmNextDay").props.onClick
        click("cancelNextDay","ui_click_01",1,5)
        expect(nil,0,staleDay)
        check(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes,"open/cancel does not advance or save")
        click("nextDay","ui_click_01")
        x.fault="write";click("confirmNextDay",nil,0);x.fault=false
        check(U.Equal(before,x.state.GetSnapshot()) and view.panel=="day","failed day commit stays in dialog")
        click("confirmNextDay","ui_confirm",1,5)
        check(x.state.GetSnapshot().live.gameFlow.day==before.live.gameFlow.day+1,"rapid confirm advances exactly once")
        -- A disabled day button never runs a command, even if its callback is invoked directly.
        click("nextDay","ui_click_01")
        local originalAction=view.model.Action
        view.model.Action=function(name) if name=="NextDay" then return {enabled=false,message="locked"} end;return originalAction(name) end
        view.Refresh();refresh();check(control("confirmNextDay").props.disabled,"day gate visible")
        expect(nil,0,function() control("confirmNextDay").props.onClick() end)
        view.model.Action=originalAction;view.Close();refresh()
        -- The final day uses the existing closing coordinator, still exactly one confirmation.
        while x.state.GetSnapshot().live.gameFlow.day<Data.release.finalDay do F.Must(x.state.NextDay()) end
        view.Refresh();refresh();click("nextDay","ui_click_01")
        click("confirmNextDay","ui_confirm",1,5)
        check(x.state.GetSnapshot().chapter.phase~="operating","final day enters closing")

        fresh(1000)
        expect("ui_click_01",1,function() view.Open("shop");view.Open("shop") end,true)
        expect(nil,0,function() view.Refresh();view.Open("shop") end)
        click("shopSettings","ui_click_01",1,4);click("closeMusicSettings",nil,0)
        -- Select a known product, then buy through its actual button.
        rawClick("shop_select_ing_night_dew");refresh()
        before=x.state.GetSnapshot()
        click("buy_ing_night_dew","ui_confirm",1)
        check(x.state.GetSnapshot().live.economy.currency==before.live.economy.currency-12,"one actual debit")
        x.fault="write";before=x.state.GetSnapshot();click("buy_ing_night_dew",nil,0);x.fault=false
        check(U.Equal(before,x.state.GetSnapshot()),"failed purchase rollback")
        -- Rapid valid purchases each get one confirm; sold-out retries get none.
        click("buy_ing_night_dew","ui_confirm",5,7)
        check(control("buy_ing_night_dew").props.disabled,"sold out gate")
        expect(nil,0,function() control("buy_ing_night_dew").props.onClick() end)
        click("shopTab_furniture","ui_click_01",1,5)
        local furniture=assert(view.root:FindById("buy_decor_tablecloth"),"furniture entry")
        expect("ui_confirm",1,function() for _=1,5 do furniture.props.onClick() end end)
        check(control("buy_decor_tablecloth").props.disabled,"owned furniture disabled; replayed quote silent")
        click("shopNextPage","ui_click_01",1,5)
        expect(nil,0,function() control("shopNextPage").props.onClick() end)
        click("shopPreviousPage","ui_click_01",1,5)

        fresh(12);expect("ui_click_01",1,function() view.Open("shop") end,true)
        rawClick("shop_select_ing_night_dew");refresh()
        local buy=control("buy_ing_night_dew").props.onClick
        expect("ui_confirm",1,function() for _=1,5 do buy() end end)
        check(x.state.GetSnapshot().live.economy.currency==0 and control("buy_ing_night_dew").props.disabled,"balance failure silent")

        fresh(1000);expect("ui_click_01",1,function() view.Open("shop") end,true)
        click("shopTab_tickets","ui_click_01")
        before=x.state.GetSnapshot();writes=x.writes
        click("buy_travel_ticket","ui_click_01",1,5)
        local cancelledConfirm=control("confirmTravelTicket").props.onClick
        click("cancelTravelTicket","ui_click_01",1,5)
        expect(nil,0,cancelledConfirm)
        check(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes,"ticket cancel never buys")
        click("buy_travel_ticket","ui_click_01")
        x.fault="write";click("confirmTravelTicket",nil,0);x.fault=false
        check(U.Equal(before,x.state.GetSnapshot()),"ticket save failure silent")
        -- An out-of-date confirmation revalidates, refreshes, then accepts a new quote.
        F.Must(x.state.NextDay());click("confirmTravelTicket",nil,0)
        click("confirmTravelTicket","ui_confirm",1,5,true) -- shop -> ending retains existing scene music policy
        check(x.state.GetSnapshot().chapter.phase=="ended","real ticket transaction entered ending")
        check(x.state.GetSnapshot().live.economy.currency==334,"real ticket debited once")

        fresh()
        click("openSettings","ui_click_01")
        control("soundVolume"):SetValue(25)
        click("closeMusicSettings",nil,0)
        click("toggleHomeHints","ui_click_01")
        check(events[#events].gain==.25,"click uses existing effects volume")
        click("openSettings","ui_click_01")
        control("soundEnabled"):SetValue(false);click("closeMusicSettings",nil,0)
        click("toggleHomeHints",nil,0)
        click("nextDay",nil,0);click("confirmNextDay",nil,0)
        check(x.state.GetSnapshot().live.gameFlow.day==2,"muting never blocks valid actions")
        click("openSettings",nil,0)
        control("soundEnabled"):SetValue(true);control("soundVolume"):SetValue(100)
        click("closeMusicSettings",nil,0)
        -- Object entrance does not pick up a generic click from shared panels.
        expect("drawer_open",1,function() view.Open("letters") end)
        for _=1,30 do host.Step(view,1/60) end
        click("closePanel","drawer_close",1,5)
    end)
    if view then view.root:Destroy() end
    Node=saved.Node;cache=saved.cache;SOUND_EFFECT=saved.effect;SOUND_MUSIC=saved.music;audio=saved.audio
    assert(ok,err)
    print("[UiActionSoundsTest] PASS assertions="..count.."; real UI/schema-4 transactions, click/confirm exclusivity, failure/replay/mute/BGM boundaries; audio adapters NOT listening evidence")
    return count
end
return T
