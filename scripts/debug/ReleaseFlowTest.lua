-- 复用实际58锅、试做/重置/确认/重读及完整11单，对新结构运行同样的业务断言。
local T={}
function T.Run() return require("debug.NumericV02FlowTest").RunSchema(4) end
return T
