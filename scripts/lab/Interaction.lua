local U=require "core.StateUtil"
local S=require "lab.Spatial"
local A={}
function A.New(ctx,rig,world)
    local api={panel=false,dragging=false,revision=0}
    local function changed() api.revision=api.revision+1 end
    function api.Open(name) if rig.busy then return false end; api.panel=name; changed(); return true end
    function api.Close() api.panel=false; changed() end
    function api.Navigate(mode)
        if rig.busy then return false end
        api.panel=false; changed(); ctx.model.ReturnHome()
        return rig.Go(mode)
    end
    function api.Read(id)
        local result=ctx.model.Read(id)
        if result.ok then api.Open("reader") end
        return result
    end
    function api.Activate(id)
        if rig.busy or api.panel or api.dragging then return false end
        if id=="home.net" then return api.Navigate("Seaside") end
        if id=="home.stove" then return api.Navigate("Brew") end
        if id=="home.merchantShip" then return api.Open("shop") end
        if id=="home.letterPaper" or id=="home.drawer" then
            local rows=ctx.session.queries.GetLetters()
            if not rows.ok then ctx.model.Notify(rows); return false end
            if id=="home.letterPaper" and #rows.value==1 then return api.Read(rows.value[1].letterInstanceId) end
            return api.Open("letters")
        end
        return false
    end
    function api.Pick(origin,direction)
        if rig.busy or api.panel or api.dragging then return nil end
        local selected,distance=nil,math.huge
        for _,proxy in ipairs(world.proxies) do
            local hit=S.RayBox(origin,direction,proxy)
            if hit and hit<distance then selected,distance=proxy.id,hit end
        end
        if not selected then return nil end
        -- Door/walls/table/shelves occlude: never pick a proxy through geometry.
        for _,box in ipairs(world.occluders) do
            local hit=S.RayBox(origin,direction,box)
            if hit and hit<distance-0.015 and box.owner~=selected then return nil end
        end
        if world.IsOccluded and world.IsOccluded(origin,direction,distance,selected) then return nil end
        return selected
    end
    function api.Pointer(origin,direction,uiConsumed)
        if uiConsumed then return false end
        local id=api.Pick(origin,direction)
        return id and api.Activate(id) or false
    end
    function api.Salvage()
        if rig.busy or rig.mode~="Seaside" or api.dragging then return U.Fail("LAB_INPUT_BLOCKED","input","请到码头后捕捞") end
        local view=ctx.session.queries.GetSalvageView()
        if not view.ok then return ctx.model.Notify(view) end
        if not view.value.enabled or not view.value.availableLetterIds[1] then
            return ctx.model.Notify(U.Fail(view.value.reasonCode or "LETTER_NOT_AVAILABLE","salvage",view.value.message or "目前没有可捕捞来信"))
        end
        return ctx.model.Receive(view.value.availableLetterIds[1])
    end
    -- Future hook: independent rim plane, not the whole stove body.
    function api.CanDropAt(origin,direction)
        if rig.busy or api.panel or rig.mode~="Brew" or direction[2]>=-1e-7 then return false end
        local rim=world.rim; local t=(rim.center[2]-origin[2])/direction[2]
        if t<=0 then return false end
        local p=S.Add(origin,S.Mul(direction,t)); local x,z=p[1]-rim.center[1],p[3]-rim.center[3]
        if x*x+z*z>rim.radius*rim.radius then return false end
        for _,box in ipairs(world.occluders) do local hit=S.RayBox(origin,direction,box); if hit and hit<t then return false end end
        return true
    end
    return api
end
return A
