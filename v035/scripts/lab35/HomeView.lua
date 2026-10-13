-- Transparent Home facade. The scene is supplied by MeshLoader, never the old lab.
local H={}
function H.New(controller,options)
    local UI=require "urhox-libs/UI"
    local Harbor=require "ui.landscape.HarborStyle"
    assert(options and options.ray and options.picker and options.project and options.hintOccluded,"explicit scene pick/projection dependencies required")
    local root=UI.Panel {id="v035Home",position="absolute",left=0,top=0,width="100%",height="100%",pointerEvents="box-none"}
    local surface=UI.Panel {id="v035PickSurface",position="absolute",left=0,top=0,width="100%",height="100%",
        onClick=function(_,event)
            if not event or (event.button and event.button~=MOUSEB_LEFT) then return end
            if not controller.WorldAllowed() then return end
            local rect=root:GetAbsoluteLayout()
            if rect.w<=0 or rect.h<=0 then return end
            local x,y=event.x,event.y
            if type(x)~="number" or type(y)~="number" then return end
            local origin,direction=options.ray((x-rect.x)/rect.w,(y-rect.y)/rect.h)
            local id=options.picker.Pick(origin,direction)
            local gesture=event.timestamp and (tostring(event.pointerId or 0)..":"..tostring(event.timestamp)) or event
            if id then controller.Activate(id,gesture,event._defaultPrevented==true) end
        end}
    root:AddChild(surface)
    local hints={}
    for id,definition in pairs(require "lab35.Ids") do
        local hint=Harbor.Tag {id="v035Hint."..id,text=definition.label,position="absolute",visible=false}
        root:AddChild(hint);hints[id]=hint
    end
    local api={root=root,inspect=false,lastHit="",zoom=1}
    function api.Fit() local r=root:GetAbsoluteLayout();return {x=r.x,y=r.y,w=r.w,h=r.h,scale=r.w/1920} end
    function api.SetInspect() end
    function api.SetZoom(value) api.zoom=value end -- compatibility only; no flat-image zoom.
    function api.SetBlocked(value) api.blocked=value end
    function api.ShowHints(value) controller.ShowHints(value) end
    function api.HintsVisible() return controller.HintsVisible() end
    function api.Update()
        for _,hint in pairs(hints) do hint:SetVisible(false) end
        local r=root:GetAbsoluteLayout()
        local rows=controller.ProjectHints(function(point) return options.project(point,r) end,r,options.hintOccluded)
        for _,row in ipairs(rows) do
            local hint=hints[row.id]
            -- Labels don't intercept scene/UI input and remain within the visible Home.
            hint:SetStyle({left=math.max(0,math.min(r.w-140,row.x-r.x-70)),top=math.max(0,row.y-r.y-46),width=140})
            hint:SetVisible(true)
        end
    end
    return api
end
return H
