-- 生产装配：所有业务块均为真实模块，无 B1/B2 夹具或内存替身。
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local Session={}
function Session.New(content,options)
    options=options or {}
    local schema=options.targetSchema or 3
    local limit=(content.gameplay or require("data.gameplay")).salvageDailyLimit
    local flow=(schema==3 or schema==4) and require("core.GameFlow").New(limit) or options.gameFlow or require "core.GameFlow"
    local save=options.saveSystem or require "core.SaveSystem"
    local bus=options.eventBus or require "core.EventBus"
    ---@type table<string, table>
    local modules={gameFlow=flow,letters=require("systems.Letter").New(content),wordTokens=require("systems.WordToken").New(content),
        economy=require("systems.Economy").New(content),world=require("systems.WorldState").New(content),narrative=require("systems.Narrative").New(content),orders=require("systems.Order").New(content,{schema4Projection=schema==4})}
    if (schema==3 or schema==4) then modules.orders=require("systems.OrderTrial").Wrap(modules.orders,content,limit,schema) end
    modules.currentOrder=modules.orders.CurrentOrder
    local initial=G.Run(function()
        local live={gameFlow=G.Value(flow.ValidateSnapshot(nil))}
        for _,name in ipairs({"letters","wordTokens","economy","world","narrative","orders"}) do live[name]=G.Value(modules[name].InitialSnapshot()) end
        local data={contentVersion=content.contentVersion,revision=0,nextOrderSerial=1,live=live,currentOrder=false}
        if (schema==3 or schema==4) then data.journal=require("systems.BrewJournal").Empty() end
        if schema==4 then
            data.live.economy.ownedFurnitureIds=nil;data.live.economy.furniturePurchases=nil;data.live.economy.itemPurchases={}
            data.chapter=require("systems.ReleaseLedger").EmptyChapter()
        end
        return G.Value(modules.orders.ValidateEnvelope(data))
    end)
    local ready=options.dataReady~=false and initial.ok
    local state=require("core.GameState").New({gameFlow=flow,saveSystem=save,eventBus=bus,targetSchema=schema,content=content,salvageDailyLimit=limit,
        dataReady=ready,dataError=options.dataError or initial.error,contentVersion=content.contentVersion,synthesisVersion=content.synthesis.version,
        economy=modules.economy,shopEnabled=content.shop~=nil,furnitureEnabled=content.furniture~=nil,letters=modules.letters,wordTokens=modules.wordTokens,narrative=modules.narrative,
        order=modules.orders,adapters=modules,initialState=initial.value})
    modules.orders.BindCoordinator(state)
    local session={state=state,order=modules.orders,modules=modules,initial=initial.ok and U.Copy(initial.value) or nil,ready=ready}
    session.queries=require("systems.PlayQueries").New(session,content)
    return session
end
return Session
