-- Optional bounded native evidence using actual UI callbacks, never OS input.
local O={}
function O.New(app,camera,node,log)
    local ids={"home.drawer","home.journal","home.tray","home.caseFile","home.merchantShip","home.letterPaper","home.net","home.stove"}
    local anchors={};for _,a in ipairs(app.imported.prepared.anchors) do anchors[a.id]=a end
    local n={elapsed=0,index=1,phase="wait",due=4,complete=false}
    local U=require "v035.core.StateUtil"
    local baseline=app.bundle.session.state.GetSnapshot();local writes=app.bundle.storage.WriteCount()
    app.controller.ShowHints(true)
    log("OBSERVATION",{input="programmatic actual UI onClick callback + native ray/picker; no OS or human input",automaticBusinessCommands=false})
    function n.Update(dt)
        if n.complete then return end
        n.elapsed=n.elapsed+dt;if n.elapsed<n.due then return end
        if n.phase=="close" then
            if app.view.panel then app.view.Close() end
            if app.view.scene~="home" then app.controller.Back() end
            n.index=n.index+1;n.phase="wait";n.due=n.elapsed+3;return
        end
        if n.index>#ids then
            n.complete=true
            log("ENTRY_CHECK_DONE",{entries=#ids,unchangedState=U.Equal(baseline,app.bundle.session.state.GetSnapshot()),
                unchangedMemoryWrites=writes==app.bundle.storage.WriteCount(),input="programmatic UI callbacks"})
            return
        end
        local id=ids[n.index];local anchor=anchors[id]
        local rect=app.view.home.root:GetAbsoluteLayout()
        local point=require("v035.lab35.NativeGeometry").Project(camera,node,anchor.position,rect)
        local hit
        if point then
            local ray=camera:GetScreenRay((point.x-rect.x)/rect.w,(point.y-rect.y)/rect.h)
            hit=app.picker.Pick({ray.origin.x,ray.origin.y,ray.origin.z},{ray.direction.x,ray.direction.y,ray.direction.z})
            local surface=assert(app.view.home.root:FindById("v035PickSurface"))
            surface.props.onClick(surface,{x=point.x,y=point.y,button=MOUSEB_LEFT,pointerId=1,timestamp=n.index})
        end
        app.view.Update()
        log("ENTRY_CHECK",{id=id,picked=hit,projected=point~=nil,scene=app.view.scene,panel=app.view.panel,
            busy=app.controller.busy,label=require("v035.lab35.Ids")[id].label,input="programmatic actual UI callback"})
        n.phase="close";n.due=n.elapsed+3
    end
    return n
end
return O
