-- 信件独占状态。候选接口返回 {state,instanceId,changed,source?}，不保存/安装/通知。
-- GetView/ParseDefinition 返回 Result；状态读取和恢复与 Economy 使用相同约定。
local U = require "core.StateUtil"
local Letter = {}
function Letter.New(content)
    ---@type table|nil
    local state
    local api = {}
    ---@return table<string, any> Result
    local function definition(id)
        if not U.String(id) then return U.Fail("INVALID_REQUEST", "letterId", "信件 ID 须为非空字符串") end
        local d = content.GetLetter(id)
        if not d then return U.Fail("UNKNOWN_ID", "letterId", "未知信件", {id=id}) end
        return U.Ok(d)
    end
    function api.ParseDefinition(id)
        local found = definition(id)
        if not found.ok then return found end
        local d, segments, spans = found.value, {}, {}
        if d.kind == "direct_followup" then
            if d.cuttable ~= false then return U.Fail("CONFIG_INVALID", "letters." .. id .. ".cuttable", "直接回信必须不可剪") end
            return U.Ok({letterId=id,kind=d.kind,cuttable=false,segments=segments,spans=spans,address=d.address})
        end
        if d.kind ~= "order" or type(d.cuttable) ~= "boolean" then return U.Fail("CONFIG_INVALID", "letters." .. id .. ".kind", "非法信件种类或剪裁标志") end
        for _, key in ipairs({"selfIntro","body","address"}) do
            if type(d[key]) ~= "string" or not utf8.len(d[key]) then
                return U.Fail("CONFIG_INVALID", "letters." .. id .. "." .. key, "文本须为有效 UTF-8 字符串")
            end
        end
        local cursor = 1
        while cursor <= #d.body do
            local first = d.body:find("{{", cursor, true)
            local stray = d.body:find("}}", cursor, true)
            if stray and (not first or stray < first) then return U.Fail("CONFIG_INVALID", "letters." .. id .. ".body", "多余的标记结束符") end
            if not first then segments[#segments+1] = {kind="text",text=d.body:sub(cursor)}; break end
            if first > cursor then segments[#segments+1] = {kind="text",text=d.body:sub(cursor,first-1)} end
            local last = d.body:find("}}", first+2, true)
            if not last then return U.Fail("CONFIG_INVALID", "letters." .. id .. ".body", "词标记未闭合") end
            local text = d.body:sub(first+2,last-1)
            if text == "" or text:find("[{}]") or not d.cuttable then return U.Fail("CONFIG_INVALID", "letters." .. id .. ".body", "空、嵌套或不可剪文本中的标记") end
            local word = content.GetWordByText(text)
            if not word then return U.Fail("UNKNOWN_ID", "letters." .. id .. ".body", "标记没有对应词定义", {text=text,position=#spans+1}) end
            local span = {kind="word",spanId="body:" .. (#spans+1),wordId=word.id,text=text,cut=false}
            spans[#spans+1], segments[#segments+1] = U.Copy(span), span
            cursor = last+2
        end
        return U.Ok({letterId=id,kind=d.kind,cuttable=d.cuttable,selfIntro=d.selfIntro,address=d.address,segments=segments,spans=spans})
    end
    function api.InitialSnapshot()
        if not U.String(content.contentVersion) then return U.Fail("CONFIG_MISSING", "contentVersion", "缺少内容版本") end
        return U.Ok({byId={},bottleQueue={},directArchive={}})
    end
    ---@return table<string, any> Result
    local function idArray(values, path)
        if not U.Array(values) then return U.Fail("STATE_INVALID", path, "须为稠密 ID 数组") end
        local seen = {}
        for _, id in ipairs(values) do
            if not U.String(id) or seen[id] then return U.Fail("STATE_INVALID", path, "ID 为空或重复") end
            seen[id] = true
        end
        return U.Ok(values)
    end
    ---@return table<string, any> Result
    local function archiveValid(record, path)
        local fields = U.Keys(record, {transactionId=true,letterId=true,renderedText=true,fragmentIds=true,rating=true}, path)
        if not fields.ok then return fields end
        local found = definition(record.letterId)
        if not found.ok then return found end
        if found.value.kind ~= "direct_followup" or found.value.cuttable ~= false or not U.String(record.transactionId)
            or not U.String(record.renderedText) then return U.Fail("STATE_INVALID", path, "非法直接回信归档") end
        local fragments = idArray(record.fragmentIds, path .. ".fragmentIds")
        if not fragments.ok then return fragments end
        for _, id in ipairs(record.fragmentIds) do
            if not content.GetFragment(id) then return U.Fail("UNKNOWN_ID", path .. ".fragmentIds", "未知回信片段") end
        end
        local rating = record.rating
        fields = U.Keys(rating, {stars=true,feedback=true,ruleId=true,factIds=true}, path .. ".rating")
        if not fields.ok then return fields end
        if not U.Integer(rating.stars,1) or rating.stars > 3 or not U.String(rating.feedback) or not U.String(rating.ruleId) then
            return U.Fail("STATE_INVALID", path .. ".rating", "非法已保存评分")
        end
        return idArray(rating.factIds, path .. ".rating.factIds")
    end
    function api.ValidateSnapshot(s)
        local valid = U.Validate(s)
        if not valid.ok then return valid end
        valid = U.Keys(s, {byId=true,bottleQueue=true,directArchive=true}, "letters")
        if not valid.ok then return valid end
        if type(s.byId) ~= "table" or type(s.directArchive) ~= "table" then return U.Fail("STATE_INVALID", "letters", "缺少信件实例或归档对象") end
        valid = idArray(s.bottleQueue, "letters.bottleQueue")
        if not valid.ok then return valid end
        for id, item in pairs(s.byId) do
            valid = U.Keys(item, {letterId=true,senderId=true,received=true,read=true,cutSpans=true,claimedAttachmentIds=true}, "letters.byId." .. tostring(id))
            if not valid.ok then return valid end
            local found = definition(item.letterId)
            if not found.ok then return found end
            local d = found.value
            if id ~= "letter:" .. d.id or d.kind ~= "order" or item.senderId ~= d.senderId or not content.GetNpc(item.senderId)
                or item.received ~= true or type(item.read) ~= "boolean" or type(item.cutSpans) ~= "table" then
                return U.Fail("STATE_INVALID", "letters.byId." .. tostring(id), "非法收到状态、来源或实例 ID")
            end
            local parsed = api.ParseDefinition(d.id)
            if not parsed.ok then return parsed end
            local allowed = {}
            for _, span in ipairs(parsed.value.spans) do allowed[span.spanId] = true end
            for spanId, cut in pairs(item.cutSpans) do
                if not allowed[spanId] or cut ~= true or not item.read then return U.Fail("STATE_INVALID", "letters.cutSpans", "位置无效或未读便剪裁") end
            end
            valid = idArray(item.claimedAttachmentIds, "letters.claimedAttachmentIds")
            if not valid.ok then return valid end
            for _, attachmentId in ipairs(item.claimedAttachmentIds) do
                local known = false
                for _, attachment in ipairs(d.attachments or {}) do if attachment.id == attachmentId then known = true end end
                if not known then return U.Fail("UNKNOWN_ID", "letters.claimedAttachmentIds", "附件不属于本信") end
            end
        end
        for _, id in ipairs(s.bottleQueue) do if not s.byId[id] then return U.Fail("STATE_INVALID", "letters.bottleQueue", "队列中的信件不存在") end end
        for id, record in pairs(s.directArchive) do
            if not U.String(id) then return U.Fail("STATE_INVALID", "letters.directArchive", "订单 ID 非法") end
            valid = archiveValid(record, "letters.directArchive." .. id)
            if not valid.ok then return valid end
        end
        return U.Ok(U.Copy(s))
    end
    function api.Restore(s)
        local valid = api.ValidateSnapshot(s)
        if valid.ok then state = U.Copy(valid.value) end
        return valid
    end
    function api.GetSnapshot() return state and U.Copy(state) or nil end
    function api.PlanReceive(s, letterId)
        local valid = api.ValidateSnapshot(s)
        if not valid.ok then return valid end
        local parsed = api.ParseDefinition(letterId)
        if not parsed.ok then return parsed end
        if parsed.value.kind ~= "order" then return U.Fail("INVALID_REQUEST", "letterId", "直接回信不能进入打捞队列") end
        local id, candidate = "letter:" .. letterId, valid.value
        if candidate.byId[id] then return U.Ok({state=candidate,instanceId=id,changed=false}) end
        local d = content.GetLetter(letterId)
        if not U.String(d.senderId) or not content.GetNpc(d.senderId) then return U.Fail("UNKNOWN_ID","letters." .. letterId .. ".senderId","未知寄信人") end
        candidate.byId[id] = {letterId=letterId,senderId=d.senderId,received=true,read=false,cutSpans={},claimedAttachmentIds={}}
        candidate.bottleQueue[#candidate.bottleQueue+1] = id
        return U.Ok({state=candidate,instanceId=id,changed=true})
    end
    function api.PlanMarkRead(s, id)
        local valid = api.ValidateSnapshot(s)
        if not valid.ok then return valid end
        local item = valid.value.byId[id]
        if not item then return U.Fail("LETTER_NOT_RECEIVED", "letterInstanceId", "尚未收到这封信") end
        local changed = not item.read
        item.read = true
        return U.Ok({state=valid.value,instanceId=id,changed=changed})
    end
    -- 公开纯来源查询；仅从真实收到/已读的定义位置推导来源，不接受 UI 自报 word/NPC。
    function api.ResolveSource(s, id, spanId)
        local valid = api.ValidateSnapshot(s)
        if not valid.ok then return valid end
        local item = valid.value.byId[id]
        if not item then return U.Fail("LETTER_NOT_RECEIVED", "letterInstanceId", "尚未收到这封信") end
        if not item.read then return U.Fail("LETTER_NOT_READ", "letterInstanceId", "请先阅读信件") end
        local parsed = api.ParseDefinition(item.letterId)
        if not parsed.ok then return parsed end
        if not parsed.value.cuttable then return U.Fail("LETTER_NOT_CUTTABLE", "letterInstanceId", "该信不可剪") end
        for _, span in ipairs(parsed.value.spans) do
            if span.spanId == spanId then return U.Ok({wordId=span.wordId,sourceLetterInstanceId=id,sourceSpanId=spanId,sourceNpcId=item.senderId}) end
        end
        return U.Fail("UNKNOWN_ID", "spanId", "未知剪裁位置")
    end
    function api.PlanMarkCut(s, id, spanId)
        local source = api.ResolveSource(s, id, spanId)
        if not source.ok then return source end
        local candidate = U.Copy(s)
        local changed = candidate.byId[id].cutSpans[spanId] ~= true
        candidate.byId[id].cutSpans[spanId] = true
        return U.Ok({state=candidate,instanceId=id,source=source.value,changed=changed})
    end
    function api.GetView(id)
        if not state then return U.Fail("STATE_NOT_READY", "letters", "信件状态尚未恢复") end
        local item = state.byId[id]
        if not item then
            local archive = state.directArchive[id]
            if not archive then return U.Fail("LETTER_NOT_RECEIVED", "letterInstanceId", "尚未收到这封信") end
            return U.Ok({orderId=id,kind="direct_followup",cuttable=false,archive=U.Copy(archive)})
        end
        local parsed = api.ParseDefinition(item.letterId)
        if not parsed.ok then return parsed end
        local view = parsed.value
        view.instanceId, view.received, view.read = id, item.received, item.read
        view.claimedAttachmentIds = U.Copy(item.claimedAttachmentIds)
        for _, list in ipairs({view.segments,view.spans}) do
            for _, span in ipairs(list) do
                if span.kind == "word" then span.cut = item.cutSpans[span.spanId] == true; span.canCut = item.read and not span.cut end
            end
        end
        return U.Ok(view)
    end
    -- followup 请求带 orderId；只投影 B0 归档字段，不确认订单，不移除瓶子队列。
    function api.PlanArchive(s, followup)
        local valid = api.ValidateSnapshot(s)
        if not valid.ok then return valid end
        local fields = U.Keys(followup, {orderId=true,transactionId=true,letterId=true,renderedText=true,fragmentIds=true,rating=true,bindings=true}, "followup")
        if not fields.ok then return fields end
        local pure = U.Validate(followup)
        if not pure.ok then return pure end
        if not U.String(followup.orderId) then return U.Fail("INVALID_REQUEST", "followup.orderId", "缺少订单 ID") end
        local record = {transactionId=followup.transactionId,letterId=followup.letterId,renderedText=followup.renderedText,fragmentIds=followup.fragmentIds,rating=followup.rating}
        local checked = archiveValid(record, "followup")
        if not checked.ok then return checked end
        local old = valid.value.directArchive[followup.orderId]
        if old and not U.Equal(old,record) then return U.Fail("ARCHIVE_CONFLICT", "followup.orderId", "该订单已归档不同事务或结果") end
        valid.value.directArchive[followup.orderId] = U.Copy(record)
        return U.Ok({state=valid.value,orderId=followup.orderId,changed=old == nil})
    end
    return api
end
return Letter
