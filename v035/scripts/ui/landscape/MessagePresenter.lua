-- Player-facing projection only: never writes back to business diagnostics.
local M = {}
local MIGRATION_TEXT = "进度已更新。今天先休息吧，明天再去海边。"
local function finite(value)
    return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end
local function playerText(raw, migrationNotice, important)
    if raw==migrationNotice then return MIGRATION_TEXT end
    if important and (raw:find("[%a_]+=[^%s]+") or raw:find("[A-Z][A-Z_]+")
        or raw:find("[%a][%w]*_[%w_]+")
        or raw:find("stack traceback",1,true) or raw:find(".lua:",1,true)) then
        return "暂时无法完成，请重试。若仍未恢复，请稍后再来。"
    end
    return raw
end
function M.New(migrationNotice)
    local self = {raw=nil, text="", persistent=false, startedAt=0}
    -- renew is reserved for a new Notify event, never per-frame observations.
    function self:Observe(raw, now, important, renew)
        raw = type(raw)=="string" and raw or ""
        if raw==self.raw and renew~=true then
            if important==true and raw~="" and not self.persistent then
                self.persistent=true
                self.text=playerText(raw,migrationNotice,true)
            end
            return
        end
        self.raw=raw
        self.persistent=important==true and raw~=""
        self.startedAt=finite(now) and now or 0
        self.text=raw~="" and playerText(raw,migrationNotice,self.persistent) or ""
    end
    function self:Current(now)
        now=finite(now) and now or self.startedAt
        return {text=self.text, visible=self.text~="" and (self.persistent or now-self.startedAt<5),
            persistent=self.persistent}
    end
    return self
end
return M
