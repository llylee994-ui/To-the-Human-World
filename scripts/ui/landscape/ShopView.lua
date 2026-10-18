-- Merchant counter. Browsing never mutates a business snapshot.
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local Harbor=require "ui.landscape.HarborStyle"
local Art=require "ui.landscape.IngredientArt"
local Merchandise=require "ui.landscape.MerchandiseArt"
local Ticket=require "ui.landscape.TravelTicket"
---@type {Confirm: fun(ctx: table, overlay: Widget)}
local TicketView=require "ui.landscape.TravelTicketView"
local S={}
local ink,light={65,47,32,255},{249,236,205,255}
local function text(parent,value,size,id,color)
    local label=UI.Label {id=id,text=tostring(value or ""),fontFamily="story",fontSize=size or 16,
        fontColor=color or ink,whiteSpace="normal",lineHeight=1.4,flexShrink=0,pointerEvents="none",alignSelf="stretch"}
    parent:AddChild(label);return label
end
local function scroll(parent,id)
    local area=UI.ScrollView {id=id,width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,scrollY=true,showScrollbar=true}
    local body=UI.Panel {width="100%",flexShrink=0,gap=8,pointerEvents="box-none"}
    area:AddChild(body);parent:AddChild(area);return body
end
local function reason(view,item)
    if not view.enabled then return view.message and view.message~="" and view.message or "请先处理当前试做结果，再来采购。" end
    if item.kind=="furniture" and item.owned then return "这件家具已经购入。" end
    if item.kind=="ingredient" and item.remainingToday<=0 then return "今日已售完，明天再来看看。" end
    if view.currency<item.price then return "金币不足，需要 "..item.price.." 金币。" end
    return ""
end
local function tab(parent,ctx,id,title,selected)
    local button=UI.Button {id="shopTab_"..id,text=title,height=44,width=104,fontFamily="story",fontSize=17,fontWeight="normal",
        backgroundImage=Harbor.paperImage,backgroundFit="fill",backgroundImageOpacity=selected and 1 or .72,
        hoverBackgroundImageOpacity=1,pressedBackgroundImageOpacity=.82,
        backgroundColor={0,0,0,0},hoverBackgroundColor={0,0,0,0},pressedBackgroundColor={0,0,0,0},
        variantBackgroundGradient={},variantHoverBackgroundGradient={},variantPressedBackgroundGradient={},
        borderWidth=0,hoverBorderWidth=0,pressedBorderWidth=0,borderRadius=0,boxShadow=false,glowShadow={},
        textColor=selected and ink or {116,89,63,255},padding={5,12},pressedPadding={5,12},
        onClick=function()
            local changed=ctx.shopCategory~=id or ctx.shopPage~=1
            ctx.shopCategory=id;ctx.shopPage=1;ctx.shopSelectedId=false;ctx.ticketConfirm=false;ctx.model.dirty=true
            if changed and ctx.PlayObjectSound then ctx.PlayObjectSound("ui_click_01") end
        end}
    if selected then button:AddChild(UI.Panel {position="absolute",left=16,right=16,bottom=4,height=2,
        backgroundColor={155,107,57,210},pointerEvents="none"}) end
    parent:AddChild(button)
