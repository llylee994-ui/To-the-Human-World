-- Opt-in engine Yoga/pointer/screenshot evidence; isolated memory saves, no OS input.
local UI=require "urhox-libs/UI"
local Pointer=require "urhox-libs/UI/Core/PointerEvent"
local Gesture=require "urhox-libs/UI/Core/GestureEvent"
local Hud=require "ui.landscape.HudLayout"
local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local N={}
function N.New()
    local phase,deadline,done=0,0,false
    local cooldown=0;local seen={} ;local trayCards={}
    ---@type table|nil
    local view
    local fixture,request,before
    local rects={};local workbench={};local phone=true;local purchaseCount=0
    local readHost=Hud.ReadHost
    local function node(id)
        local root=view.root --[[@as Widget]]
        return assert(root:FindById(id),id)
    end
    local function bounds(id) return U.Copy(node(id):GetAbsoluteLayout()) end
    local function same(a,b)
        for _,k in ipairs({"x","y","w","h"}) do assert(math.abs(a[k]-b[k])<1,"geometry changed "..k.." "..cjson.encode({a,b})) end
    end
    local function pointer(kind,x,y)
        local s=UI.GetScale()
        local event=Pointer.new(kind,{x=x*s,y=y*s,pointerId=91,pointerType="touch",button=MOUSEB_LEFT})
        if kind=="PointerDown" then UI.HandlePointerDown(event)
        elseif kind=="PointerMove" then UI.HandlePointerMove(event)
        else UI.HandlePointerUp(event) end
    end
    local function tapAt(x,y)
        pointer("PointerDown",x,y);pointer("PointerUp",x,y);view.Update()
    end
    local function tap(id)
        local target=node(id);local r=target:GetAbsoluteLayout()
        assert(UI.FindWidgetAt(r.x+r.w/2,r.y+r.h/2)==target,"blocked "..id.." "..cjson.encode(r))
        tapAt(r.x+r.w/2,r.y+r.h/2)
    end
    local out="first_batch_r2_"
    local function capture(name)
        local im=Image();assert(graphics:TakeScreenShot(im))
        if phone then
            local s=UI.GetScale();im=im:GetSubimage(IntRect(0,0,math.floor(1206*s),math.floor(540*s)))
        end
        assert(im:SavePNG(out..name..".png"));print("[FirstBatchNative] CAPTURE "..name)
    end
    local function setup(cash,brew)
        if view then view.root:Destroy() end
        fixture=R.New(cash)
        if brew then request=R.Accept(fixture,1) end
        local checks=require "ui.landscape.DevChecks";checks.firstBatchProbe=false
        view=require("ui.landscape.AppView").New(fixture.session,fixture.content);checks.firstBatchProbe=true
        local update=view.brew.Update;view.brew.Update=function(dt) update(dt,true) end
        return view
    end
    local function cleanup(ctx)
        Hud.ReadHost=readHost
        if view then view.root:Destroy();view=nil end
        ctx.root:SetVisible(true);ctx.Refresh();done=true
    end
    local shopIds={"shopContent","shopGoodsPage","shopDetail","shopDetailFooter","shopSelectedArt","shopPager","buy_ing_night_dew"}
    local function rememberShop() for _,id in ipairs(shopIds) do rects[id]=bounds(id) end end
    local function checkShop() for _,id in ipairs(shopIds) do same(rects[id],bounds(id)) end end
    return function(ctx)
        if done or not ctx.root.parent then return end
        if view then view.Update() end
        if cooldown>0 then cooldown=cooldown-1;return end
        local now=GetTime():GetElapsedTime();if now<deadline then return end
        local ok,err=pcall(function()
            if phase==0 then
                before=ctx.session.state.GetSnapshot()
                Hud.ReadHost=function()
                    if phone then return {w=1206,h=540},{left=40,right=0,top=0,bottom=12},{left=.86,right=.99,top=.02,bottom=.16} end
                    local w,h=UI.GetViewportSize();return {w=w,h=h},{left=0,right=0,top=0,bottom=0},nil
                end
                setup(1000,true);ctx.root:SetVisible(false);ctx.root.parent:AddChild(view.root)
                R.Must(view.model.Drop("word",request.mainTokenId))
                for _,id in ipairs(request.auxTokenIds) do R.Must(view.model.Drop("word",id)) end
                for _,line in ipairs(request.ingredients) do for _=1,line.quantity do R.Must(view.model.Drop("ingredient",line.ingredientId)) end end
                view.Navigate("brew");view.Update();deadline=now+3
                print("[FirstBatchNative] START real Yoga/touch routing; 1206x540 host adapter, NOT physical phone")
            elseif phase==1 then
                assert(bounds("brewWordPanel").x==0,"brew tray flush left")
                for _,id in ipairs({"brewRecipePaper","brewShelf","brewControls"}) do workbench[id]=bounds(id) end
                capture("01-phone-workbench");tap("brewRecipeDetails");deadline=now+.5
            elseif phase==2 then
                local r=bounds("brewDetail")
                local center=view.brew.layout.center
                assert(r.x==center.x and r.w==center.w and r.y>=view.brew.layout.pot.y+view.brew.layout.pot.h,"drawer stays under cauldron in center column")
                assert(node("brewNotesBackdrop").props.backgroundColor[4]==0,"outside remains bright")
                local close=bounds("brewNotesClose");assert(close.y>=540*.16,"notes close clears capsule")
                for id,b in pairs(workbench) do same(b,bounds(id)) end
                assert(node("brewNotesClose").props.onClick and not view.root:FindById("brewMainEffectMeaning"),"close and no prognosis")
                capture("02-phone-notes");tap("brewToggleNumbers");deadline=now+.3
            elseif phase==3 then
                assert(node("brewEffectNumbers"));capture("03-phone-notes-numbers")
                local area=bounds("brewDetailBody")
                local sx,sy=area.x+area.w/2,area.y+area.h-10
                local target=UI.FindWidgetAt(sx,sy);local scale=UI.GetScale()
                pointer("PointerDown",sx,sy)
                for _,kind in ipairs({"PanStart","PanMove","PanEnd"}) do
                    UI.HandleGestureEvent(Gesture.new(kind,{target=target,x=sx*scale,y=(sy-72)*scale,
                        pointerId=91,pointerType="touch",deltaX=0,deltaY=-72*scale,totalDeltaX=0,totalDeltaY=-72*scale}))
                end
                pointer("PointerUp",sx,sy-72)
                local _,scrollY=node("brewDetailBody"):GetScroll();assert(scrollY>0,"notes scroll through touch routing")
                local paper=bounds("brewDetail");local x,y=paper.x+10,paper.y+paper.h/2
                assert(UI.FindWidgetAt(x,y)==node("brewDetail"),"inside blank belongs to paper")
                tapAt(x,y);assert(view.brew.selected=="recipe","inside blank must stay open")
                tap("brewNotesBackdrop");assert(view.brew.selected==false,"outside blank closes notes")
                deadline=now+.3
            elseif phase==4 then
                for id,b in pairs(workbench) do same(b,bounds(id)) end
                R.Must(view.model.Preview());view.Open("result");view.Update();deadline=now+.8
            elseif phase==5 then
                local paper,body,actions=bounds("activePanel"),bounds("resultScroll"),bounds("resultActions")
                assert(paper.y<=12 and paper.w>1000 and body.h>300,"phone full reading area")
                assert(actions.y+actions.h<=paper.y+paper.h,"actions remain on paper")
                local close=bounds("closePanel")
                assert(close.x+close.w<1206*.86 or close.y>=540*.16,"only close button clears capsule")
                capture("04-phone-reply")
                view.root:Destroy();view=nil
                setup(1000,false);ctx.root.parent:AddChild(view.root);view.Open("shop");view.Update();deadline=now+.5
            elseif phase==6 then
                tap("shop_select_ing_night_dew");deadline=now+.3
            elseif phase==7 then
                rememberShop();capture("05-phone-shop-before");tap("buy_ing_night_dew");purchaseCount=1;deadline=now+.3
            elseif phase==8 then
                checkShop();if purchaseCount==1 then capture("06-phone-shop-after") end
                if not node("buy_ing_night_dew").props.disabled then
                    tap("buy_ing_night_dew");purchaseCount=purchaseCount+1;assert(purchaseCount<20);deadline=now+.15;cooldown=3;return
                end
                assert(node("shopItemReason"):GetText():find("售完"),"last stock tested")
                capture("07-phone-shop-soldout")
                setup(12,false);ctx.root.parent:AddChild(view.root);view.Open("shop");view.Update();deadline=now+.3
            elseif phase==9 then
                tap("shop_select_ing_night_dew");deadline=now+.3
            elseif phase==10 then
                rememberShop();tap("buy_ing_night_dew");deadline=now+.3
            elseif phase==11 then
                checkShop();assert(node("buy_ing_night_dew").props.disabled,"insufficient balance tested")
                capture("08-phone-shop-no-money")
                phone=false;setup(1000,true);ctx.root.parent:AddChild(view.root)
                R.Must(view.model.Drop("word",request.mainTokenId));view.Navigate("brew");view.Update();deadline=now+.5
            elseif phase==12 then
                tap("brewRecipeDetails");deadline=now+.5
            elseif phase==13 then
                capture("09-desktop-notes");tap("brewNotesClose")
                for _,id in ipairs(request.auxTokenIds) do R.Must(view.model.Drop("word",id)) end
                for _,line in ipairs(request.ingredients) do for _=1,line.quantity do R.Must(view.model.Drop("ingredient",line.ingredientId)) end end
                R.Must(view.model.Preview());view.Open("result");view.Update();deadline=now+.8
            elseif phase==14 then
                capture("10-desktop-reply")
                phone=true;setup(1000,false);ctx.root.parent:AddChild(view.root)
                local content=fixture.content --[[@as table]]
                for i,word in ipairs(content.words) do trayCards[i]={text=word.displayText,tokenId="display-only:"..i,categoryId="one",available=true,sourceTitle="字体与分页测试"} end
                view.session.queries.GetWordTray=function() return {ok=true,value={cards=trayCards,categories={{id="one",title="词语",availableCount=#trayCards}}}} end
                view.Open("words");view.Update();deadline=now+1
            elseif phase==15 then
                local area=bounds("wordTrayStrips")
                assert(bounds("activePanel").x==0,"ordinary tray flush left")
                for _,card in ipairs(trayCards) do
                    local root=view.root --[[@as Widget]]
                    local widget=root:FindById("wordTrayCard_"..card.tokenId)
                    if widget then
                        local r=widget:GetAbsoluteLayout()
                        assert(r.x>=area.x and r.y>=area.y and r.x+r.w<=area.x+area.w+1 and r.y+r.h<=area.y+area.h+1,"full native card fits its page")
                        seen[card.tokenId]=true
                    end
                end
                capture("11-phone-tray-page-"..view.wordTray.pages.one)
                if not node("wordTrayNext").props.disabled then tap("wordTrayNext");deadline=now+.2;cooldown=3;return end
                for _,card in ipairs(trayCards) do assert(seen[card.tokenId],"native pagination reaches every word") end
                assert(not node("wordTrayPrev").props.disabled,"last page can go back")
                assert(U.Equal(before,ctx.session.state.GetSnapshot()),"original player snapshot unchanged")
                cleanup(ctx);print("[FirstBatchNative] PASS notes overlay/readable numbers/no reflow; phone wide reply/capsule; real purchases first/continuous/soldout/no money identical Yoga rectangles; actual desktop viewport; 61 real words font/native arrow pages; original player unchanged")
            end
            phase=phase+1;cooldown=3
        end)
        if not ok then print("[FirstBatchNative] FAIL phase="..phase.." "..tostring(err));cleanup(ctx) end
    end
end
return N
