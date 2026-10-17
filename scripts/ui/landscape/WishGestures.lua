-- UI events already use stable base-pixel coordinates. Only visuals change before release.
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local U=require "core.StateUtil"
local C=require "systems.WishCollage"
local P=require "ui.landscape.WishPaper"
local Layout=require "ui.landscape.WishLayout"
local G={HandleSize=52,Slop=5}
local function stop(e) if e.StopPropagation then e:StopPropagation() end end
local function angle(x,y,cx,cy) return math.atan(y-cy,x-cx) end
local function normalize(a) return (a+180)%360-180 end
function G.Bind(view,ctx,paper,rows,words,select,commit)
    local drag=false --[[@as table|false]]
    local focused=true --[[@as boolean]]
    local ghost=false --[[@as table|false]]
    local rect=paper.rect;local workspace=view.interactionRect or rect;local handles={}
    local updateHandles
    local function index(id) for i,row in ipairs(rows) do if C.Id(row)==id then return i end end end
    local function live() return focused and view.Live() and not view.committed end
    local function cancel()
        if drag and drag.node.state then drag.node.state.dragging=false end
        if drag and drag.origin then paper.Preview(drag.id,drag.origin);if updateHandles then updateHandles(drag.id) end;select(drag.id,drag.origin) end
        if ghost then ghost.root:Destroy();ghost=false end
        drag=false;view.busy=false
    end
    local function begin(node,id,mode,e,factory)
        stop(e)
        if not live() or drag or e.isPrimary==false or e.IsPrimaryAction and not e:IsPrimaryAction() then return end
        local i=index(id)
        if mode~="source" and not i then return end
        if mode~="source" then select(id);if rows[i].locked then return end end
        local origin=i and U.Copy(paper.cards[id].display) or nil
        local cx,cy=origin and rect.x+origin.x*rect.w or e.x,origin and rect.y+origin.y*rect.h or e.y
        drag={id=id,index=i,mode=mode,node=node,pointer=e.pointerId,x=e.x,y=e.y,cx=cx,cy=cy,
            distance=math.max(8,math.sqrt((e.x-cx)^2+(e.y-cy)^2)),theta=angle(e.x,e.y,cx,cy),rotation=0,
            origin=origin,row=origin and U.Copy(origin) or factory(),moved=false}
        if mode=="source" then
            local b=node:GetAbsoluteLayout()
            drag.u=math.max(0,math.min(1,(e.x-b.x)/math.max(1,b.w)))
            drag.v=math.max(0,math.min(1,(e.y-b.y)/math.max(1,b.h)))
        end
        view.busy=true
    end
    local function move(node,e,force)
        stop(e)
        local d=drag;if not d or d.node~=node or d.pointer~=e.pointerId then return end
        if not live() then cancel();return end
        local dx,dy=e.x-d.x,e.y-d.y
        d.moved=d.moved or force or dx*dx+dy*dy>G.Slop^2
        if not d.moved then return end
        if d.mode=="source" then
            local w,h=P.Size(d.row,words[d.row.sourceTokenId],rect.w)
            local row=U.Copy(d.row)
            row.x=(e.x+(.5-d.u)*w)/rect.w;row.y=(e.y+(.5-d.v)*h)/rect.h
            if not ghost then
                local id=C.Id(row)
                ghost=P.New(view.root,{x=0,y=0,w=rect.w,h=rect.h},{placements={row},words=words},{id="wishDragGhost",ghost=true})
                ghost.root.props.zIndex=1000005;ghost.root.props.opacity=.9
                ghost.Preview(id,row)
            else ghost.Preview(C.Id(row),row) end
            d.row.x=row.x-rect.x/rect.w;d.row.y=row.y-rect.y/rect.h
        else
            local row=U.Copy(d.origin)
            if d.mode=="move" then row.x=row.x+dx/rect.w;row.y=row.y+dy/rect.h
            elseif d.mode=="scale" then row.scale=math.max(.25,math.min(3,(row.scale or 1)*math.sqrt((e.x-d.cx)^2+(e.y-d.cy)^2)/d.distance))
            else
                local theta=angle(e.x,e.y,d.cx,d.cy)
                d.rotation=d.rotation+normalize(math.deg(theta-d.theta));d.theta=theta
                row.angle=normalize(d.origin.angle+d.rotation)
            end
            d.row=P.Clamp(row,words[d.id],rect.w,rect.h)
            paper.Preview(d.id,d.row);updateHandles(d.id);select(d.id,d.row)
        end
    end
    local function release(node,e)
        stop(e)
        local d=drag;if not d or d.node~=node or d.pointer~=e.pointerId then return end
        if not live() then cancel();return end
        move(node,e)
        local row=U.Copy(d.row);local moved=d.moved;local source=d.mode=="source"
        local area=d.row.freePlacement and workspace or rect
        local inside=e.x>=area.x and e.x<=area.x+area.w and e.y>=area.y and e.y<=area.y+area.h
        local i=d.index;cancel()
        if not moved or source and not inside then return end
        local nextRows=U.Copy(rows)
        if source then
            if #rows>=128 or index(C.Id(row)) then return end
            local z=#rows;for j,r in ipairs(rows) do z=math.max(z,C.Depth(r,j)) end
            row.z=math.min(999999,z+1);nextRows[#nextRows+1]=P.Clamp(row,words[row.sourceTokenId],rect.w,rect.h)
        else nextRows[i]=row end
        select(C.Id(row),row)
        if not commit(nextRows) then select(source and false or d.id) end
    end
    local function bind(node,id,mode,factory)
        node.props.onPointerDown=function(e) begin(node,id,mode,e,factory) end
        node.props.onPointerMove=function(e) move(node,e) end
        node.props.onPointerUp=function(e) release(node,e) end
        node.props.onPointerCancel=function(e) stop(e);if drag and drag.pointer==e.pointerId then cancel() end end
        node.props.onClick=function() end
        function node:OnPanStart(e)
            if not drag or drag.node~=self or drag.pointer~=e.pointerId then return false end
            self.state=self.state or {};self.state.dragging=true;move(self,e,true);return true
        end
        function node:OnPanMove(e) move(self,e,true) end
        function node:OnPanEnd(e) self.state.dragging=false;release(self,e) end
    end
    for id,card in pairs(paper.cards) do bind(card.root,id,"move") end
    for _,mode in ipairs({"rotate","scale"}) do
        local h=UI.Panel {id="wishHandle_"..mode,position="absolute",width=G.HandleSize,height=G.HandleSize,
            backgroundColor={250,240,214,250},borderWidth=1,borderColor={145,104,56,225},borderRadius=G.HandleSize/2,
            visible=false,zIndex=1000002,pointerEvents="auto"}
        function h:Render(vg)
            self:RenderFullBackground(vg)
            local r=self:GetAbsoluteLayout();local x,y=r.x+r.w/2,r.y+r.h/2
            nvgBeginPath(vg)
            if mode=="rotate" then
                for i=0,20 do local a=math.rad(-55+i*13);local px,py=x+math.cos(a)*9,y+math.sin(a)*9
                    if i==0 then nvgMoveTo(vg,px,py) else nvgLineTo(vg,px,py) end end
                nvgMoveTo(vg,x+5,y-9);nvgLineTo(vg,x+10,y-9);nvgLineTo(vg,x+10,y-3)
            else
                nvgMoveTo(vg,x-7,y+7);nvgLineTo(vg,x+7,y-7)
                nvgMoveTo(vg,x,y-7);nvgLineTo(vg,x+7,y-7);nvgLineTo(vg,x+7,y)
                nvgMoveTo(vg,x-7,y);nvgLineTo(vg,x-7,y+7);nvgLineTo(vg,x,y+7)
            end
            nvgStrokeWidth(vg,1.8);nvgStrokeColor(vg,nvgRGBA(117,82,41,255));nvgStroke(vg)
        end
        paper.root:AddChild(h);handles[mode]=h
    end
    updateHandles=function(id)
        local i=index(id);local card=paper.cards[id]
        for mode,h in pairs(handles) do
            h:SetVisible(i~=nil and not rows[i].locked)
            if card then
                local b=P.Bounds(card.display,words[id],rect)
                local r=Layout.Handle(b,workspace,mode,G.HandleSize)
                Widget.SetStyle(h,{left=r.x-rect.x,top=r.y-rect.y});bind(h,id,mode)
            end
        end
    end
    local vp=U.Copy(ctx.viewport or {w=1280,h=720});local safe=U.Copy(ctx.safeInsets or {})
    return {Select=updateHandles,Cancel=cancel,Source=function(node,factory) bind(node,false,"source",factory) end,
        Update=function(dt,hasFocus)
            focused=hasFocus
            local next=ctx.viewport or vp
            if not focused or dt<0 or dt>.5 or ctx.portrait or next.w~=vp.w or next.h~=vp.h or not U.Equal(safe,ctx.safeInsets or {}) then cancel() end
        end}
end
return G