end
function S.Render(ctx,overlay)
    local height=ctx.viewport and ctx.viewport.h or 720 --[[@as number]]
    local safe=ctx.safeInsets or {left=0,top=0,right=0,bottom=0}
    height=height-safe.top-safe.bottom
    local compact=height<540
    local pad=compact and 14 or 24
    local panel=UI.Panel {id="activePanel",position="absolute",left=0,top=0,width="100%",height="100%",
        backgroundImage=Art.Background,backgroundFit="cover",backgroundColor={72,46,28,255},overflow="hidden",onClick=function() end}
    overlay:AddChild(panel)
    panel:AddChild(UI.Panel {position="absolute",left=0,top=0,width="100%",height="100%",backgroundColor={26,20,14,70},pointerEvents="none"})
    local header=UI.Panel {id="panelHeader",width="100%",minHeight=64+safe.top,flexShrink=0,
        paddingTop=8+safe.top,paddingBottom=8,paddingLeft=pad+safe.left,paddingRight=pad+safe.right,gap=compact and 6 or 12,
        flexDirection="row",alignItems="center",pointerEvents="box-none"}
    ctx.panelHeader=header;panel:AddChild(header)
    local title=text(header,"商队商店",compact and 23 or 27,"shopTitle",light)
    Widget.SetStyle(title,{width=compact and 120 or 180,whiteSpace="nowrap",alignSelf="center",fontSize=compact and 20 or 27})
    header:AddChild(UI.Panel {flexGrow=1,pointerEvents="none"})
    local wallet=text(header,"",17,"shopBalance",light)
    Widget.SetStyle(wallet,{width=compact and 96 or 128,whiteSpace="nowrap",alignSelf="center"})
    header:AddChild(Harbor.Button {id="shopSettings",text="设置",minHeight=48,width=72,onClick=ctx.OpenSettings})
    header:AddChild(Harbor.Button {id="closePanel",text="关闭",minHeight=48,width=84,onClick=ctx.Close})
    local noticeArea=UI.Panel {id="shopMessageArea",position="absolute",left="30%",right="30%",top=safe.top+70,
        minHeight=44,padding={8,14},zIndex=20,backgroundColor={37,29,21,235},borderRadius=8,
        visible=false,pointerEvents="none"}
    ctx.panelNotice=text(noticeArea,ctx.model.message,14,"panelMessage",light);ctx.panelNoticeArea=noticeArea
    panel:AddChild(noticeArea)
    local result=ctx.session.queries.GetShopView()
    if not result.ok then
        local body=Harbor.Paper {margin=pad,padding=20};panel:AddChild(body);text(body,result.error.message,18,"shopQueryError");return
    end
    local ingredientView=result.value;wallet:SetText("金币 "..ingredientView.currency)
    if not ctx.shopCategory then
        local id=ctx.shopSelectedId or ""
        ctx.shopCategory=id=="travel_ticket" and "tickets" or (id:match("^decor_") and "furniture" or "ingredients")
    end
    local category=ctx.shopCategory
    local tabs=UI.Panel {id="shopCategories",width="100%",flexDirection="row",gap=12,flexShrink=0,
        paddingLeft=pad+safe.left,paddingRight=pad+safe.right,paddingBottom=8,pointerEvents="box-none"}
    panel:AddChild(tabs)
    tab(tabs,ctx,"ingredients","原料",category=="ingredients")
    tab(tabs,ctx,"furniture","家具",category=="furniture")
    tab(tabs,ctx,"tickets","船票",category=="tickets")
    local view,items=ingredientView,{}
    local errorMessage,errorId
    if category=="ingredients" then
        for _,item in ipairs(view.items) do
            local row={};for k,v in pairs(item) do row[k]=v end;row.kind="ingredient";items[#items+1]=row
        end
    elseif category=="furniture" then
        local furniture=ctx.session.queries.GetFurnitureShopView()
        if furniture.ok then
            view=furniture.value
            local action=ctx.model.Action("PurchaseFurniture")
            if not action.enabled then view.enabled=false;view.message=action.message end
            for _,item in ipairs(view.items) do
                items[#items+1]={kind="furniture",ingredientId=item.furnitureId,furnitureId=item.furnitureId,name=item.name,price=item.price,owned=item.owned,quote=item.quote}
            end
        else errorMessage,errorId=furniture.error.message,"furnitureQueryError" end
    else
        local offer=Ticket.Get(ctx)
        if offer.ok then local q=offer.value;items[1]={kind="ticket",ingredientId=q.itemId,name=q.name,price=q.price,ticket=q}
        else errorMessage,errorId=offer.error.message,"ticketQueryError" end
    end
    if errorMessage then
        local body=Harbor.Paper {margin=pad,padding=20};panel:AddChild(body);text(body,errorMessage,16,errorId);return
    end
    if #items==0 then
        local body=Harbor.Paper {margin=pad,padding=20};panel:AddChild(body);text(body,"目前没有可出售的商品。",18,"shopEmpty");return
    end
    local availableWidth=(ctx.viewport and ctx.viewport.w or 1280)-safe.left-safe.right
    local perPage=availableWidth<900 and 1 or 2
    if ctx.shopPerPage and ctx.shopPerPage~=perPage then
        for i,item in ipairs(items) do if item.ingredientId==ctx.shopSelectedId then ctx.shopPage=math.ceil(i/perPage) end end
    end
    ctx.shopPerPage=perPage
    local pageCount=math.ceil(#items/perPage)
    local page=math.max(1,math.min(pageCount,math.floor(ctx.shopPage or 1)))
    ctx.shopPage=page
    local first=(page-1)*perPage+1
    local selected=items[first]
    for index=first,math.min(first+perPage-1,#items) do
        local item=items[index];if item.ingredientId==ctx.shopSelectedId then selected=item;break end
    end
    ctx.shopSelectedId=selected.ingredientId
    local content=UI.Panel {id="shopContent",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,
        flexDirection="row",paddingTop=4,paddingLeft=pad+safe.left,paddingRight=pad+safe.right,paddingBottom=pad+safe.bottom,
        gap=compact and 16 or 24,pointerEvents="box-none"}
    panel:AddChild(content)
    local goods=UI.Panel {id="shopGoods",flexGrow=3,flexShrink=1,flexBasis=0,minWidth=0,gap=8,pointerEvents="box-none"}
    content:AddChild(goods)
    text(goods,category=="ingredients" and "原料每日补货" or category=="furniture" and "购入后收存" or "通往人间的单程航程",13,nil,light)
    local gallery=UI.Panel {id="shopGoodsPage",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,
        flexDirection="row",gap=12,pointerEvents="box-none"}
    goods:AddChild(gallery)
    for index=first,math.min(first+perPage-1,#items) do
        local item=items[index]
        local chosen=item.ingredientId==selected.ingredientId
        local card=UI.Panel {id="shop_select_"..item.ingredientId,flexGrow=1,flexShrink=1,flexBasis=0,minWidth=0,
            minHeight=0,padding=height<400 and 4 or 10,gap=3,alignItems="center",borderRadius=6,borderWidth=0,
            flexDirection=height<400 and "row" or "column",
            backgroundColor=chosen and {111,79,48,155} or {34,24,17,95},
            onClick=function()
                local changed=ctx.shopSelectedId~=item.ingredientId
                ctx.shopSelectedId=item.ingredientId;ctx.model.dirty=true
                if changed and ctx.PlayObjectSound then ctx.PlayObjectSound("ui_click_01") end
            end}
        gallery:AddChild(card)
        card:AddChild(Merchandise.Panel(item.ingredientId,height<400 and {id="shopArt_"..item.ingredientId,width=52,height=52,flexShrink=0}
            or {id="shopArt_"..item.ingredientId,width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0}))
        local info=card
        if height<400 then
            local area=UI.ScrollView {id="shopCardScroll_"..item.ingredientId,flexGrow=1,flexShrink=1,flexBasis=0,minWidth=0,height="100%",scrollY=true}
            info=UI.Panel {width="100%",gap=2,flexShrink=0,pointerEvents="box-none"};area:AddChild(info);card:AddChild(area)
        end
        local name=text(info,item.name,16,"shopName_"..item.ingredientId,light);name.props.textAlign="center"
        local price=text(info,item.price.." 金币",13,"shopPrice_"..item.ingredientId,{227,204,155,255});price.props.textAlign="center"
        local status=item.kind=="ticket" and Ticket.Expiry(item.ticket) or item.kind=="furniture" and (item.owned and "已拥有" or "可购入")
            or (item.remainingToday>0 and "余 "..item.remainingToday.." 份" or "今日售完")
        local caption=text(info,status,11,"shopStatus_"..item.ingredientId,{222,207,179,255});caption.props.textAlign="center"
    end
    local pager=UI.Panel {id="shopPager",width="100%",height=48,flexShrink=0,flexDirection="row",gap=12,
        alignItems="center",justifyContent="center",pointerEvents="box-none"}
    goods:AddChild(pager)
    local function turn(delta)
        local target=math.max(1,math.min(pageCount,page+delta))
        local changed=ctx.shopPage~=target
        ctx.shopPage=target;ctx.shopSelectedId=false
        ctx.ticketConfirm=false;ctx.model.dirty=true
        if changed and ctx.PlayObjectSound then ctx.PlayObjectSound("ui_click_01") end
    end
    pager:AddChild(Harbor.Button {id="shopPreviousPage",text=perPage==1 and "‹" or "上一页",width=perPage==1 and 48 or 96,minHeight=44,disabled=page==1,onClick=function() turn(-1) end})
    local pageNumber=text(pager,page.." / "..pageCount,14,"shopPageNumber",light)
    Widget.SetStyle(pageNumber,{width=64,textAlign="center",whiteSpace="nowrap",alignSelf="center"})
    pager:AddChild(Harbor.Button {id="shopNextPage",text=perPage==1 and "›" or "下一页",width=perPage==1 and 48 or 96,minHeight=44,disabled=page==pageCount,onClick=function() turn(1) end})
    local detail=Harbor.Paper {id="shopDetail",flexGrow=2,flexShrink=1,flexBasis=0,minWidth=0,padding=16,paperInset=compact and 16 or 32,overflow="hidden"}
    content:AddChild(detail)
    local body=scroll(detail,"shopDetailScroll")
    body:AddChild(Merchandise.Panel(selected.ingredientId,{id="shopSelectedArt",width="100%",height=compact and 122 or 212}))
    text(body,selected.name,compact and 23 or 28,"shopItemName")
    local description
    if selected.kind=="ticket" then description="前往人间的单程船票。确认购买后将离开魔药铺，结束本次旅程。"
    elseif selected.kind=="furniture" then description="购入后会保存为已拥有，暂不能布置到小屋。"
    else local definition=ctx.content.GetIngredient(selected.ingredientId);description=definition and definition.desc or "" end
    text(body,description,14,"shopItemDescription")
    text(body,(selected.kind=="ticket" and "票价 " or selected.kind=="furniture" and "售价 " or "每份 ")..selected.price.." 金币",17,"shopItemPrice")
    if selected.kind=="ticket" then
        text(body,Ticket.Expiry(selected.ticket),15,"ticketExpiry")
        text(body,"可购买至第 "..selected.ticket.lastPurchaseDay.." 天结束",13,"ticketLastDay")
    elseif selected.kind=="furniture" then text(body,selected.owned and "已拥有" or "尚未拥有",15,"shopItemOwned")
    else text(body,"已有 "..selected.ownedQuantity.." 份",14,"shopItemOwned");text(body,"今日余量 "..selected.remainingToday.." 份",14,"shopItemStock") end
    local footer=UI.Panel {id="shopDetailFooter",width="100%",height=compact and 52 or 118,flexShrink=0,paddingTop=compact and 4 or 12,gap=6,pointerEvents="box-none"}
    detail:AddChild(footer)
    local blocked=selected.kind=="ticket" and selected.ticket.message or reason(view,selected)
    local explanation=text(compact and body or footer,blocked,14,"shopItemReason",{115,60,31,255})
    if compact then explanation:SetVisible(blocked~="")
    else Widget.SetStyle(explanation,{height=52,minHeight=52,overflow="hidden"}) end
    local title=selected.kind=="furniture" and (selected.owned and "已拥有" or "购入 · "..selected.price.." 金币")
        or (selected.kind=="ticket" and "购买船票 · " or "购买一份 · ")..selected.price.." 金币"
    if compact then title=selected.kind=="furniture" and (selected.owned and "已拥有" or "购入家具")
        or (selected.kind=="ticket" and "购买船票" or "购买一份") end
    footer:AddChild(Harbor.Button {id="buy_"..selected.ingredientId,text=title,width="100%",height=48,minHeight=48,fontSize=15,
        disabled=blocked~="",onClick=function()
            if blocked~="" or ctx.panel~="shop" or ctx.ticketConfirm then return end
            if selected.kind=="ticket" then
                local current=Ticket.Get(ctx)
                if not current.ok then ctx.model.Notify(current)
                elseif not current.value.enabled then ctx.model.Notify({ok=false,error={code=current.value.reasonCode,message=current.value.message}})
                else
                    ctx.ticketConfirm=true;ctx.model.dirty=true
                    if ctx.PlayObjectSound then ctx.PlayObjectSound("ui_click_01") end
                end
            else
                ---@type table
                local result
                if selected.kind=="furniture" then result=ctx.model.BuyFurniture(selected.furnitureId,selected.quote)
                else result=ctx.model.Buy(selected.ingredientId) end
                -- A replayed furniture quote may return ok with alreadyPurchased.
                if result.ok and not (result.value and result.value.alreadyPurchased) and ctx.PlayObjectSound then
                    ctx.PlayObjectSound("ui_confirm")
                end
            end
        end})
    if ctx.ticketConfirm then TicketView.Confirm(ctx,overlay) end
end
return S
