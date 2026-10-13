-- Merchant counter. Display selection never mutates a business snapshot.
local UI=require "urhox-libs/UI"
local Harbor=require "ui.landscape.HarborStyle"
local Art=require "ui.landscape.IngredientArt"
local Ticket=require "ui.landscape.TravelTicket"
local TicketView=require "ui.landscape.TravelTicketView"
---@alias ShopDisplayItem {ingredientId:string,name:string,price:number,remainingToday:number,ownedQuantity:number,ticket?:TravelTicketQuote}
local S={}
local function text(parent,value,size,id,color)
    local label=UI.Label {id=id,text=tostring(value or ""),fontSize=size or 16,fontColor=color or {65,46,28,255},
        whiteSpace="normal",lineHeight=1.45,flexShrink=0,pointerEvents="none",alignSelf="stretch"}
    parent:AddChild(label);return label
end
local function reason(view,item)
    if not view.enabled then return view.message and view.message~="" and view.message or "请先处理当前试做结果，再来采购。" end
    if item.remainingToday<=0 then return "今日已售完，明天再来看看。" end
    if view.currency<item.price then return "金币不足，可先看看其他原料。" end
    return ""
end
local function scroll(parent,id,padding)
    local area=UI.ScrollView {id=id,width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,scrollY=true,showScrollbar=true}
    local body=UI.Panel {width="100%",flexShrink=0,padding=padding or 12,gap=10,pointerEvents="box-none"}
    area:AddChild(body);parent:AddChild(area);return body
