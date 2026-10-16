-- Real navigation and lifecycle; explicit audio adapters, not speaker/device evidence.
local T={}
function T.Run()
    Stop() -- Release the runner's initial UI before installing audio adapters.
    local savedNode,savedCache,savedType=Node,cache,SOUND_MUSIC
    local n=0
    local function check(value,message) n=n+1;assert(value,message) end
    local Preferences=require "core.MusicSettings"
    local Json=require "core.SaveJson"
    local files,writes={},0
    local fault=false --[[@as string|boolean]]
    local storage={
        exists=function(path) return files[path]~=nil end,
        read=function(path) if fault=="read" then error("test read failure") end;return files[path] end,
        write=function(path,raw)
            check(path=="music_settings.json","preferences never write a gameplay save")
            writes=writes+1
            if fault=="write" then return false end
            files[path]=fault=="truncate" and "{" or raw;return true
        end,
    }
    local preferences=Preferences.New(storage)
    check(preferences.Get().enabled and preferences.Get().volume==100,"missing preferences default to approved volume")
    preferences.SetEnabled(false);preferences.SetVolume(37);check(preferences.Save(),"save preferences")
    local restored=Preferences.New(storage).Get()
    check(not restored.enabled and restored.volume==37,"new instance restores mute and volume")
    local writeCount=writes;preferences.Save();check(writes==writeCount,"unchanged settings avoid redundant writes")
    preferences.SetVolume(-8);check(preferences.Get().volume==0,"volume clamps at zero")
    preferences.SetVolume(140);check(preferences.Get().volume==100,"volume clamps at approved maximum")
    preferences.SetVolume(25);fault="write"
    check(not preferences.Save() and preferences.Get().volume==25,"failed persistence keeps current listening preference")
    check(Preferences.New(storage).Get().volume==37,"failed write preserves last saved preference")
    fault=false;check(preferences.Save(),"retry saves after storage recovers")
    preferences.SetVolume(50);fault="truncate";check(not preferences.Save(),"readback catches truncated write")
    fault=false
    restored=Preferences.New(storage).Get()
    check(restored.enabled and restored.volume==100,"corrupt settings do not stop startup")
    files["music_settings.json"]=Json.Encode({version=1,enabled=false,volume=250})
    check(Preferences.New(storage).Get().volume==100,"invalid stored volume is bounded")
    fault="read";check(Preferences.New(storage).Get().enabled,"read failure falls back safely");fault=false
    local badView=require("ui.landscape.MusicSettingsView").New(Preferences.New(storage),function() end)
    fault="write"
    local badToggle=assert(badView.root:FindById("musicEnabled"))
    badToggle:SetValue(true)
    check(assert(badView.root:FindById("musicSettingsHint")):GetText():find("未能保存",1,true),"UI reports persistence failure without hiding immediate effect")
    badView.root:Destroy();fault=false
    local hearth="audio/bgm/hearth-warmth-loop.wav"
    local seaside="audio/bgm/seaside-path-loop.wav"
    local plays,nodes,removed,loads=0,0,0,{}
    local active,missing,actualGain
    SOUND_MUSIC="Music"
    cache={GetResource=function(_,kind,path)
        check(kind=="Sound","loads an audio resource")
        check(path==hearth or path==seaside,"uses packaged BGM paths")
        loads[path]=(loads[path] or 0)+1
        if path==missing then return nil end
        return {path=path,SetLooped=function(self,value) self.looped=value end}
    end}
    Node=function()
        nodes=nodes+1
        local owner={}
        function owner:CreateComponent(kind)
            check(kind=="SoundSource","non-positional music source")
            local source={}
            function source:SetSoundType(kind) check(kind==SOUND_MUSIC,"music volume group") end
            function source:Play(sound,frequency,gain)
                check(active==nil,"previous track must stop before replacement")
                check(sound.looped==true,"whole track loops")
                check(frequency==0 and gain>=0 and gain<=1,"preserve speed and never amplify approved mix")
                actualGain=gain
                active=sound.path;plays=plays+1
            end
            function source:Stop() active=nil end
            function source:SetGain(value) actualGain=value end
            return source
        end
        function owner:RemoveAllComponents()
            check(active==nil,"stop audio before releasing the node")
            removed=removed+1
        end
        return owner
    end
    -- Native engine globals can be exposed by getters rather than raw table keys.
    local originalMetatable=getmetatable(_G)
    local boundNode,boundCache=Node,cache
    Node=nil;cache=nil
    setmetatable(_G,{__index=function(t,key)
        if key=="Node" then return boundNode end
        if key=="cache" then return boundCache end
        local index=originalMetatable and originalMetatable.__index
        if type(index)=="function" then return index(t,key) end
        if type(index)=="table" then return index[key] end
    end})
    local ok,err=pcall(function()
        check(Node~=nil and cache~=nil and rawget(_G,"cache")==nil,"engine globals available through getters")
        package.loaded["debug.DeveloperMode"]=false
        local host=require("ui.landscape.tests.ZoomTestHost").New()
        local data=require "data.content"
        local x=require("debug.fixtures.B5Fixtures").New(data,{targetSchema=4})
        local view=require("ui.PlayView").New(x.session,data)
        host.Bind(view.root)
        local function click(id)
            local control=assert(view.root:FindById(id),"missing "..id)
            check(not control.props.disabled,"enabled "..id)
            control.props.onClick();view.Update();host.Bind(view.root)
        end
        check(active==hearth and plays==1,"initial homepage plays hearth")
        check(actualGain==1,"initial gain keeps approved mix")
        local before=x.state.GetSnapshot();local writes=x.writes
        click("openSettings")
        local settingsOverlay=view.root:FindById("musicSettingsOverlay")
        check(settingsOverlay.props.visible and view.scene=="home" and not view.panel,"settings opens over the existing scene")
        local toggle=view.root:FindById("musicEnabled")
        local slider=view.root:FindById("musicVolume")
        slider:SetValue(37);view.Update()
        check(actualGain==.37 and plays==1,"drag changes gain immediately without restarting")
        check(view.root:FindById("musicVolume")==slider,"UI updates preserve slider and drag state")
        check(view.root:FindById("musicVolumeValue"):GetText()=="37%","volume percentage follows slider")
        toggle:SetValue(false)
        check(actualGain==0 and active==hearth and plays==1,"mute preserves current track position")
        slider:SetValue(25);slider.props.onChangeEnd(slider,25)
        check(actualGain==0,"adjusting volume while muted does not unmute")
        local closeSettings=view.root:FindById("closeMusicSettings")
        closeSettings.props.onClick()
        check(settingsOverlay.props.visible,"modal blocks until pointer-up/update")
        view.Update();check(not settingsOverlay.props.visible,"close returns to original page")
        local savedPreferences=Preferences.New().Get()
        check(not savedPreferences.enabled and savedPreferences.volume==25,"File adapter roundtrip retains latest preferences")
        click("openSettings");toggle:SetValue(true)
        check(actualGain==.25 and plays==1,"unmute restores selected volume without restarting")
        slider:SetValue(0);check(actualGain==0,"zero volume is silent with switch on")
        slider:SetValue(100);slider.props.onChangeEnd(slider,100);click("closeMusicSettings")
        check(actualGain==1 and plays==1,"maximum restores original mix")
        for _=1,10 do view.Refresh();view.Update() end
        check(plays==1,"UI refresh does not restart music")
        view.Open("letters");view.Update();view.Close();view.Update()
        check(plays==1,"home panels keep hearth playing")
        view.Open("shop");view.Update()
        check(active==seaside and plays==2,"home shop overrides hearth")
        click("shop_select_ing_night_dew")
        local selected=view.shopSelectedId
        click("shopSettings")
        check(view.panel=="shop" and view.shopSelectedId==selected and active==seaside and plays==2,"shop settings preserves selection and seaside track")
        click("closeMusicSettings")
        check(plays==2,"shop selection keeps music position")
        check(require("core.StateUtil").Equal(before,x.state.GetSnapshot()) and x.writes==writes,"music/navigation never saves progress")
        click("buy_ing_night_dew")
        check(active==seaside and plays==2,"purchase refresh keeps music playing")
        click("closePanel")
        check(active==hearth and plays==3,"shop close returns to hearth")
        view.Navigate("seaside");view.Update();host.Bind(view.root)
        check(active==seaside and plays==4,"salvage scene plays seaside")
        click("seasideShop");click("closePanel")
        check(active==seaside and plays==4,"sea/shop/sea never restarts shared track")
        click("startSalvage")
        check(view.salvage.active,"real salvage presentation started")
        click("skipSalvage")
        check(view.panel=="reader" and active==seaside and plays==4,"captured letter preserves seaside music")
        click("closePanel");view.Navigate("home");view.Update()
        check(active==hearth and plays==5,"return home restores hearth")
        view.Navigate("brew");view.Update()
        check(active==hearth and plays==5,"brewing in the house keeps hearth")
        view.Open("shop");view.Update();click("closePanel")
        check(view.scene=="brew" and active==hearth,"shop restores underlying brewing music")
        check(nodes==1,"one audio node across all scene transitions")
        view.root:Destroy();view.root:Destroy();view.Update()
        check(active==nil and removed==1,"destroy stops/releases once and cannot restart")

        local player=require("ui.landscape.SceneMusic").New()
        player.SetOptions(false,45);player.Sync("home",false)
        check(actualGain==0 and active==hearth,"muted startup has no audible first frame")
        player.Sync("seaside",false)
        check(actualGain==0 and active==seaside,"scene change respects mute")
        local mutedPlays=plays
        player.SetOptions(true,45)
        check(actualGain==.45 and plays==mutedPlays,"unmute current scene without restart")
        player.SetOptions(true,100)
        player.Sync("home",false);missing=seaside
        local attempts=loads[seaside]
        player.Sync("home","shop")
        check(active==nil,"missing requested music never leaves wrong music playing")
        player.Sync("home","shop")
        check(loads[seaside]==attempts+1,"missing asset is reported without repeated load attempts")
        player.Sync("home",false)
        check(active==hearth,"available track still works after missing resource")
        player.Destroy();missing=nil

        Start()
        check(active==hearth,"real main Start owns homepage music")
        local removedBefore=removed
        Stop();Stop()
        check(active==nil and removed==removedBefore+1,"real main Stop releases music exactly once")
    end)
    setmetatable(_G,originalMetatable)
    Node,cache,SOUND_MUSIC=savedNode,savedCache,savedType
    assert(ok,err)
    print("[SceneMusicTest] PASS assertions="..n.."; music settings/persistence/failures, schema4 navigation, no overlap/restart, missing asset and main Stop; audio adapters only")
    return true
end
return T
