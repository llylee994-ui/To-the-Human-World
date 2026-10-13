local F={}
function F.New()
    local samples,total={},0
    local api={}
    function api.Add(dt)
        if type(dt)~="number" or dt~=dt or dt<=0 or dt==math.huge then return end
        samples[#samples+1]=dt;total=total+dt
    end
    function api.Report(reset)
        local n=#samples;if n==0 then return {frames=0} end
        local ordered={};for i,x in ipairs(samples) do ordered[i]=x end;table.sort(ordered)
        local r={frames=n,seconds=total,meanFrameMs=1000*total/n,p95FrameMs=1000*ordered[math.ceil(n*.95)],worstFrameMs=1000*ordered[n],
            updateFps=n/total,source="Update TimeStep, not GPU profiler"}
        if reset then samples={};total=0 end
        return r
    end
    return api
end
return F
