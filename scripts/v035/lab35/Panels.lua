-- Reuse pinned main panels; only confirmation dispatch differs.
local Main=require "v035.ui.landscape.Panels"
local P={};for k,v in pairs(Main) do P[k]=v end
P.Renderers={};for k,v in pairs(Main.Renderers) do P.Renderers[k]=v end
function P.Day(ctx,body)
    local data=ctx.model.Refresh();local action=ctx.model.Action("NextDay")
    local token=ctx.BeginDayConfirmation()
    P.Text(body,"结束第 "..data.live.gameFlow.day.." 天？",22)
    P.Text(body,"确认后进入下一天。订单和投料限制由现有业务规则检查。",16)
    P.Button(body,"confirmNextDay","确认结束当天",function() ctx.ConfirmDay(token) end,action.enabled,action.message)
    P.Button(body,"cancelNextDay","继续今天",ctx.Close)
end
P.Renderers.day=P.Day
return P
