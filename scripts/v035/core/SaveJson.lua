-- cjson 的结构/字符串处理保持不变；绕过原生数字转换的末位精度损失。
-- 磁盘仍为普通 JSON，未引入存档字段或玩法数值容差。
local Json = {}
local function stringEnd(raw, start)
    local i=start+1
    while i<=#raw do
        local char=raw:sub(i,i)
        if char=='\\' then i=i+2
        elseif char=='"' then return i
        else i=i+1 end
    end
    error("unterminated JSON string")
end
local function placeholders(value)
    local occupied, replacements, serial = {}, {}, 0
    local function visit(v)
        if type(v) == "string" then occupied[v] = true
        elseif type(v) == "table" then
            for k,x in pairs(v) do visit(k); visit(x) end
        end
    end
    visit(value)
    local function add(v)
        local key
        repeat serial=serial+1; key="__save_number_" .. serial .. "__" until not occupied[key]
        occupied[key]=true; replacements[key]=v
        return key
    end
    return add,replacements
end
function Json.Encode(value)
    local add,numbers = placeholders(value)
    local function replace(v)
        if type(v) == "number" then
            assert(v==v and math.abs(v)<math.huge,"non-finite number")
            return add(math.type(v)=="integer" and string.format("%d",v) or string.format("%.17g",v))
        end
        if type(v) ~= "table" then return v end
        local copy={}
        for k,x in pairs(v) do copy[k]=replace(x) end
        return copy
    end
    local raw=cjson.encode(replace(value))
    local parts,i={},1
    while i<=#raw do
        if raw:sub(i,i)=='"' then
            local finish=stringEnd(raw,i)
            local token=raw:sub(i,finish)
            local key=token:match('^"(__save_number_%d+__)"$')
            parts[#parts+1]=(key and numbers[key]) or token
            i=finish+1
        else parts[#parts+1]=raw:sub(i,i); i=i+1 end
    end
    return table.concat(parts)
end
function Json.Decode(raw)
    -- 先让 cjson 验证完整 JSON 语法；不让数字替换掩盖非法输入。
    local original=cjson.decode(raw)
    local add,numbers=placeholders(original)
    local parts,i={},1
    while i<=#raw do
        local char=raw:sub(i,i)
        if char=='"' then
            local finish=stringEnd(raw,i)
            parts[#parts+1]=raw:sub(i,finish); i=finish+1
        elseif char=='-' or char:match('%d') then
            local finish=i+1
            while finish<=#raw and raw:sub(finish,finish):match('[%d.eE+%-]') do finish=finish+1 end
            local number=assert(tonumber(raw:sub(i,finish-1)),"invalid JSON number")
            parts[#parts+1]='"' .. add(number) .. '"'; i=finish
        else parts[#parts+1]=char; i=i+1 end
    end
    local function restore(v)
        if type(v)=="string" and numbers[v]~=nil then return numbers[v] end
        if type(v)=="table" then for k,x in pairs(v) do v[k]=restore(x) end end
        return v
    end
    return restore(cjson.decode(table.concat(parts)))
end
return Json
