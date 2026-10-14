-- Adapts native presentation/navigation only. Business uses shared main modules.
local IDs=require "v035.lab35.Ids"
local C={}
function C.New(bundle,navigation)
    assert(navigation and type(navigation.Start)=="function","explicit navigation driver required")
    local api={busy=false,dragging=false,hints=false,anchors={},navigation=navigation}
    local ctx,serial,active,dayToken,lastGesture=nil,0,nil,nil,nil
    local original={}
    local function blocked()
        return not ctx or ctx.destroyed or ctx.portrait or api.busy or api.dragging or ctx.salvage.active or ctx.ticketEnding
    end
    function api.WorldAllowed() return not blocked() and not ctx.panel and ctx.scene=="home" end
    function api.SetDragging(value) api.dragging=not not value end
    function api.ShowHints(value) api.hints=not not value end
    function api.HintsVisible() return api.hints and api.WorldAllowed() end
    function api.Bind(view)
        assert(not ctx,"controller already bound")
        assert(view.session==bundle.session and view.model==bundle.model,"single session/model identity violated")
        ctx=view
        for _,name in ipairs({"Navigate","Open","Close","Read","StartSalvage","CancelHomeZoom"}) do original[name]=assert(ctx[name]) end
        function ctx.CancelHomeZoom(reason)
            if api.busy then
                active=nil;api.busy=false
                if navigation.Cancel then navigation.Cancel() end
                ctx.LabSetNavigationBlocked(false)
            end
            original.CancelHomeZoom(reason)
        end
        function ctx.Navigate(target)
            if blocked() or (target~="home" and target~="brew" and target~="seaside") then return false end
            if target==ctx.scene then return true end
            serial=serial+1;local token=serial;active=token;api.busy=true;dayToken=nil
            ctx.LabSetNavigationBlocked(true)
            local from=ctx.scene
            local function finish(success)
                if active~=token or ctx.destroyed then return false end
                active=nil;api.busy=false;ctx.LabSetNavigationBlocked(false)
                if success then original.Navigate(target) end
                bundle.model.dirty=true;return true
            end
            local ok,accepted=pcall(navigation.Start,from,target,finish)
            if not ok or accepted==false then finish(false);return false end
            return true
        end
        function ctx.BeginHomeZoom()
            if not api.WorldAllowed() then return false end
            return ctx.Navigate("seaside")
        end
        function ctx.Open(kind)
            if blocked() then return false end
            if kind=="home" or kind=="seaside" or kind=="brew" then return ctx.Navigate(kind) end
            original.Open(kind);return true
        end
        function ctx.Close()
            if blocked() then return false end
            dayToken=nil;original.Close();return true
        end
        function ctx.Read(id)
            if blocked() then return false end
            return original.Read(id)
        end
        function ctx.StartSalvage()
            if blocked() then return false end
            return original.StartSalvage()
        end
        function ctx.BeginDayConfirmation()
            if blocked() or ctx.panel~="day" then return false end
            serial=serial+1;dayToken=serial;return dayToken
        end
        function ctx.ConfirmDay(token)
            if blocked() or ctx.panel~="day" or not token or token~=dayToken then return false end
            dayToken=nil -- consume before the command; stale/double pointer-up cannot advance another day.
            local result=bundle.model.NextDay()
            if result.ok then ctx.Close() else bundle.model.dirty=true end
            return result
        end
        local destroy=ctx.root.Destroy
        function ctx.root:Destroy()
            active=nil;api.busy=false;dayToken=nil
            if navigation.Cancel then navigation.Cancel() end
            destroy(self)
        end
    end
    function api.Activate(id,gestureId,uiConsumed)
        if uiConsumed or not api.WorldAllowed() or not IDs[id] then return false end
        if gestureId~=nil and gestureId==lastGesture then return false end
        lastGesture=gestureId
        return ctx.Open(IDs[id].target)
    end
    function api.Back() if blocked() then return false end;return ctx.Navigate("home") end
    function api.EndDay() if blocked() or ctx.panel then return false end;return ctx.Open("day") end
    function api.Hud()
        local state=bundle.model.Refresh()
        if not state then return {enabled=false} end
        return {enabled=true,day=state.live.gameFlow.day,currency=state.live.economy.currency,
            scene=ctx and ctx.scene or "home",pending=not not (state.currentOrder and state.currentOrder.pending),
            backVisible=ctx and ctx.scene~="home" or false,blocked=blocked(),message=bundle.model.message}
    end
    function api.SetAnchors(anchors) api.anchors=anchors end
    function api.ProjectHints(project,rect,isOccluded)
        local result={}
        if not api.HintsVisible() then return result end
        assert(type(isOccluded)=="function","explicit hint occlusion query required")
        for _,anchor in ipairs(api.anchors) do
            local definition=IDs[anchor.id]
            if definition and anchor.proxy and not isOccluded(anchor.position,anchor.id) then
                local p=project(anchor.position)
                if p and p.x>=rect.x and p.x<=rect.x+rect.w and p.y>=rect.y and p.y<=rect.y+rect.h then
                    result[#result+1]={id=anchor.id,label=definition.label,x=p.x,y=p.y}
                end
            end
        end
        return result
    end
    return api
end
return C
