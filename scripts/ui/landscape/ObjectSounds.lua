-- One-shot object foley. Never changes the Music channel or its sources.
local S={}
local paths=require("ui.landscape.AudioCatalog").EffectPaths()

function S.New()
    local player={}
    ---@type Node|nil
    local node
    ---@type SoundSource[]
    local voices={}
    ---@type table<string,Sound>
    local sounds={}
    local reported={}
    local destroyed=false
    local gain=1 --[[@as number]]
    function player.SetOptions(enabled,volume)
        if destroyed then return end
        gain=enabled and math.max(0,math.min(100,volume))/100 or 0
        -- Only our object voices change; the existing effects bus still applies.
        for _,voice in ipairs(voices) do voice:SetGain(gain) end
    end
    local function load(id)
        if sounds[id] then return sounds[id] end
        local sound=assert(cache:GetResource("Sound",paths[id]),"missing sound: "..paths[id])
        sound:SetLooped(false);sounds[id]=sound
        return sound
    end
    local function report(id,err)
        if reported[id] then return end
        reported[id]=true;print("[ObjectSounds] "..paths[id]..": "..tostring(err))
    end
    -- Warm the small resources without playing on initialization/restoration.
    -- A transient load failure may retry on the next real action, never later replay it.
    if Node and cache and SOUND_EFFECT then
        for id in pairs(paths) do local ok,err=pcall(load,id);if not ok then report(id,err) end end
    end
    function player.Play(id)
        if destroyed or gain<=0 or not paths[id] or not Node or not cache or not SOUND_EFFECT then return false end
        local ok,result=pcall(function()
            local sound=load(id)
            ---@type SoundSource|nil
            local source
            for _,voice in ipairs(voices) do if not voice:IsPlaying() then source=voice;break end end
            if not source then
                -- Bound resource use without cutting off a previous sound or any BGM.
                if #voices>=8 then return false end
                node=node or Node()
                source=node:CreateComponent("SoundSource")
                source:SetSoundType(SOUND_EFFECT)
                voices[#voices+1]=source
            end
            -- Per-file gain stays at 1.0; apply only the shared user preference.
            source:Play(sound,0,1.0*gain)
            return true
        end)
        if not ok then report(id,result);return false end
        return result
    end
    function player.Destroy()
        if destroyed then return end
        destroyed=true
        for _,voice in ipairs(voices) do voice:Stop() end
        if node then node:RemoveAllComponents() end
        node=nil;voices={};sounds={}
    end
    return player
end
return S
