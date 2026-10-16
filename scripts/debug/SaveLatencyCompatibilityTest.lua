local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local T={}
function T.Run()
    local check,done=R.Checks("SaveLatencyCompatibility")
    check("exact JSON numbers, placeholders and escape compatibility",function() require("debug.SaveJsonTest").Run() end)
    check("long prose, every byte remainder and B1 digest match the original algorithm",function()
        local files={}
        local save=require("core.SaveSystem").New({exists=function(p)return files[p]~=nil end,read=function(p)return files[p]end,
            write=function(p,s)files[p]=s;return true end,delete=function(p)files[p]=nil;return true end})
        local function oldDigest(raw)
            local n=0;for i=1,#raw do n=(n*31+raw:byte(i))%4294967291 end;return string.format("%.0f",n)
        end
        for i=0,16 do
            local text=string.rep('海边的信\\与"引号"\n',i*57)..string.rep('x',i)
            local value={text=text,number=.12345678901234567}
            assert(save.Save("digest",value,1))
            local latest,side=0
            for _,s in ipairs({"a","b"}) do
                local raw=files["save_digest_"..s..".commit"]
                local gen=raw and tonumber(raw:match("^B1|(%d+)|"))
                if gen and gen>latest then latest,side=gen,s end
            end
            local payload=files["save_digest_"..side..".json"]
            local marker=files["save_digest_"..side..".commit"]
            assert(marker=="B1|"..latest.."|"..side.."|"..#payload.."|"..oldDigest(payload).."|END")
            local loaded,status=save.Load("digest");assert(status.status=="loaded" and U.Equal(value,loaded))
        end
    end)
    check("existing dual-snapshot fault and corrupt-marker scenarios",function()
        local save=require "core.SaveSystem";local original={}
        for _,key in ipairs({"EngineStorage","Save","Load","Delete"}) do original[key]=save[key] end
        local files={}
        local io={exists=function(p)return files[p]~=nil end,read=function(p)return assert(files[p])end,
            write=function(p,s)files[p]=s;return true end,delete=function(p)files[p]=nil;return true end}
        save.EngineStorage=function()return io end
        local memory=save.New(io);save.Save=memory.Save;save.Load=memory.Load;save.Delete=memory.Delete
        local ok,err=pcall(function()
            require("debug.SaveSystemTest").RunStorage(function(name,actual,expected)assert(U.Equal(actual,expected),name)end)
        end)
        for key,fn in pairs(original) do save[key]=fn end
        assert(ok,err)
    end)
    return done()
end
return T
