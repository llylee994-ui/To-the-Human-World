-- One non-positional music source for the scene and its overlay panels.
local Audio=require "ui.landscape.AudioCatalog"
local Music={}
local hearth=assert(Audio.BgmPath("hearth"),"missing hearth BGM")
local seaside=assert(Audio.BgmPath("seaside"),"missing seaside BGM")
local brewing=assert(Audio.BgmPath("brewing"),"missing brewing BGM")
local traveler=assert(Audio.BgmPath("traveler"),"missing traveler BGM")
local wish=assert(Audio.BgmPath("wish"),"missing wish BGM")

function Music.New()
    local player={}
    ---@type Node|nil
    local node
    ---@type SoundSource|nil
    local source
    ---@type string|nil
    local current
    local failed={}
    local destroyed=false
    local gain=1 --[[@as number]]
    local presentationGain=1 --[[@as number]]

    function player.SetOptions(enabled,volume)
        if destroyed then return end
        gain=enabled and math.max(0,math.min(100,volume))/100 or 0
        if source then source:SetGain(gain*presentationGain) end
    end

    -- Temporary ending fade, independent from persisted volume/mute preferences.
    function player.SetPresentationGain(value)
        if destroyed then return end
        local nextGain=math.max(0,math.min(1,value))
        if presentationGain==nextGain then return end
        presentationGain=nextGain
        if source then source:SetGain(gain*presentationGain) end
    end

    function player.Sync(scene,panel,endingKind)
        if destroyed then return end
        local ending=panel=="ending" or panel=="memoryReview"
        local path
        if panel=="shop" then path=seaside
        elseif panel=="wish" or panel=="wishPreview" or (ending and endingKind=="wish") then path=wish
        elseif panel=="departure" or (ending and endingKind=="departure") then path=traveler
        else path=scene=="seaside" and seaside or (scene=="brew" and brewing or hearth) end
        if current==path then return end
        -- Native cache is a global getter; rawget would incorrectly skip playback.
        -- Isolated business/UI tests have neither of these native bindings.
        if not Node or not cache then return end
        if source then source:Stop();current=nil end
        if failed[path] then return end
        local ok,err=pcall(function()
            local sound=assert(cache:GetResource("Sound",path),"missing sound: "..path)
            sound:SetLooped(true)
            if not source then
                node=node or Node()
                source=node:CreateComponent("SoundSource")
                source:SetSoundType(SOUND_MUSIC)
            end
            -- Use each file's sample rate and preserve its approved mix/gain.
            source:Play(sound,0,gain*presentationGain)
            current=path
        end)
        if not ok then
            failed[path]=true
            print("[SceneMusic] "..path..": "..tostring(err))
        end
    end

    function player.Destroy()
        if destroyed then return end
        destroyed=true
        if source then source:Stop() end
        if node then node:RemoveAllComponents() end
        source=nil;node=nil;current=nil
    end

    return player
end

return Music
