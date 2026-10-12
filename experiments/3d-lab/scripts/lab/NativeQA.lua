-- Native program-driven acceptance. Never generates OS mouse/keyboard input.
-- Uses the one existing lab session; only this explicit test invokes business.
local Q={}
function Q.New(app)
    local U=require "core.StateUtil"
    local S=require "lab.Spatial"
    local ctx,rig,a=app.ctx,app.rig,app.adapter
    local steps={}; local index,age,wait=1,0,8
    local baseline=ctx.session.state.GetSnapshot()
    local item,letterId,spanId,cards
    local failed=false
    local function log(status,name,detail)
        print("[D3-LAB QA] "..cjson.encode({utc=os.date("!%Y-%m-%dT%H:%M:%SZ"),status=status,name=name,detail=detail or "",camera=rig.mode,panel=a.panel,width=graphics:GetWidth(),height=graphics:GetHeight(),writes=ctx.storage.GetWriteCount()}))
    end
    local function check(name,ok,detail) if not ok then error(name..": "..tostring(detail)) end; log("PASS",name,detail) end
    local function step(name,fn,seconds) steps[#steps+1]={name=name,fn=fn,seconds=seconds or 7} end
    local function click(id)
        local p=assert(app.hud.root:FindById(id),"missing UI "..id)
        local props=p.props; assert(not props.disabled,"disabled UI "..id)
        props.onClick(p)
    end
    local function ray(id)
        for _,p in ipairs(app.world.proxies) do if p.id==id then
            local c=S.Mul(S.Add(p.min,p.max),0.5)
            local v=app.view.camera:WorldToScreenPoint(Vector3(c[1],c[2],c[3]))
            check("visible native projected target "..id,v.x>0 and v.x<1 and v.y>0 and v.y<1,{x=v.x,y=v.y})
            return app.view.Ray(v.x,v.y)
        end end
        error("missing proxy "..id)
    end
    local function pick(id)
        local o,d=ray(id)
        check("native pick "..id,a.Pick(o,d)==id)
        check("native pointer "..id,a.Pointer(o,d,false))
    end
    step("Home baseline",function()
        check("schema3 and no startup writes",ctx.session.state.GetStatus().schema==3 and ctx.storage.GetWriteCount()==0)
        local o,d=ray("home.net")
        check("UI consumed input blocked",not a.Pointer(o,d,true))
        a.dragging=true; check("drag input blocked",not a.Pointer(o,d,false)); a.dragging=false
        check("wall occlusion blocks",a.Pick({-6,1.16,2.75},{1,0,0})==nil)
    end)
    step("Home to Seaside",function() pick("home.net"); check("repeat motion blocked",not a.Activate("home.net")) end,10)
    step("Seaside same ship shop",function()
        check("Seaside reached",rig.mode=="Seaside")
        check("navigation preserves state",U.Equal(baseline,ctx.session.state.GetSnapshot()) and ctx.storage.GetWriteCount()==0)
        pick("home.merchantShip")
    end)
    step("Buy through real shop button",function()
        local v=ctx.session.queries.GetShopView().value; item=v.items[1]
        click("buy_"..item.ingredientId)
        check("purchase debits exact price",ctx.session.queries.GetShopView().value.currency==v.currency-item.price)
        local o,d=ray("home.merchantShip"); check("modal blocks scene",not a.Pointer(o,d,false))
    end)
    step("Atomic real purchase failures",function()
        local b=ctx.session.state.GetSnapshot(); local writes=ctx.storage.GetWriteCount()
        local r=ctx.model.Buy("unknown_lab_ingredient")
        check("unknown purchase atomic",not r.ok and U.Equal(b,ctx.session.state.GetSnapshot()) and writes==ctx.storage.GetWriteCount(),r.error.code)
        for _=1,100 do
            b=ctx.session.state.GetSnapshot(); writes=ctx.storage.GetWriteCount(); r=ctx.model.Buy(item.ingredientId)
            if not r.ok then break end
        end
        check("stock rejection atomic",not r.ok and U.Equal(b,ctx.session.state.GetSnapshot()) and writes==ctx.storage.GetWriteCount(),r.error.code)
        r=ctx.model.Buy(ctx.session.queries.GetShopView().value.items[2].ingredientId)
        check("funds rejection atomic",not r.ok and U.Equal(b,ctx.session.state.GetSnapshot()) and writes==ctx.storage.GetWriteCount(),r.error.code)
    end)
    step("Open explicit salvage",function() click("closePanel"); app.hud.Update(); click("salvagePanel") end)
    step("Real receive setup",function()
        local before=ctx.session.queries.GetSalvageView().value.remaining
        click("receiveLetter")
        check("explicit Receive spends one",ctx.session.queries.GetSalvageView().value.remaining==before-1)
        letterId=ctx.session.queries.GetLetters().value[1].letterInstanceId
        baseline=ctx.session.state.GetSnapshot()
    end)
    step("Seaside return",function() click("closePanel"); app.hud.Update(); click("returnHome") end,10)
    step("Pick paper opens real reader",function()
        check("return Home",rig.mode=="Home")
        check("return preserves business",U.Equal(baseline,ctx.session.state.GetSnapshot()))
        pick("home.letterPaper")
        check("reader panel opened",a.panel=="reader")
    end)
    step("Cut real span through UI",function()
        local v=ctx.session.modules.letters.GetView(letterId).value; spanId=v.spans[1].spanId
        cards=ctx.session.modules.wordTokens.GetInventoryView().value.availableCount
        check("body and requirement exist",#v.segments>0 and app.hud.root:FindById("readerRequirement")~=nil)
        click("cut_"..spanId)
        check("cut creates exactly one card",ctx.session.modules.wordTokens.GetInventoryView().value.availableCount==cards+1)
    end)
    step("Repeat cut idempotent",function()
        local b=ctx.session.state.GetSnapshot(); local writes=ctx.storage.GetWriteCount()
        local r=ctx.model.Cut(spanId)
        check("same span duplicate safe",r.ok and U.Equal(b,ctx.session.state.GetSnapshot()) and writes==ctx.storage.GetWriteCount(),r)
        click("closePanel"); app.hud.Update(); pick("home.letterPaper")
        check("reopen retains gap",ctx.session.modules.letters.GetView(letterId).value.spans[1].cut)
    end)
    step("Home to Brew",function()
        click("closePanel"); app.hud.Update(); baseline=ctx.session.state.GetSnapshot(); pick("home.stove")
    end,9)
    step("Brew same geometry",function()
        check("Brew reached no auto brew",rig.mode=="Brew" and U.Equal(baseline,ctx.session.state.GetSnapshot()))
        local o=S.Add(app.world.rim.center,{0,2,0})
        check("separate rim",a.CanDropAt(o,{0,-1,0}) and not a.CanDropAt(S.Add(o,{0.6,0,0}),{0,-1,0}))
    end)
    step("Brew return",function() click("returnHome") end,9)
    if require("lab.QAConfig").aspectOnly then
        steps={}
        step("Aspect setup real Receive",function()
            local v=ctx.session.queries.GetSalvageView().value
            local r=ctx.model.Receive(v.availableLetterIds[1]); check("aspect setup Receive",r.ok)
            letterId=r.value.letterInstanceId; check("aspect setup Read",ctx.model.Read(letterId).ok)
            baseline=ctx.session.state.GetSnapshot()
        end,3)
    end
    local config=require("lab.QAConfig")
    for _,size in ipairs(config.sizes or {{960,540},{1260,540},{840,630}}) do
        step("aspect "..size[1].."x"..size[2],function()
            if not config.externalSize then
                local result=graphics:SetMode(size[1],size[2],false,false,true,true,true,false,1,0,0)
                log("OBSERVE","native SetMode full signature",tostring(result))
            end
        end,5)
        step("aspect Home targets",function()
            check("exact native dimensions",graphics:GetWidth()==size[1] and graphics:GetHeight()==size[2])
            for _,id in ipairs({"home.net","home.stove","home.merchantShip","home.letterPaper","home.drawer"}) do local o,d=ray(id); check("aspect pick "..id,a.Pick(o,d)==id) end
            pick("home.letterPaper")
        end,7)
        step("aspect reader scroll",function()
            local scroll=assert(app.hud.root:FindById("bodyScroll"))
            scroll:ScrollToBottom(); local _,y=scroll:GetScroll()
            check("reader scroll has travel",y>0,y)
        end,5)
        step("aspect reader close",function() click("closePanel"); app.hud.Update(); pick("home.net") end,10)
        step("aspect Seaside",function() check("aspect Seaside arrived",rig.mode=="Seaside"); click("returnHome") end,10)
        step("aspect Brew",function() pick("home.stove") end,9)
        step("aspect Brew return",function() check("aspect Brew arrived",rig.mode=="Brew"); click("returnHome") end,9)
    end
    step("Complete",function()
        check("final navigation business invariant",U.Equal(baseline,ctx.session.state.GetSnapshot()))
        check("formal save path denied",not pcall(ctx.storage.read,"save_numeric_v02_trial_a.json"))
        for _,entry in ipairs(ctx.storage.GetAudit()) do check("memory only "..entry.path,entry.path:find("save_d3_lab_r3",1,true)==1) end
        log("COMPLETE","native program-driven suite; human input not tested")
    end)
    local q={}
    function q.Update(dt)
        if failed or index>#steps then return end
        age=age+dt; if age<wait or rig.busy then return end
        local entry=steps[index]; graphics.windowTitle="寄往人间 · 独立 3D 试验 | QA "..entry.name; log("BEGIN",entry.name)
        local ok,err=pcall(entry.fn)
        if not ok then failed=true; log("FAIL",entry.name,tostring(err)); return end
        wait=entry.seconds; age=0; index=index+1
    end
    log("ENABLED","explicit QA config; one session; no OS input")
    return q
end
return Q
