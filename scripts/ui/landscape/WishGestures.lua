-- Pointer-owned gestures: preview while moving, persist exactly once on release.
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local U=require "core.StateUtil"
local C=require "systems.WishCollage"
local P=require "ui.landscape.WishPaper"
local G={}
function G.Bind(view,ctx,paper,rows,words,select,commit)
    local drag=false --[[@as table|false]]
    local focused=true --[[@as boolean]]
    local rect=paper.rect
    local function index(id) for i,row in ipairs(rows) do if C.Id(row)==id then return i end end end
    local handles={}
    local function stop(e) if e.StopPropagation then e:StopPropagation() end end
    local function xy(e,node) local b=node:GetAbsoluteLayout();return b.x+e.x,b.y+e.y end
    local function preview(id,row)
        local card=paper.cards[id]
        Widget.SetStyle(card.root,{left=row.x*rect.w-card.width/2,top=row.y*rect.h-card.height/2})
        card.visual.props.rotate=row.angle;card.visual.props.scale=(row.scale or 1)/(card.display.scale or 1)
    end
    local function cancel()
        if drag then preview(drag.id,paper.cards[drag.id].display) end
        drag=false;view.busy=false
    end
    local function bind(node,id,mode)
        node.props.onPointerDown=function(e)
            stop(e)
            if not focused or not view.Live() or view.committed or drag or (e.IsPrimaryAction and not e:IsPrimaryAction()) or e.isPrimary==false then return end
            local i=index(id);if not i then return end
            select(id)
            if rows[i].locked then return end
            local x,y=xy(e,node);local card=paper.cards[id];local b=card.root:GetAbsoluteLayout()
            local cx,cy=b.x+card.width/2,b.y+card.height/2
            drag={id=id,index=i,mode=mode,pointer=e.pointerId,x=x,y=y,cx=cx,cy=cy,
                distance=math.max(8,math.sqrt((x-cx)^2+(y-cy)^2)),theta=math.atan(y-cy,x-cx),
                origin=U.Copy(card.display),row=U.Copy(rows[i])}
            view.busy=true
        end
        node.props.onPointerMove=function(e)
            stop(e);if not drag or drag.id~=id or drag.mode~=mode or drag.pointer~=e.pointerId then return end
            local x,y=xy(e,node);local row=U.Copy(drag.origin)
            if mode=="move" then row.x=row.x+(x-drag.x)/rect.w;row.y=row.y+(y-drag.y)/rect.h
            elseif mode=="scale" then
                row.scale=math.max(.25,math.min(3,(row.scale or 1)*math.sqrt((x-drag.cx)^2+(y-drag.cy)^2)/drag.distance))
            else
                row.angle=((row.angle+math.deg(math.atan(y-drag.cy,x-drag.cx)-drag.theta)+180)%360)-180
            end
            drag.moved=math.abs(x-drag.x)+math.abs(y-drag.y)>3 or drag.moved
            drag.row=P.Clamp(row,words[id],rect.w,rect.h);preview(id,drag.row)
        end
        node.props.onPointerUp=function(e)
            stop(e);if not drag or drag.id~=id or drag.mode~=mode or drag.pointer~=e.pointerId then return end
            if not view.Live() then cancel();return end
            local row,i,moved=drag.row,drag.index,drag.moved
            cancel()
            if moved then local nextRows=U.Copy(rows);nextRows[i]=row;commit(nextRows) end
        end
        node.props.onPointerCancel=function(e) stop(e);if drag and drag.pointer==e.pointerId then cancel() end end
        node.props.onClick=function() end
    end
    for id,card in pairs(paper.cards) do bind(card.root,id,"move") end
    for _,mode in ipairs({"rotate","scale"}) do
        local h=UI.Panel {id="wishHandle_"..mode,position="absolute",width=38,height=38,
            backgroundColor={250,240,214,250},borderWidth=1,borderColor={145,104,56,225},borderRadius=19,
            visible=false,zIndex=1000001,pointerEvents="auto"}
        function h:Render(vg)
            local r=self:GetAbsoluteLayout();local x,y=r.x+r.w/2,r.y+r.h/2
            nvgBeginPath(vg)
            if mode=="rotate" then
                for i=0,20 do
                    local a=math.rad(-55+i*13);local px,py=x+math.cos(a)*9,y+math.sin(a)*9
                    if i==0 then nvgMoveTo(vg,px,py) else nvgLineTo(vg,px,py) end
                end
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
    local function updateHandles(id)
        local i=index(id);local card=paper.cards[id]
        for mode,h in pairs(handles) do
            h:SetVisible(i~=nil and not rows[i].locked)
            if card then
                Widget.SetStyle(h,{left=card.display.x*rect.w+card.width/2+5,
                    top=card.display.y*rect.h+(mode=="rotate" and -card.height/2-36 or card.height/2-2)})
                bind(h,id,mode)
            end
        end
    end
    local vp=U.Copy(ctx.viewport or {w=1280,h=720})
    return {Select=updateHandles,Cancel=cancel,Update=function(_,hasFocus)
        focused=hasFocus
        local next=ctx.viewport or vp
        if not focused or next.w~=vp.w or next.h~=vp.h then cancel() end
    end}
end
return G
