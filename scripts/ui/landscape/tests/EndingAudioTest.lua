-- Real view/model transactions with isolated storage, audio and clock ports.
-- These checks do not claim native playback or subjective listening acceptance.
local T={}
function T.Run()
    Stop()
    local saved={Node=Node,cache=cache,effect=SOUND_EFFECT,music=SOUND_MUSIC,audio=audio}
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local R=require "debug.fixtures.ReleaseFixtures"
    local E=require "debug.fixtures.ReleaseEndingFixtures"
    local App=require "ui.landscape.AppView"
    local Audio=require "ui.landscape.AudioCatalog"
    local events,voices,nodes={},{},{}
    local plays,n=0,0
    local view
    local function check(ok,why) n=n+1;assert(ok,why) end
    local durations={brew_simmer=1.65,reward_coins_crisp_v2=.64,wish_seal=.82}
    SOUND_EFFECT="Effect";SOUND_MUSIC="Music"
    audio={Stop=function() error("global stop forbidden") end,SetMasterGain=function() error("global gain forbidden") end}
    cache={GetResource=function(_,kind,path)
        check(kind=="Sound" and path:match("^audio/"),"project resource only")
        return {path=path,SetLooped=function(self,value) self.looped=value end}
    end}
    Node=function()
        local node={removed=0};nodes[#nodes+1]=node
        function node:CreateComponent(kind)
            check(kind=="SoundSource","non-positional source")
            local source={playing=false};voices[#voices+1]=source
            function source:SetSoundType(value) self.kind=value end
            function source:SetGain(value) self.gain=value end
            function source:IsPlaying() return self.playing and (self.kind==SOUND_MUSIC or host.now<self.finish) end
            function source:Stop() self.playing=false end
            function source:Play(sound,frequency,gain)
                check(frequency==0 and gain>=0 and gain<=1,"original rate and gain")
                local id=sound.path:match("/([^/]+)%.wav$")
                if self.kind==SOUND_MUSIC then
                    for _,other in ipairs(voices) do check(other.kind~=SOUND_MUSIC or not other:IsPlaying(),"no overlapping BGM") end
                    check(sound.looped,"looping complete mix");plays=plays+1
                else
                    check(self.kind==SOUND_EFFECT and not sound.looped,"one-shot effect")
                    events[#events+1]={id=id,path=sound.path,source=self,gain=gain}
                end
                self.playing=true;self.path=sound.path;self.gain=gain;self.finish=host.now+(durations[id] or .6)
            end
            return source
        end
        function node:RemoveAllComponents() self.removed=self.removed+1 end
        return node
    end
    local function total(id) local count=0;for _,event in ipairs(events) do if event.id==id then count=count+1 end end;return count end
    local function music(id)
        local found
        for _,voice in ipairs(voices) do if voice.kind==SOUND_MUSIC and voice:IsPlaying() then check(not found,"single music voice");found=voice end end
        check(found and found.path==Audio.BgmPath(id),"correct music "..id)
        return found
    end
    local function update() view.Update();host.Bind(view.root) end
    local function step(seconds) for _=1,math.ceil(seconds/.01) do host.Step(view,.01) end;host.Bind(view.root) end
    local function widget(id) return assert(view.root:FindById(id),id) end
    local function click(id) local w=widget(id);check(not w.props.disabled,"enabled "..id);w.props.onClick();update() end
    local function fresh(x)
        if view then view.root:Destroy() end
        local before=#events;view=App.New(x.session,x.content);host.Bind(view.root)
        check(#events==before,"initialization/restoration silent")
    end
    local function finishEnding()
        step(1.2)
        local guard=0
        while not view.journeyView.sequence.done do
            local w=widget("departureAdvance")
            local event={pointerId=1,IsPrimaryAction=function() return true end,StopPropagation=function() end}
            w.props.onPointerDown(event);w.props.onClick(w,event)
            step(3);guard=guard+1;check(guard<12,"bounded original ending flow")
        end
    end
    local function brewReady()
        local x=R.New(1000);local request=R.Accept(x,1)
        for _,ingredient in ipairs(request.ingredients) do
            local shortage=ingredient.quantity-(x.state.GetSnapshot().live.economy.ingredients[ingredient.ingredientId] or 0)
            if shortage>0 then R.Must(x.state.Shop({ingredientId=ingredient.ingredientId,quantity=shortage})) end
        end
        R.Must(x.order.UpdateDraft({orderId=request.orderId,draft=require("systems.RecipeDraft").Project(request)}))
        fresh(x);view.Navigate("brew");update();music("brewing")
        return x
    end
    local ok,err=xpcall(function()
        local x=R.New(700);R.Must(x.state.PurchaseTravelTicket(R.Quote(x,"travel_ticket",666)))
        fresh(x);music("traveler");local mp=plays
        for _=1,4 do view.Refresh();update() end
        check(plays==mp,"traveler view rebuild keeps same track")
        finishEnding();check(music("traveler").gain==0,"existing ending fade reaches silence")
        click("endGame");check(view.atTitle,"ending exit accepted");music("hearth")
        click("openMemories");click("memory_1");music("traveler")

        x=E.WishSeed();fresh(x);music("wish");mp=plays
        for _=1,3 do view.Refresh();update() end
        click("previewWish");click("cancelWishPreview");click("previewWish")
        check(plays==mp and total("wish_seal")==0,"edit/refresh/preview/cancel keep wish track and never seal")
        x.fault="write";widget("confirmWish").props.onClick();x.fault=false;update()
        check(total("wish_seal")==0 and view.panel=="wishPreview","failed confirmation silent")
        local callback=widget("confirmWish").props.onClick;local before=#events
        callback();callback();callback()
        check(#events==before+1 and events[#events].id=="wish_seal","one accepted seal, no generic sound")
        update();check(view.panel=="ending" and plays==mp,"sealing continues wish music")
        callback();view.Refresh();update();check(total("wish_seal")==1 and plays==mp,"stale confirm and refresh do not replay")
        finishEnding();check(music("wish").gain==0,"wish keeps existing fade")
        click("endGame");check(music("hearth").gain>0,"exit restores scene volume")
        local restored=E.Clone(x);fresh(restored);music("wish");check(total("wish_seal")==1,"loading ended save does not reseal")

        x=E.WishSeed();E.Must(x.state.UpdateWishLayout(E.Request(x,{placements={}})));fresh(x)
        view.Open("wishPreview");update();check(widget("confirmWish").props.disabled,"empty wish disables confirmation")
        before=#events;widget("confirmWish").props.onClick();update();check(#events==before,"disabled stale callback silent")

        x=brewReady();mp=plays;before=#events
        x.fault="write";local r=view.brew.Start();x.fault=false
        check(not r.ok and #events==before,"failed brew never starts simmer")
        r=view.brew.Start();check(r.ok and view.brew.interaction.active,"accepted real brew starts presentation")
        local simmer=events[#events].source
        for _=1,5 do view.brew.Start() end
        check(#events==before+1 and events[#events].id=="brew_simmer","one simmer for repeated start")
        view.PlayObjectSound("letter_pick");local other=events[#events].source
        view.brew.Skip();step(.02)
        check(simmer:IsPlaying() and simmer.gain>0 and simmer.gain<1,"skip begins short fade")
        step(.04);check(not simmer:IsPlaying() and other:IsPlaying() and plays==mp,"50ms stop affects only simmer")
        view.brew.Start();update();check(total("brew_simmer")==1,"pending result never restarts simmer")
        local txn=view.model.Refresh().currentOrder.pending.transactionId
        before=#events;x.fault="write";r=view.model.Resolve(true,txn);x.fault=false
        check(not r.ok and #events==before,"failed payment silent")
        r=view.model.Resolve(true,txn);check(r.ok,"real payment accepted")
        check(#events==before+1 and events[#events].id=="reward_coins_crisp_v2","positive reward starts one crisp v2, no confirm overlay")
        view.model.Resolve(true,txn);update();step(.3);view.Refresh();update()
        check(total("reward_coins_crisp_v2")==1 and plays==mp,"reward refresh/callback/number animation does not replay or restart BGM")

        for _,ending in ipairs({"natural","leave","cancel","focus","destroy"}) do
            brewReady();before=total("brew_simmer");check(view.brew.Start().ok,"new brew "..ending)
            simmer=events[#events].source
            if ending=="natural" then step(view.brew.interaction.duration+.1)
            elseif ending=="leave" then view.Navigate("home");update();step(.06);music("hearth")
            elseif ending=="cancel" then view.brew.Cancel();step(.06)
            elseif ending=="focus" then host.focused=false;step(.07);host.focused=true
            else view.root:Destroy() end
            check(not simmer:IsPlaying() and total("brew_simmer")==before+1,"stop without replay on "..ending..
                "; path="..tostring(simmer.path).."; playing="..tostring(simmer:IsPlaying()).."; count="..total("brew_simmer").."; before="..before)
        end

        -- A duplicate transaction callback and non-positive amounts are gated by feedback acceptance.
        local UI=require "urhox-libs/UI"
        local balance=20;local amount=0;local transaction="zero"
        local ctx={root=UI.Panel {},viewport={w=1280,h=720},model={}}
        local heard=0;ctx.PlayObjectSound=function(id) check(id=="reward_coins","reward mapping");heard=heard+1 end
        function ctx.model.Refresh() return {currentOrder={pending={transactionId=transaction}},live={economy={currency=balance},gameFlow={day=1}}} end
        function ctx.model.Resolve() balance=balance+amount;return {ok=true} end
        require("ui.landscape.BrewFeedback").New(ctx,UI.Label {})
        ctx.model.Resolve(true);amount=-1;ctx.model.Resolve(true);check(heard==0,"zero/negative payout silent")
        transaction="positive";amount=10;ctx.model.Resolve(true);ctx.model.Resolve(true)
        check(heard==1,"same positive transaction accepted only once")

        -- Owned cancellation remains correct if another effect reuses the old voice.
        local sounds=require("ui.landscape.ObjectSounds").New()
        local handle=sounds.PlayScoped("brew_simmer");host.now=host.now+2
        sounds.Play("letter_pick");other=events[#events].source
        sounds.Stop(handle,.05);sounds.Update(.1)
        check(other:IsPlaying(),"stale handle cannot stop a reused voice")
        handle=sounds.PlayScoped("brew_simmer");simmer=events[#events].source
        sounds.SetOptions(true,40);check(simmer.gain==.4,"shared sound volume")
        sounds.Stop(handle,.05);sounds.Update(.025);sounds.SetOptions(true,60)
        check(math.abs(simmer.gain-.3)<.00001,"volume changes preserve fade fraction")
        sounds.SetOptions(false,60);check(simmer.gain==0 and not sounds.PlayScoped("brew_simmer"),"muted simmer stays silent")
        sounds.Update(.025);check(not simmer:IsPlaying(),"muted fade finishes")
        sounds.Destroy();sounds.Stop(handle,.05);check(not sounds.Play("wish_seal"),"destroyed manager cannot replay")

        -- Both new tracks honor existing independent settings, same-track checks and shop override.
        local musicPlayer=require("ui.landscape.SceneMusic").New()
        for _,route in ipairs({{"wish","wish"},{"ending","traveler","departure"}}) do
            musicPlayer.SetOptions(false,31);musicPlayer.Sync("home",route[1],route[3]);local source=music(route[2]);mp=plays
            check(source.gain==0,"new ending honors music mute")
            musicPlayer.SetOptions(true,31);musicPlayer.Sync("home",route[1],route[3])
            check(source.gain==.31 and plays==mp,"volume/unmute/same route without restart")
            musicPlayer.SetPresentationGain(.5);check(source.gain==.155,"presentation fade multiplies user volume")
            musicPlayer.SetPresentationGain(1);musicPlayer.Sync("home","shop",route[3]);music("seaside")
            musicPlayer.Sync("home",route[1],route[3]);music(route[2])
        end
        musicPlayer.Destroy()
        for _,voice in ipairs(voices) do check(not voice:IsPlaying(),"all owned sources cleaned up") end
        for _,node in ipairs(nodes) do check(node.removed==1,"audio components released exactly once") end
    end,debug.traceback)
    if view then view.root:Destroy() end
    Node=saved.Node;cache=saved.cache;SOUND_EFFECT=saved.effect;SOUND_MUSIC=saved.music;audio=saved.audio
    assert(ok,err)
    print("[EndingAudioTest] PASS assertions="..n.."; real transactions/views, isolated audio/storage; NOT native listening evidence")
    return n
end
return T
