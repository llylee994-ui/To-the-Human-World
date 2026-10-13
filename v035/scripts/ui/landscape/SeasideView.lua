-- Seaside presentation only: UI callbacks delegate all transactions to AppView.
local UI=require "urhox-libs/UI"
local Harbor=require "ui.landscape.HarborStyle"
local G=require "ui.landscape.LayoutGeometry"
local M=require "ui.landscape.SeasideManifest"
local Backdrop=require "ui.landscape.SceneBackdrop"
local S={}
local function sprite(vg,path,x,y,w,h,angle,alpha)
    local handle=math.floor(require("urhox-libs/UI/Core/ImageCache").Get(path))
    if handle<=0 or alpha<=0 then return end
    nvgSave(vg);nvgTranslate(vg,x,y);nvgRotate(vg,math.rad(angle))
    nvgBeginPath(vg);nvgRect(vg,-w/2,-h/2,w,h)
    nvgFillPaint(vg,nvgImagePattern(vg,-w/2,-h/2,w,h,0,handle,alpha));nvgFill(vg);nvgRestore(vg)
end
local function ring(vg,x,y,rx,ry,alpha)
    nvgBeginPath(vg);nvgEllipse(vg,x,y,rx,ry)
    nvgStrokeColor(vg,nvgRGBA(226,242,235,math.floor(alpha)));nvgStrokeWidth(vg,2);nvgStroke(vg)