end
function S.Render(ctx,overlay)
    local height=720 --[[@as number]]
    local viewport=rawget(UI,"GetViewportSize") --[[@as function?]]
    if viewport then local _,h=viewport();height=h end
    local safe=ctx.safeInsets or {left=0,top=0,right=0,bottom=0}
    height=height-safe.top-safe.bottom
    local compact=height<540
    local pad=compact and 12 or 24
    local panel=UI.Panel {id="activePanel",position="absolute",left=0,top=0,width="100%",height="100%",
        backgroundImage=Art.Background,backgroundFit="cover",backgroundColor={72,46,28,255},overflow="hidden",onClick=function() end}
    overlay:AddChild(panel)
    local header=UI.Panel {id="panelHeader",width="100%",minHeight=64+safe.top,flexShrink=0,
        paddingTop=8+safe.top,paddingBottom=8,paddingLeft=pad+safe.left,paddingRight=pad+safe.right,gap=10,
        flexDirection="row",alignItems="center",pointerEvents="box-none"}
    ctx.panelHeader=header;panel:AddChild(header)
    header:AddChild(Harbor.Tag {text="商队商店",fontSize=compact and 20 or 24,padding={8,18}})
    header:AddChild(UI.Panel {flexGrow=1,pointerEvents="none"})
    local wallet=Harbor.Tag {id="shopBalance",text="",fontSize=16,padding={8,14}}
    header:AddChild(wallet)
    header:AddChild(Harbor.Button {id="closePanel",text="关闭",minHeight=48,width=84,onClick=ctx.Close})
    local messageArea=UI.ScrollView {id="shopMessageArea",width="100%",height=48,flexShrink=0,scrollY=true,
        visible=false,paddingHorizontal=pad,pointerEvents="box-none",backgroundColor={247,232,204,245}}
    local message=text(messageArea,ctx.model.message,14,"panelMessage",{108,53,30,255})
    panel:AddChild(messageArea);ctx.panelNotice=message;ctx.panelNoticeArea=messageArea
    local result=ctx.session.queries.GetShopView()
    if not result.ok then
        local errorBody=Harbor.Paper {margin=pad,padding=20,gap=12}
        panel:AddChild(errorBody);text(errorBody,result.error.message,18,"shopQueryError");return
    end
    local view=result.value;wallet:SetText("金币 "..view.currency)
    local ticketResult=Ticket.Get(ctx)
    ---@type ShopDisplayItem[]
    local items={}
    for _,item in ipairs(view.items) do items[#items+1]=item end
    if ticketResult.ok then
        local q=ticketResult.value --[[@as TravelTicketQuote]]
        items[#items+1]={ingredientId=q.itemId,name=q.name,price=q.price,remainingToday=1,ownedQuantity=0,ticket=q}
    end
    if #view.items==0 then
        local empty=Harbor.Paper {margin=pad,padding=20}
        panel:AddChild(empty);text(empty,"商队目前没有可出售的原料。",18,"shopEmpty")
    end
    if not ticketResult.ok then
        local errorBody=Harbor.Paper {marginHorizontal=pad,padding=8}
        panel:AddChild(errorBody);text(errorBody,ticketResult.error.message,14,"ticketQueryError")
    end
    if #items==0 then return end
    local rows=math.ceil(#items/2)
    local itemHeight=math.min(compact and 134 or 264,math.max(compact and 104 or 150,(height-180)/rows))
    local selected=assert(items[1])
    for _,item in ipairs(items) do if item.ingredientId==ctx.shopSelectedId then selected=item;break end end
    ctx.shopSelectedId=selected.ingredientId
    local content=UI.Panel {id="shopContent",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,
        flexDirection="row",paddingTop=compact and 4 or 16,paddingLeft=pad+safe.left,paddingRight=pad+safe.right,
        paddingBottom=pad+safe.bottom,gap=compact and 12 or 24,pointerEvents="box-none"}
    panel:AddChild(content)
    local goods=UI.Panel {id="shopGoods",flexGrow=3,flexShrink=1,flexBasis=0,minWidth=0,gap=8,pointerEvents="box-none"}
    content:AddChild(goods)
    goods:AddChild(Harbor.Tag {text="商队货品 · 原料每日补货",alignSelf="flex-start",fontSize=14,padding={5,12}})
    local gallery=scroll(goods,"shopGoodsScroll",0)
    local row=UI.Panel {width="100%",flexDirection="row",gap=12,pointerEvents="box-none"}
    gallery:AddChild(row)
    for index,item in ipairs(items) do
        if index>1 and index%2==1 then
            row=UI.Panel {width="100%",flexDirection="row",gap=12,pointerEvents="box-none"};gallery:AddChild(row)
        end
        local chosen=item.ingredientId==selected.ingredientId
        local card=UI.Panel {id="shop_select_"..item.ingredientId,flexGrow=1,flexShrink=1,flexBasis=0,minWidth=0,
            height=itemHeight,padding=8,gap=4,alignItems="center",justifyContent="center",borderRadius=6,
            borderWidth=chosen and 2 or 1,borderColor=chosen and {237,204,139,255} or {195,155,94,130},
            backgroundColor=chosen and {126,84,45,165} or {53,34,21,100},
            onClick=function() ctx.shopSelectedId=item.ingredientId;ctx.model.dirty=true end}
        row:AddChild(card)
        if item.ticket then
            card:AddChild(UI.Panel {id="shopArt_"..item.ingredientId,width="100%",height=itemHeight-65,
                backgroundImage=Ticket.image,backgroundFit="contain",pointerEvents="none"})
        else
            card:AddChild(Art.Panel(item.ingredientId,{id="shopArt_"..item.ingredientId,width="100%",height=itemHeight-65,
                imageTint=item.remainingToday<=0 and {160,160,160,255} or nil}))
        end
        card:AddChild(Harbor.Tag {text=item.name.." · "..item.price.." 金币",fontSize=compact and 14 or 16,minHeight=30,padding={3,9}})
        text(card,item.ticket and Ticket.Expiry(item.ticket) or (item.remainingToday>0 and "余 "..item.remainingToday.." 份" or "今日售完"),12,nil,{250,231,192,255})
    end
    local detail=Harbor.Paper {id="shopDetail",flexGrow=2,flexShrink=1,flexBasis=0,minWidth=0,padding=0,
        backgroundColor={242,226,195,250},borderWidth=1,borderColor={175,132,70,255},overflow="hidden"}
    content:AddChild(detail)
    local body=scroll(detail,"shopDetailScroll")
    if selected.ticket then
        body:AddChild(UI.Panel {id="shopSelectedArt",width="100%",height=compact and 74 or 164,
            backgroundImage=Ticket.image,backgroundFit="contain",pointerEvents="none"})
    else body:AddChild(Art.Panel(selected.ingredientId,{id="shopSelectedArt",width="100%",height=compact and 74 or 164})) end
    text(body,selected.name,compact and 22 or 28,"shopItemName")
    local definition=not selected.ticket and ctx.content.GetIngredient(selected.ingredientId)
    text(body,selected.ticket and "前往人间的单程船票。确认购买后将离开魔药铺，结束本次旅程。" or (definition and definition.desc or ""),compact and 14 or 16,"shopItemDescription")
    body:AddChild(UI.Panel {height=1,width="100%",backgroundColor={161,125,76,110},pointerEvents="none"})
    text(body,(selected.ticket and "票价 " or "每份 ")..selected.price.." 金币",18,"shopItemPrice")
    if selected.ticket then
        text(body,Ticket.Expiry(selected.ticket),16,"ticketExpiry")
        text(body,"可购买至第 "..selected.ticket.lastPurchaseDay.." 天结束",15,"ticketLastDay")
    else
        text(body,"已有 "..selected.ownedQuantity.." 份",16,"shopItemOwned")
        text(body,"今日余量 "..selected.remainingToday.." 份",16,"shopItemStock")
    end
    -- Fixed purchase footer stays reachable even when the description scrolls.
    local footer=UI.Panel {width="100%",flexShrink=0,padding=12,gap=6,pointerEvents="box-none"}
    detail:AddChild(footer)
    local blocked=selected.ticket and selected.ticket.message or reason(view,selected)
    local explanation=text(footer,blocked,13,"shopItemReason",{115,60,31,255})
    explanation:SetVisible(blocked~="")
    footer:AddChild(Harbor.Button {id="buy_"..selected.ingredientId,text=(selected.ticket and "购买船票 · " or "购买一份 · ")..selected.price.." 金币",
        width="100%",minHeight=48,fontSize=compact and 14 or 16,disabled=blocked~="",onClick=function()
            if selected.ticket then
                local current=Ticket.Get(ctx)
                if not current.ok then ctx.model.Notify(current)
                elseif not current.value.enabled then ctx.model.Notify({ok=false,error={code=current.value.reasonCode,message=current.value.message}})
                else ctx.ticketConfirm=true;ctx.model.dirty=true end
            else ctx.model.Buy(selected.ingredientId) end
        end})
    if ctx.ticketConfirm then TicketView.Confirm(ctx,overlay) end
end
return S
