-- 定点读回故障注入；实际数据仍写原生File，不修改全局File或正式SaveSystem。
local Lab = {}
local SLOT = "b6_uncertain_20261004_a"
local armed, blocked = false, false
local blockedPath = ""
local blockedReads, committedWrites = 0, 0
function Lab.Status()
    return {armed=armed, blocked=blocked, blockedPath=blockedPath,
        blockedReads=blockedReads, committedWrites=committedWrites}
end
function Lab.Arm()
    if armed or blocked then return false end
    armed = true
    return true
end
function Lab.Release() armed=false; blocked=false end
---@param saveSystem table
---@param slot string
function Lab.New(saveSystem, slot)
    assert(slot == SLOT, "读回实验只允许指定独立槽")
    local native = saveSystem.EngineStorage()
    local function checkPath(path)
        assert(path == "save_" .. SLOT .. ".json" or path:match("^save_" .. SLOT .. "_[ab]%.json$")
            or path:match("^save_" .. SLOT .. "_[ab]%.commit$"), "读回实验禁止访问其他槽")
    end
    local storage = {}
    function storage.exists(path) checkPath(path); return native.exists(path) end
    function storage.read(path)
        checkPath(path)
        if blocked and path == blockedPath then
            blockedReads = blockedReads + 1
            error("B6 injected commit readback failure", 0)
        end
        return native.read(path)
    end
    function storage.write(path, raw)
        checkPath(path)
        local written = native.write(path, raw)
        if written and armed and path:match("%.commit$") then
            armed=false; blocked=true; blockedPath=path
            committedWrites=committedWrites+1
            print("[B6UncertainCommitted] " .. cjson.encode(Lab.Status()))
        end
        return written
    end
    function storage.delete(path) checkPath(path); return native.delete(path) end
    return saveSystem.New(storage)
end
return Lab
