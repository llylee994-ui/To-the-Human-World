-- Temporary input/display state. All persisted changes belong to PlayModel.
local L=require "ui.landscape.BrewLayout"
local Smoke=require "ui.landscape.BrewSmoke"
local I={Lift=24}
local function target(drop,item,x,y)
    if type(drop)=="function" then return drop(item,x,y) end
    return L.Contains(drop,x,y) and drop or false
end
---@param model table
---@param onResult fun()
---@return table
function I.New(model,onResult)
    local s={drag=false --[[@as table|false]],active=false --[[@as boolean]],elapsed=0,
        feedback=0,suppressClick=false --[[@as boolean]],duration=Smoke.brewDuration,
        flight=false --[[@as table|false]],pulse=false --[[@as table|false]]}
    function s.CancelDrag()
        if s.drag then s.suppressClick=true end
        s.drag=false
    end
    function s.Begin(item,event)
        if s.active or s.drag or (s.flight and s.flight.accepted) or
            (event.pointerType~="touch" and event.button~=MOUSEB_LEFT) then return false end
        if not model.Action("UpdateDraft").enabled then return false end
        s.suppressClick=false;s.flight=false
        s.drag={kind=item.kind,id=item.id,text=item.text,path=item.path,pointerId=event.pointerId,
            startX=event.x,startY=event.y,x=event.x,y=event.y,
            touch=event.pointerType=="touch",active=false,over=false,target=false}
        return true
    end
    function s.Move(event,drop,recognizedPan)
        local d=s.drag;if not d or d.pointerId~=event.pointerId then return false end
        local dx,dy=event.x-d.startX,event.y-d.startY
        -- The host recognizes a pan in screen pixels, before our base-pixel
        -- slop at high DPI. Claim that first event before ScrollView cancels it.
        if not d.active and (recognizedPan or (dx*dx+dy*dy)>100) then
            d.active=true;s.suppressClick=true
        end
        d.x=event.x;d.y=event.y;d.target=d.active and target(drop,d,event.x,event.y) or false;d.over=not not d.target
        return d.active
    end
    function s.Release(event,drop)
        local d=s.drag;if not d or d.pointerId~=event.pointerId then return end
        -- Pot and matching empty slots route into exactly the same persisted draft.
        local valid=d.active and target(drop,d,event.x,event.y)
        s.drag=false;s.feedback=0
        if valid then
            return s.Commit(d,event.x,event.y-I.Lift,valid)
        elseif d.active then
            s.flight={kind=d.kind,id=d.id,text=d.text,path=d.path,fromX=event.x,fromY=event.y-I.Lift,
                toX=d.startX,toY=d.startY,accepted=false,elapsed=0,duration=.18}
        end
    end
    function s.Commit(item,x,y,destination)
        if s.active or (s.flight and s.flight.accepted) then return false end
        local r=model.Drop(item.kind,item.id)
        if r.ok then
            s.feedback=.35
            s.flight={kind=item.kind,id=item.id,text=item.text,path=item.path,fromX=x,fromY=y,
                toX=destination.landingX or destination.x+destination.w/2,toY=destination.landingY or destination.y+destination.h/2,
                accepted=true,elapsed=0,duration=.38,pot=destination.landingX~=nil}
        end
        return r
    end
    function s.SampleFlight()
        local f=s.flight;if not f then return false end
        local t=math.min(1,f.elapsed/f.duration);local p=1-(1-t)^3
        return {kind=f.kind,id=f.id,text=f.text,path=f.path,
            x=f.fromX+(f.toX-f.fromX)*p,y=f.fromY+(f.toY-f.fromY)*p-math.sin(t*math.pi)*(f.accepted and 20 or 8),
            scale=f.accepted and (1-.85*t*t) or 1,alpha=f.accepted and (1-t^3) or (1-t*.2)}
    end
    function s.ClickAllowed() return not s.active and not s.drag and not s.suppressClick end
    function s.Start()
        if s.active or (s.flight and s.flight.accepted) then return false end
        s.CancelDrag()
        local data=model.Refresh()
        if data and data.currentOrder and data.currentOrder.pending then onResult();return false end
        local r=model.Preview()
        if r.ok and r.value.phase=="pending" then s.active=true;s.elapsed=0 end
        return r
    end
    function s.Skip()
        if not s.active then return end
        s.active=false;s.elapsed=s.duration;onResult()
    end
    function s.Cancel() s.CancelDrag();s.active=false;s.elapsed=0;s.feedback=0;s.flight=false;s.pulse=false end
    function s.Update(dt,focused)
        if not focused or dt<0 or dt>.5 then s.Cancel();return end
        s.feedback=math.max(0,s.feedback-math.max(0,dt or 0))
        if s.pulse then s.pulse.elapsed=s.pulse.elapsed+dt;if s.pulse.elapsed>.4 then s.pulse=false end end
        if s.flight then
            local f=s.flight;f.elapsed=f.elapsed+dt
            if f.elapsed>=f.duration then
                if f.accepted and f.pot then s.pulse={x=f.toX,y=f.toY,elapsed=0} end
                s.flight=false;model.dirty=true
            end
        end
        if s.active then
            s.elapsed=s.elapsed+math.max(0,dt or 0)
            if s.elapsed>=s.duration then s.Skip() end
        end
    end
    return s
end
return I
