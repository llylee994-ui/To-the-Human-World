-- 存档和纯计算共用的值工具；不依赖引擎或业务配置。
local U = {}
function U.Error(code, path, message, details)
    return { code = code, path = path or "", message = message, details = details or {} }
end
function U.Fail(code, path, message, details)
    return { ok = false, error = U.Error(code, path, message, details) }
end
function U.Ok(value) return { ok = true, value = value } end
function U.Integer(n, minimum)
    return type(n) == "number" and n <= 9007199254740991 and n == math.floor(n) and n >= (minimum or 0)
end
function U.String(s) return type(s) == "string" and s ~= "" end
function U.Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = U.Copy(x) end
    return t
end
function U.Equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not U.Equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
function U.Array(t)
    if type(t) ~= "table" then return false end
    local count = 0
    for k in pairs(t) do
        if not U.Integer(k, 1) then return false end
        count = count + 1
    end
    return count == #t
end
-- JSON 的表必须是字符串键对象或连续数组，拒绝混合键、循环、元表和非法标量。
function U.Validate(value)
    local active = {}
    local function walk(v, path)
        local kind = type(v)
        if kind == "string" or kind == "boolean" then return nil end
        if kind == "number" and v == v and math.abs(v) < math.huge then return nil end
        if kind ~= "table" then return U.Error("SAVE_VALUE_INVALID", path, "不是可保存的有限值") end
        if active[v] or getmetatable(v) then return U.Error("SAVE_VALUE_INVALID", path, "循环或带元表的对象") end
        active[v] = true
        local numeric, strings, count = false, false, 0
        for k, x in pairs(v) do
            if type(k) == "string" then strings = true
            elseif U.Integer(k, 1) then numeric = true
            else return U.Error("SAVE_KEY_INVALID", path, "非法键") end
            count = count + 1
            local err = walk(x, path .. "." .. tostring(k))
            if err then return err end
        end
        active[v] = nil
        if (numeric and strings) or (numeric and count ~= #v) then
            return U.Error("SAVE_KEY_INVALID", path, "混合键或不连续数组")
        end
    end
    local err = walk(value, "data")
    if err then return { ok = false, error = err } end
    return U.Ok(value)
end
---@return table
function U.Keys(t, allowed, path)
    if type(t) ~= "table" then return U.Fail("STATE_INVALID", path, "需要对象") end
    for key in pairs(t) do
        if not allowed[key] then return U.Fail("UNKNOWN_FIELD", path .. "." .. tostring(key), "未知字段，保留原档") end
    end
    return U.Ok(t)
end
return U
