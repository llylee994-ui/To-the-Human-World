-- Exports actual ShopView widget props. Browser replay is NOT native Yoga/NanoVG.
local UI=require "urhox-libs/UI"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local Model=require "ui.PlayModel"
local Shop=require "ui.landscape.ShopView"
local U=require "core.StateUtil"
local T={}
function T.Run()
    local ticketMode=rawget(_G,"TRAVEL_TICKET_EVIDENCE")
    local content=U.Copy(Data)
    if ticketMode then content.stage1.initialEconomy.currency=666 end -- isolated review fixture, not player funds
    local x=F.New(content,{targetSchema=3})
    local model=Model.New(x.session,content)
    local variants={};for _,item in ipairs(Data.ingredients) do variants[#variants+1]={id=item.id} end
    if ticketMode then variants[#variants+1]={id="travel_ticket"};variants[#variants+1]={id="travel_ticket",confirm=true,captureId="travel_ticket_confirm"} end
    for _,size in ipairs({{1280,720},{1600,720},{1024,768},{800,360}}) do
        local scale=math.max(.625,math.min(1,math.sqrt(math.min(size[1],size[2])/720)))
        rawset(UI,"GetViewportSize",function() return size[1]/scale,size[2]/scale end)
        for _,item in ipairs(variants) do
            local root=UI.Panel {width="100%",height="100%",pointerEvents="box-none"}
            local ctx={session=x.session,content=content,model=model,shopSelectedId=item.id,ticketConfirm=item.confirm,Close=function() end}
            Shop.Render(ctx,root)
            local capture=rawget(_G,"SHOP_EVIDENCE")
            if capture then capture(size[1],size[2],scale,item.captureId or item.id,root) end
        end
    end
    print("[ShopEvidence] exported "..(#variants*4).." actual widget trees; CSS replay only, isolated review balance")
    return true
end
return T
