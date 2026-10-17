-- Accept the same primary pointer from a stable down through its click.
local P={}
local function primary(event)
    if not event then return true end
    if event.IsPrimaryAction then return event:IsPrimaryAction() end
    return event.button==nil or event.button==MOUSEB_LEFT
end
function P.Bind(node,ready,action,button)
    local armed=false --[[@as boolean]]
    local pointer=false --[[@as number|false]]
    local released=false --[[@as boolean]]
    local px,py=0,0
    local function cancel() armed=false;pointer=false;released=false end
    local function owns(event) return pointer~=false and pointer==(event and event.pointerId or 0) end
    node.props.onPointerDown=function(event)
        if not primary(event) or (event and event.isPrimary==false) or (pointer~=false and not released) then return end
        armed=ready();pointer=event and event.pointerId or 0;released=false
        px,py=event and event.x or 0,event and event.y or 0
    end
    node.props.onPointerUp=function(event) if owns(event) then released=true end end
    node.props.onPointerCancel=function(event) if owns(event) then cancel() end end
    node.props.onPointerMove=function(event)
        if owns(event) and math.abs((event.x or 0)-px)+math.abs((event.y or 0)-py)>8 then armed=false end
    end
    node.props.onClick=function(_,event)
        if event and event.StopPropagation then event:StopPropagation() end
        if not owns(event) then return end
        local allowed=armed and ready() and primary(event);cancel()
        if allowed then action() end
    end
    -- Button overrides down/up without calling the Widget callbacks.
    if button then
        local down,up=node.OnPointerDown,node.OnPointerUp
        function node:OnPointerDown(event)
            self.props.onPointerDown(event)
            if down then down(self,event) end
        end
        function node:OnPointerUp(event)
            self.props.onPointerUp(event)
            if up then up(self,event) end
        end
    end
    return cancel
end
return P
