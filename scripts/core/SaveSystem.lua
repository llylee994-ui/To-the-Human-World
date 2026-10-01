-- ============================================================================
-- SaveSystem — 本地存档读写
--
-- 引擎的 File API 自带「项目隔离 + 用户隔离」，脚本里直接用相对路径即可。
-- 见 engine-docs/recipes/file-storage.md
--
-- 存档格式：
--   { schema = <结构版本号>, data = <游戏数据表> }
--
-- 读取策略（见开发计划 B3）：任何异常都回落默认值并打印原因，不抛异常、不崩溃。
--   - 文件不存在
--   - JSON 解析失败
--   - 缺少版本号 / 版本号比当前新
--   - 缺少 data 字段
-- ============================================================================

local SaveSystem = {}

--- 存档结构版本号。改动 data 的结构时 +1，并在 Migrate 里补迁移。
local SCHEMA_VERSION = 1

local DEFAULT_SLOT = "slot1"

---@param slotName? string
---@return string
local function BuildPath(slotName)
    local slot = slotName or DEFAULT_SLOT
    return "save_" .. slot .. ".json"
end

--- 当前存档结构版本号。
---@return integer
function SaveSystem.GetSchemaVersion()
    return SCHEMA_VERSION
end

--- 写入存档。
---@param slotName? string 槽位名，默认 slot1
---@param data table 待保存的游戏数据
---@return boolean ok
---@return string? err
function SaveSystem.Save(slotName, data)
    if type(data) ~= "table" then
        return false, "SaveSystem.Save: data 必须是 table"
    end

    local path = BuildPath(slotName)
    local file = File(path, FILE_WRITE)
    if not file:IsOpen() then
        print("[SaveSystem] 无法打开存档文件写入: " .. path)
        return false, "无法打开文件"
    end

    local encoded = cjson.encode({
        schema = SCHEMA_VERSION,
        data = data,
    })
    file:WriteString(encoded)
    file:Close()

    print(string.format("[SaveSystem] 已保存 %s（%d 字节）", path, #encoded))
    return true, nil
end

--- 读取存档。任何异常都返回 nil，由调用方回落到默认值。
---@param slotName? string 槽位名，默认 slot1
---@return table|nil data
function SaveSystem.Load(slotName)
    local path = BuildPath(slotName)
    if not fileSystem:FileExists(path) then
        return nil
    end

    local file = File(path, FILE_READ)
    if not file:IsOpen() then
        print("[SaveSystem] 无法打开存档文件读取，回落默认值: " .. path)
        return nil
    end
    local raw = file:ReadString()
    file:Close()

    local ok, decoded = pcall(cjson.decode, raw)
    if not ok or type(decoded) ~= "table" then
        print("[SaveSystem] 存档解析失败，回落默认值: " .. path)
        return nil
    end

    local schema = decoded.schema
    if type(schema) ~= "number" then
        print("[SaveSystem] 存档缺少结构版本号，回落默认值: " .. path)
        return nil
    end
    if schema > SCHEMA_VERSION then
        print(string.format(
            "[SaveSystem] 存档版本过新（存档 %d > 当前 %d），回落默认值: %s",
            schema, SCHEMA_VERSION, path
        ))
        return nil
    end

    if type(decoded.data) ~= "table" then
        print("[SaveSystem] 存档缺少 data 字段，回落默认值: " .. path)
        return nil
    end

    if schema < SCHEMA_VERSION then
        print(string.format(
            "[SaveSystem] 存档版本较旧（存档 %d < 当前 %d），已按当前结构读取: %s",
            schema, SCHEMA_VERSION, path
        ))
        -- 目前尚无历史版本需要迁移；出现 v1 -> v2 时在此补 Migrate 分支
    end

    return decoded.data
end

--- 判断存档是否存在。
---@param slotName? string
---@return boolean
function SaveSystem.Exists(slotName)
    return fileSystem:FileExists(BuildPath(slotName))
end

--- 删除存档（回溯 / 重开用）。
---@param slotName? string
---@return boolean
function SaveSystem.Delete(slotName)
    local path = BuildPath(slotName)
    if not fileSystem:FileExists(path) then
        return false
    end
    fileSystem:Delete(path)
    print("[SaveSystem] 已删除存档: " .. path)
    return true
end

return SaveSystem
