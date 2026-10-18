-- Device-local listening preferences, independent of the gameplay save/schema.
local Json=require "core.SaveJson"
local SaveSystem=require "core.SaveSystem"
local M={}
local path="music_settings.json"
local defaultVolume=60
local function volume(value)
    if type(value)~="number" or value~=value or value==math.huge or value==-math.huge then return defaultVolume end
    return math.floor(math.max(0,math.min(100,value))+.5)
end

function M.New(storage)
    storage=storage or SaveSystem.EngineStorage()
    local enabled,level=true,defaultVolume
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
            assert(storage.write(path,raw),"music preferences write failed")
            assert(storage.read(path)==raw,"music preferences readback failed")
        end)
        if not written then
            print("[MusicSettings] "..tostring(err))
            return false
        end
        saved=raw;return true
    end
    return api
end
return M