end
function S.New(ctx)
    local root=UI.Panel {id="seasideView",position="absolute",left=0,top=0,width="100%",height="100%",
        visible=false,backgroundColor={32,60,72,255},pointerEvents="box-none"}
    local background=Backdrop.New("seasideBackdrop",M.background,M.width,M.height,M.foreground)
    root:AddChild(background)
    local canvas=UI.Panel {id="seasideCanvas",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,pointerEvents="box-none"}
    root:AddChild(canvas)
    local art=UI.Panel {id="seasideArt",position="absolute",left=0,top=0,width="100%",height="100%",pointerEvents="none"}
    canvas:AddChild(art)
    local api={root=root,canvas=canvas,art=art,background=background,time=0 --[[@as number]],bottleVisible=false --[[@as boolean]],manifest=M}
    function api.Fit() return G.SceneFit(root:GetAbsoluteLayout(),M) end
    function api.ShipLayer()
        local s=M.ship
        return {path=s.path,x=s.x,y=s.y+math.sin(api.time*.85)*18,width=s.width,height=s.height,rotation=math.sin(api.time*.7)*2.2,visible=true}
    end
    function art:Render(vg)
        local fit=api.Fit();if fit.scale<=0 then return end
        local bounds=canvas:GetAbsoluteLayout()
        nvgSave(vg);nvgIntersectScissor(vg,bounds.x,bounds.y,bounds.w,bounds.h)
        nvgTranslate(vg,fit.x,fit.y);nvgScale(vg,fit.scale,fit.scale)
        local ship=api.ShipLayer();sprite(vg,ship.path,ship.x,ship.y,ship.width,ship.height,ship.rotation,1)
        local pose=ctx.salvage.Pose()
        if api.bottleVisible or ctx.salvage.letterInstanceId then
            local bob=(ctx.salvage.active or ctx.salvage.letterInstanceId) and 0 or math.sin(api.time*1.65)*15
            local floating=not ctx.salvage.letterInstanceId
            local angle=floating and math.sin(api.time*1.25)*4 or 0
            if floating or pose.phase=="lowering" then
                ring(vg,M.bottle.x,M.bottle.y+35+bob,75+math.sin(api.time)*10,16,100)
                ring(vg,M.bottle.x,M.bottle.y+35+bob,92+math.sin(api.time+1)*12,20,45)
            end
            sprite(vg,M.bottle.path,pose.bottleX,pose.bottleY+bob,M.bottle.width*pose.bottleScale,M.bottle.height*pose.bottleScale,angle,pose.bottleOpacity)
        end
        sprite(vg,M.net.path,pose.netX,pose.netY,M.net.width,M.net.height,pose.netAngle,pose.netOpacity)
        if pose.splash>0 then
            ring(vg,M.bottle.x,M.bottle.y+35,75+pose.splash*65,16+pose.splash*12,pose.splash*140)
            for i=1,7 do
                local angle=i*2.4;local radius=35+pose.splash*65
                local dx=M.bottle.x+math.cos(angle)*radius
                local dy=pose.bottleY+20+math.sin(angle)*18+math.sin(api.time*6+i)*10
                nvgBeginPath(vg);nvgCircle(vg,dx,dy,2+i%3)
                nvgFillColor(vg,nvgRGBA(223,239,241,math.floor(pose.splash*180)));nvgFill(vg)
            end
        end
        nvgRestore(vg)
    end
    local shipHot=UI.Panel {id="seaside.merchantShip",position="absolute",left=0,top=0,width="100%",height="100%",
        onClick=function(_,event)
            if event and event.button~=MOUSEB_LEFT then return end
            if not ctx.salvage.active then ctx.Open("shop") end
        end}
    function shipHot:HitTest(x,y)
        return not ctx.salvage.active and G.HitObject({layers={api.ShipLayer()}},M.shipObject,api.Fit(),x,y)
    end
    canvas:AddChild(shipHot)
    local bar=UI.Panel {id="seasideControls",width="100%",height=76,flexShrink=0,paddingLeft=14,paddingRight=14,
        flexDirection="row",alignItems="center",gap=12,pointerEvents="box-none"}
    root:AddChild(bar)
    local info=Harbor.Paper {flexGrow=1,minWidth=0,pointerEvents="none",gap=4,padding={6,14}}
    local title=UI.Label {text="海边 · 木码头",fontSize=17,fontColor={65,46,28,255},pointerEvents="none"}
    local status=UI.Label {id="salvageStatus",fontSize=14,whiteSpace="normal",fontColor={65,46,28,255},pointerEvents="none"}
    info:AddChild(title);info:AddChild(status);bar:AddChild(info)
    local capture=Harbor.Button {id="startSalvage",text="开始捕捞",width=240,minHeight=48,fontSize=16,
        backgroundColor={188,147,77,255},textColor={35,36,29,255},borderRadius=8,onClick=function() ctx.StartSalvage() end}
    local read=Harbor.Button {id="readCapturedLetter",text="阅读捞到的信",width=240,minHeight=48,fontSize=16,visible=false,
        backgroundColor={188,147,77,255},textColor={35,36,29,255},borderRadius=8,onClick=function() ctx.OpenCapturedLetter() end}
    local shop=Harbor.Button {id="seasideShop",text="商队商店",width=122,minHeight=48,fontSize=15,onClick=function() ctx.Open("shop") end}
    bar:AddChild(capture);bar:AddChild(read);bar:AddChild(shop)
    function api.Update(dt) api.time=api.time+math.max(0,math.min(dt,.1)) end
    function api.Refresh()
        local r=ctx.session.queries.GetSalvageView()
        local received=not not ctx.salvage.letterInstanceId
        api.bottleVisible=r.ok and #r.value.availableLetterIds>0 and r.value.remaining>0
        capture:SetVisible(not received);read:SetVisible(received)
        capture:SetDisabled(not r.ok or not r.value.enabled or ctx.salvage.active)
        read:SetDisabled(ctx.salvage.active);shop:SetDisabled(ctx.salvage.active)
        if received then
            status:SetText(ctx.salvage.active and "正在收起漂流瓶…" or "信已收好，可阅读或返回药铺。")
        elseif not r.ok then status:SetText(r.error.message)
        else
            capture:SetText("开始捕捞 · 剩余 "..r.value.remaining.." 次")
            status:SetText(r.value.enabled and "一只漂流瓶靠近了码头。" or r.value.message)
        end
    end
    return api
end
return S
