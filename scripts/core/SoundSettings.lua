-- Device-local object sound preferences, independent of music and gameplay saves.
local Json=require "core.SaveJson"
local SaveSystem=require "core.SaveSystem"
local S={}
local path="sound_settings.json"
local function volume(value)
    if type(value)~="number" or value~=value or value==math.huge or value==-math.huge then return 100 end
    return math.floor(math.max(0,math.min(100,value))+.5)
end

function S.New(storage)
    storage=storage or SaveSystem.EngineStorage()
    local enabled,level=true,100
    local saved
    local ok,loaded=pcall(function()
        if not storage.exists(path) then return nil end
        return Json.Decode(storage.read(path))
    end)
    if ok and type(loaded)=="table" and loaded.version==1 then
        enabled=loaded.enabled~=false;level=volume(loaded.volume)
    end
    local function encode() return Json.Encode({version=1,enabled=enabled,volume=level}) end
    -- Missing/corrupt preferences are repaired on the next explicit settings save.
    if ok and type(loaded)=="table" and loaded.version==1 then saved=encode() end
    local api={}
    function api.Get() return {enabled=enabled,volume=level} end
    function api.SetEnabled(value) enabled=value==true end
    function api.SetVolume(value) level=volume(value) end
    function api.Save()
        local raw=encode()
        if raw==saved then return true end
        local written,err=pcall(function()
            assert(storage.write(path,raw),"sound preferences write failed")
            assert(storage.read(path)==raw,"sound preferences readback failed")
        end)
        if not written then
            print("[SoundSettings] "..tostring(err))
            return false
        end
        saved=raw;return true
    end
    return api
end
return S
