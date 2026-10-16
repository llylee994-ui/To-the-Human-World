-- Display-only feedback. Persistence and currency awards are never performed here.
local M={}
local function clamp(t) return math.max(0,math.min(1,t)) end
function M.New()
    local s={record=false --[[@as table|false]],reward=false --[[@as table|false]],value=false --[[@as number|false]],seenRecords={},seenRewards={}}
    function s.Record(id,isNew)
        if s.seenRecords[id] then return false end
        s.seenRecords[id]=true;s.record={id=id,isNew=isNew,started=false,time=0,duration=1.1};return true
    end
    function s.StartRecord(source,target)
        if not s.record or s.record.started then return end
        s.record.started=true;s.record.source=source;s.record.target=target;s.record.time=-.25
    end
    function s.Reward(id,before,after,source,target)
        if after<=before or s.seenRewards[id] then return false end
        s.seenRewards[id]=true;s.value=before
        s.reward={id=id,started=true,before=before,after=after,amount=after-before,source=source,target=target,time=0,duration=.9}
        return true
    end
    function s.Cancel(actual)
        s.record=false;s.reward=false
        if actual~=nil then s.value=actual end
    end
    function s.Currency(actual)
        if s.reward and actual~=s.reward.after then s.Cancel(actual) end
        if not s.reward then s.value=actual end
        return s.value or actual
    end
    function s.Update(dt)
        if dt<0 or dt>.5 then s.Cancel();return end
        if s.record and s.record.started then
            s.record.time=s.record.time+dt
            if s.record.time>s.record.duration+1.2 then s.record=false end
        end
        if s.reward then
            local r=s.reward;r.time=r.time+dt
            local t=clamp((r.time-r.duration)/.5);t=1-(1-t)^3
            s.value=math.floor(r.before+(r.after-r.before)*t+.5)
            if r.time>r.duration+1.1 then s.value=r.after;s.reward=false end
        end
    end
    function s.Sample(event,offset)
        if not event or not event.started then return nil end
        local t=(event.time-(offset or 0))/event.duration
        if t<0 or t>1 then return nil end
        t=t*t*(3-2*t)
        local a,b=event.source,event.target
        local cx=(a.x+b.x)/2;local cy=math.min(a.y,b.y)-math.max(60,math.abs(a.x-b.x)*.14)
        return {x=(1-t)^2*a.x+2*(1-t)*t*cx+t*t*b.x,y=(1-t)^2*a.y+2*(1-t)*t*cy+t*t*b.y}
    end
    return s
end
return M
