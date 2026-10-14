-- 可由原生 cjson 或明确标注的隔离适配器运行。
local T={}
function T.Run()
    local J=require "core.SaveJson"
    local U=require "core.StateUtil"
    local samples={
        {'"__save_number_1__',0.1*1.5},
        {small=0.1*1.5,other=0.45-0.000000000000000055511151231257827,
            integer=9007199254740991,large=math.maxinteger,negative=math.mininteger},
        {"__save_number_1__","__save_number_2__",'转义"\\ 12.5e-2',false,{},
            {__save_number_3__=0.1*1.5,["中文"]=1e-300}},
    }
    for _,value in ipairs(samples) do assert(U.Equal(J.Decode(J.Encode(value)),value),"lossless roundtrip") end
    assert(J.Decode('{"v":0.44999999999999996}').v==tonumber("0.44999999999999996"),"legacy decimal")
    assert(J.Decode('{"v":"\\u005f_save_number_1__","n":0.15000000000000002}').v=="__save_number_1__","escaped collision")
    for _,raw in ipairs({'{"v":1+2}','{"v":01}','[1,]','{"v":1e}'}) do
        assert(not pcall(J.Decode,raw),"invalid JSON accepted")
    end
    print("[SaveJsonTest] PASS exact numbers, nested values, collisions, escapes, legacy JSON, invalid syntax")
    return true
end
return T
