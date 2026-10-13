-- 生产装配：所有业务块均为真实模块，无 B1/B2 夹具或内存替身。
local U=require "v035.core.StateUtil"
local G=require "v035.systems.CalculationGuard"
local Session={}
function Session.New(content,options)
    options=options or {}
    local schema=options.targetSchema or 3
    local limit=(content.gameplay or require("v035.data.gameplay")).salvageDailyLimit
    local flow=schema==3 and require("v035.core.GameFlow").New(limit) or options.gameFlow or require "v035.core.GameFlow"
    local save=options.saveSystem or require "v035.core.SaveSystem"
    local bus=options.eventBus or require "v035.core.EventBus"
    ---@type table<string, table>
    local modules={gameFlow=flow,letters=require("v035.systems.Letter").New(content),wordTokens=require("v035.systems.WordToken").New(content),
        economy=require("v035.systems.Economy").New(content),world=require("v035.systems.WorldState").New(content),narrative=require("v035.systems.Narrative").New(content),orders=require("v035.systems.Order").New(content)}
    if schema==3 then modules.orders=require("v035.systems.OrderTrial").Wrap(modules.orders,content,limit) end
    modules.currentOrder=modules.orders.CurrentOrder
    local initial=G.Run(function()
        local live={gameFlow=G.Value(flow.ValidateSnapshot(nil))}
        for _,name in ipairs({"letters","wordTokens","economy","world","narrative","orders"}) do live[name]=G.Value(modules[name].InitialSnapshot()) end
        local data={contentVersion=content.contentVersion,revision=0,nextOrderSerial=1,live=live,currentOrder=false}
        if schema==3 then data.journal=require("v035.systems.BrewJournal").Empty() end
        return G.Value(modules.orders.ValidateEnvelope(data))
    end)
    local ready=options.dataReady~=false and initial.ok
    local state=require("v035.core.GameState").New({gameFlow=flow,saveSystem=save,eventBus=bus,targetSchema=schema,content=content,salvageDailyLimit=limit,
        dataReady=ready,dataError=options.dataError or initial.error,contentVersion=content.contentVersion,synthesisVersion=content.synthesis.version,
        economy=modules.economy,shopEnabled=content.shop~=nil,letters=modules.letters,wordTokens=modules.wordTokens,narrative=modules.narrative,
        order=modules.orders,adapters=modules,initialState=initial.value})
    modules.orders.BindCoordinator(state)
    local session={state=state,order=modules.orders,modules=modules,initial=initial.ok and U.Copy(initial.value) or nil,ready=ready}
    session.queries=require("v035.systems.PlayQueries").New(session,content)
    return session
end
return Session
