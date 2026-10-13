-- 双快照 + 双提交记录。只按完整提交记录选代，不按时间选快照。
-- 兼容旧 save_<slot>.json；默认 payload schema 仍为 1。
local U = require "core.StateUtil"
local Json = require "core.SaveJson"
local SaveSystem = {}
local function digest(s)
    local n = 0
    for i = 1, #s do n = (n * 31 + s:byte(i)) % 4294967291 end
    return string.format("%.0f", n)
end
local function paths(slot)
    slot = slot or "slot1"
    assert(type(slot) == "string" and slot:match("^[%w_]+$") and #slot <= 64, "非法存档槽")
    local base = "save_" .. slot
    return {legacy=base .. ".json", a=base .. "_a.json", b=base .. "_b.json",
        ca=base .. "_a.commit", cb=base .. "_b.commit"}
end
function SaveSystem.EngineStorage()
    return {
        exists = function(path) return fileSystem:FileExists(path) end,
        read = function(path)
            local f = File(path, FILE_READ)
            assert(f:IsOpen(), "无法打开读取 " .. path)
            local ok, value = pcall(function() return f:ReadString() end)
            local closed, err = pcall(function() f:Close() end)
            assert(ok, value); assert(closed, err)
            return value
        end,
        write = function(path, raw)
            local f = File(path, FILE_WRITE)
            assert(f:IsOpen(), "无法打开写入 " .. path)
            local ok, value = pcall(function()
                local written = f:WriteString(raw)
                f:Flush()
                return written
            end)
            local closed, err = pcall(function() f:Close() end)
            assert(ok, value); assert(closed, err)
            return value == true
        end,
        delete = function(path) return fileSystem:Delete(path) end,
    }
end
-- io 可为引擎 File 的故障包装器；不替换全局 File。
function SaveSystem.New(storage)
    local io = storage or SaveSystem.EngineStorage()
    local api = {}
    local function readOptional(path)
        if not io.exists(path) then return nil end
        return io.read(path)
    end
    local function parseMarker(raw, side)
        if type(raw) ~= "string" then return nil end
        local gen, actual, len, hash = raw:match("^B1|(%d+)|([ab])|(%d+)|(%d+)|END$")
        if actual ~= side or not U.Integer(tonumber(gen), 1) then return nil end
        return {generation=tonumber(gen),side=side,length=tonumber(len),hash=hash}
    end
    local function readCurrent(p)
        local ra, rb = readOptional(p.ca), readOptional(p.cb)
        local a, b = parseMarker(ra, "a"), parseMarker(rb, "b")
        local marker = a
        if b and (not a or b.generation > a.generation) then marker = b end
        if a and b and a.generation == b.generation then error("重复提交代数") end
        if marker then
            local raw = readOptional(p[marker.side])
            assert(raw and #raw == marker.length and digest(raw) == marker.hash, "已提交快照损坏")
            return raw, marker
        end
        local legacy = readOptional(p.legacy)
        if legacy then return legacy, nil end
        assert(not ra and not rb, "没有有效提交记录")
        return nil, nil
    end
    function api.GetSchemaVersion() return 1 end
    ---@param slot? string
    ---@return table|nil data
    ---@return table status
    function api.Load(slot)
        local ok, raw, marker = pcall(function() return readCurrent(paths(slot)) end)
        if not ok then return nil, {status="corrupt",error=U.Error("SAVE_READ_FAILED", "file", tostring(raw))} end
        if not raw then return nil, {status="new",schema=1} end
        if type(raw) ~= "string" then return nil,{status="corrupt",error=U.Error("SAVE_DECODE_FAILED","file","文件未返回文本")} end
        local decoded, env = pcall(Json.Decode, raw)
        if not decoded or type(env) ~= "table" or not U.Integer(env.schema, 1) or type(env.data) ~= "table" then
            return nil, {status="corrupt",error=U.Error("SAVE_DECODE_FAILED", "envelope", "文件损坏或结构不完整")}
        end
        local valid = U.Validate(env)
        if not valid.ok then return nil, {status="corrupt",error=valid.error} end
        if env.schema > 3 then return nil, {status="unsupported",schema=env.schema,error=U.Error("SAVE_UNSUPPORTED", "schema", "存档来自更高版本")} end
        for k in pairs(env) do
            if k ~= "schema" and k ~= "data" then return nil, {status="unsupported",error=U.Error("UNKNOWN_FIELD", k, "未知存档字段")} end
        end
        return env.data, {status="loaded",schema=env.schema,generation=marker and marker.generation or 0}
    end
    -- 已知结果：boolean + structured error。提交后介质拒绝读取时抛出
    -- SAVE_COMMIT_UNCERTAIN；协调者须锁定并重新 Load 对账，不能谎报 false。
    function api.Save(slot, data, schema)
        local valid = U.Validate(data)
        if not valid.ok then return false, valid.error end
        if type(data) ~= "table" or (schema ~= nil and schema ~= 1 and schema ~= 2 and schema ~= 3) then
            return false, U.Error("SAVE_VALUE_INVALID", "data", "非法数据或结构版本")
        end
        local encoded, raw = pcall(Json.Encode, {schema=schema or 1,data=data})
        if not encoded then return false, U.Error("SAVE_ENCODE_FAILED", "encode", tostring(raw)) end
        local roundtrip, parsed = pcall(Json.Decode, raw)
        if not roundtrip or not U.Equal(parsed, {schema=schema or 1,data=data}) then
            return false, U.Error("SAVE_ENCODE_FAILED", "encode", "编码往返不一致")
        end
        local existing, status = api.Load(slot)
        if not existing and status.status ~= "new" then return false, status.error end
        local stage, markerPath, markerText = "prepare", nil, nil
        local ok, err = pcall(function()
            local p = paths(slot)
            local _, current = readCurrent(p)
            local side = current and current.side == "a" and "b" or "a"
            local generation = current and current.generation + 1 or 1
            stage = "snapshot_write"
            assert(io.write(p[side], raw), "WriteString 返回 false")
            stage = "snapshot_readback"
            assert(io.read(p[side]) == raw, "快照读回不一致")
            markerPath = p["c" .. side]
            markerText = "B1|" .. generation .. "|" .. side .. "|" .. #raw .. "|" .. digest(raw) .. "|END"
            if io.checkpoint then io.checkpoint("before_commit") end
            stage = "commit"
            local written = io.write(markerPath, markerText)
            local observed = io.read(markerPath)
            assert(observed == markerText, written and "提交读回不一致" or "提交写入失败")
            if io.checkpoint then io.checkpoint("after_commit") end
        end)
        if ok then return true end
        if stage == "commit" then
            local readable, observed = pcall(readOptional, markerPath)
            if not readable then
                error(U.Error("SAVE_COMMIT_UNCERTAIN", "commit", "提交结果暂不可读；须重新读取对账，禁止继续推进", {cause=tostring(err)}), 0)
            end
            if observed == markerText then return true end
        end
        return false, U.Error("SAVE_WRITE_FAILED", stage, tostring(err))
    end
    function api.Exists(slot)
        local p = paths(slot)
        return io.exists(p.legacy) or io.exists(p.ca) or io.exists(p.cb)
    end
    function api.Delete(slot)
        local p, removed = paths(slot), false
        for _, path in pairs(p) do
            if io.exists(path) then
                if not io.delete(path) then return false end
                removed = true
            end
        end
        return removed
    end
    return api
end
local default = SaveSystem.New()
SaveSystem.Save = default.Save
SaveSystem.Load = default.Load
SaveSystem.Exists = default.Exists
SaveSystem.Delete = default.Delete
SaveSystem.GetSchemaVersion = default.GetSchemaVersion
return SaveSystem
