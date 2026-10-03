-- B3 纯计算边界；没有状态、存档或事件。失败统一转换为 B0 Result。
local U = require "core.StateUtil"
local G = {}
function G.Need(condition, code, path, message, details)
    if not condition then error(U.Error(code, path, message, details), 0) end
end
function G.Finite(value)
    return type(value)=="number" and value==value and math.abs(value)<math.huge
end
function G.Nonnegative(value) return G.Finite(value) and value>=0 end
function G.Required(value, predicate, path)
    G.Need(value~=nil,"CONFIG_MISSING",path,"缺少配置：" .. path)
    G.Need(predicate(value),"CONFIG_INVALID",path,"配置类型或取值不合法：" .. path)
    return value
end
function G.Table(value) return type(value)=="table" end
function G.Keys(value, keys, path, code)
    local valid=U.Keys(value,keys,path)
    G.Need(valid.ok,code or "INVALID_REQUEST",path,"字段缺失、类型错误或含未知字段",valid.error)
end
function G.Pure(value, path, code)
    local valid=U.Validate(value)
    G.Need(valid.ok,code or "INVALID_REQUEST",path,"只接受可保存的纯数据",valid.error)
end
function G.Array(value, path, code)
    G.Need(U.Array(value),code or "INVALID_REQUEST",path,"须为从 1 开始的稠密数组")
end
function G.Value(result)
    if not result.ok then error(result.error,0) end
    return result.value
end
function G.Sorted(map)
    local keys={}
    for key in pairs(map) do keys[#keys+1]=key end
    table.sort(keys)
    return keys
end
---@return table
function G.Known(content, listName, id, path)
    G.Need(U.String(id),"INVALID_REQUEST",path,"引用 ID 须为非空字符串")
    local list=G.Required(content[listName],U.Array,listName)
    ---@type table|nil
    local found
    for _, item in ipairs(list) do
        G.Need(type(item)=="table" and U.String(item.id),"CONFIG_INVALID",listName,"配置条目缺少 ID")
        if item.id==id then
            G.Need(found==nil,"CONFIG_INVALID",listName .. "." .. id,"配置 ID 重复")
            found=item
        end
    end
    G.Need(found~=nil,"UNKNOWN_ID",path,"引用不存在",{id=id})
    return found --[[@as table]]
end
---@return table
function G.Run(callback)
    local ok, value=pcall(callback)
    if ok then return U.Ok(value) end
    if type(value)=="table" and U.String(value.code) then return {ok=false,error=value} end
    return U.Fail("CALCULATION_FAILED","calculation","计算异常",{reason=tostring(value)})
end
return G
