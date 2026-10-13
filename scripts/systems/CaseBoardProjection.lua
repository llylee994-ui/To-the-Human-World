-- 主线案件映射尚未接入；不从试做回信、星级或重置记录推断线索。
local U=require "core.StateUtil"
local C={}
function C.Get(_data,_content) return U.Ok({availability="unopened",nodes={},edges={}}) end
return C
