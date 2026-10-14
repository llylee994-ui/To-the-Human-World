local UI=require "urhox-libs/UI"
local Harbor=require "ui.landscape.HarborStyle"
local Ticket=require "ui.landscape.TravelTicket"
local U=require "core.StateUtil"
local V={}
local function label(parent,text,id,size)
    local control=UI.Label {id=id,text=text,fontSize=size or 17,fontFamily=Harbor.fontFamily,fontColor={65,46,28,255},whiteSpace="normal",
        lineHeight=1.5,flexShrink=0,pointerEvents="none",alignSelf="stretch"}
    parent:AddChild(control);return control
end
function V.Confirm(ctx,overlay)
    overlay:AddChild(UI.Panel {id="ticketConfirmBlocker",position="absolute",left=0,top=0,width="100%",height="100%",
        backgroundColor={20,16,12,205},onClick=function() end})
    local panel=Harbor.Paper {id="ticketConfirmPanel",position="absolute",left="18%",top="8%",width="64%",height="84%",
        padding=12,gap=8,overflow="hidden",onClick=function() end}
    overlay:AddChild(panel)
    local header=UI.Panel {id="panelHeader",width="100%",flexDirection="row",alignItems="center",gap=8,minHeight=44,pointerEvents="box-none"}
    ctx.panelHeader=header;panel:AddChild(header)
    header:AddChild(UI.Label {text="购买并启程",fontSize=21,fontFamily=Harbor.fontFamily,flexGrow=1,fontColor={65,46,28,255},pointerEvents="none"})
    header:AddChild(Harbor.Button {id="closeTicketConfirm",text="返回",minHeight=44,width=72,onClick=function() ctx.ticketConfirm=false;ctx.ticketQuote=false;ctx.model.dirty=true end})
    local messageArea=UI.ScrollView {width="100%",height=48,flexShrink=0,scrollY=true,visible=false}
    ctx.panelNotice=label(messageArea,ctx.model.message,"panelMessage",14);ctx.panelNoticeArea=messageArea;panel:AddChild(messageArea)
    local scroll=UI.ScrollView {id="ticketConfirmScroll",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,scrollY=true,showScrollbar=true}
    local body=UI.Panel {width="100%",flexShrink=0,gap=10,paddingRight=8,pointerEvents="box-none"}
    scroll:AddChild(body);panel:AddChild(scroll)
    label(body,"购买这张船票后，你将离开魔药铺，直接进入结局。本次旅程将结束。是否购买并启程？","ticketConfirmText",18)
    local quote=Ticket.Get(ctx)
    local canConfirm=false
    if quote.ok then
        local q=quote.value
        ctx.ticketQuote=U.Copy(q)
        label(body,"人间单程船票 · "..q.price.." 金币","ticketConfirmPrice",18)
        label(body,Ticket.Expiry(q),"ticketExpiry",15)
        canConfirm=q.canDepart
        if not q.enabled then label(body,q.message,"ticketConfirmReason",15)
        elseif not q.canDepart then label(body,"这趟航程尚未开放。船票规则已确定，请稍后再来。","ticketUnavailable",15) end
    else ctx.ticketQuote=false;label(body,quote.error.message,"ticketQueryError",15) end
    -- Fixed footer keeps both decisions reachable on a short landscape viewport.
    local footer=UI.Panel {width="100%",flexShrink=0,flexDirection="row",gap=10,pointerEvents="box-none"}
    panel:AddChild(footer)
    footer:AddChild(Harbor.Button {id="cancelTravelTicket",text="再想想",flexGrow=1,flexShrink=1,flexBasis=0,minWidth=0,minHeight=48,
        onClick=function() ctx.ticketConfirm=false;ctx.ticketQuote=false;ctx.model.dirty=true end})
    footer:AddChild(Harbor.Button {id="confirmTravelTicket",text="购买并启程",flexGrow=1,flexShrink=1,flexBasis=0,minWidth=0,minHeight=48,
        disabled=not canConfirm,onClick=function()
            local result=Ticket.Purchase(ctx)
            ctx.model.Notify(result)
            if result.ok then
                local value=result.value
                if value and value.departed==true and type(value.ending)=="table" and U.String(value.ending.title) and U.String(value.ending.text) then
                    ctx.ticketConfirm=false
                    if rawget(ctx.session.queries,"GetEndingView") then ctx.Open("ending")
                    else ctx.ticketEnding=U.Copy(value.ending);ctx.Open("ticketEnding") end
                else ctx.model.Notify(U.Fail("TICKET_RESULT_INVALID","ticket","启程结果需要核对，请重新读取进度。")) end
            end
        end})
end
function V.Ending(ctx,overlay)
    local safe=ctx.safeInsets or {left=0,top=0,right=0,bottom=0}
    local panel=Harbor.Paper {id="activePanel",position="absolute",left=0,top=0,width="100%",height="100%",
        paddingLeft=24+safe.left,paddingRight=24+safe.right,paddingTop=96+safe.top,paddingBottom=24+safe.bottom,
        gap=16,overflow="hidden",onClick=function() end}
    overlay:AddChild(panel)
    local scroll=UI.ScrollView {width="100%",flexGrow=1,flexShrink=1,flexBasis=0,scrollY=true,showScrollbar=true}
    local body=UI.Panel {width="100%",flexShrink=0,padding=12,gap=20,pointerEvents="box-none"}
    scroll:AddChild(body);panel:AddChild(scroll)
    label(body,ctx.ticketEnding.title,"travelEndingTitle",26)
    label(body,ctx.ticketEnding.text,"travelEndingText",19)
end
return V
