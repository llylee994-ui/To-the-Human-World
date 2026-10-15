-- Real navigation and lifecycle; explicit audio adapters, not speaker/device evidence.
local T={}
function T.Run()
    Stop() -- Release the runner's initial UI before installing audio adapters.
    local savedNode,savedCache,savedType=Node,cache,SOUND_MUSIC
    local n=0
    local function check(value,message) n=n+1;assert(value,message) end
    local hearth="audio/bgm/hearth-warmth-loop.wav"
    local seaside="audio/bgm/seaside-path-loop.wav"
    local plays,nodes,removed,loads=0,0,0,{}
    local active,missing
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
                check(frequency==0 and gain==1,"preserve file speed and approved mix")
                active=sound.path;plays=plays+1
            end
            function source:Stop() active=nil end
            return source
        end
        function owner:RemoveAllComponents()
            check(active==nil,"stop audio before releasing the node")
            removed=removed+1
        end
        return owner
    end
    local ok,err=pcall(function()
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
        local before=x.state.GetSnapshot();local writes=x.writes
        for _=1,10 do view.Refresh();view.Update() end
        check(plays==1,"UI refresh does not restart music")
        view.Open("letters");view.Update();view.Close();view.Update()
        check(plays==1,"home panels keep hearth playing")
        view.Open("shop");view.Update()
        check(active==seaside and plays==2,"home shop overrides hearth")
        click("shop_select_ing_night_dew")
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
    Node,cache,SOUND_MUSIC=savedNode,savedCache,savedType
    assert(ok,err)
    print("[SceneMusicTest] PASS assertions="..n.."; schema4 navigation, purchase, salvage/reader, no overlap/restart, missing asset and main Stop; audio adapters only")
    return true
end
return T
