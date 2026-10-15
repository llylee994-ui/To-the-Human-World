-- One non-positional music source for the scene and its overlay panels.
local Music={}
local hearth="audio/bgm/hearth-warmth-loop.wav"
local seaside="audio/bgm/seaside-path-loop.wav"

function Music.New()
    local player={}
    local node,source,current
    local failed={}
    local destroyed=false

    function player.Sync(scene,panel)
        if destroyed then return end
        local path=(scene=="seaside" or panel=="shop") and seaside or hearth
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
            source:Play(sound,0,1)
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
