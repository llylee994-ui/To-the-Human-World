-- Layout policy only: CSS-sized UI, safe controls and retained reading state.
-- No session, inventory or save APIs belong in this module.
local R={}
function R.Metrics(viewport,safe)
    viewport=viewport or {w=1280,h=720};safe=safe or {}
    local left,right,top,bottom=safe.left or 0,safe.right or 0,safe.top or 0,safe.bottom or 0
    local w,h=math.max(1,viewport.w-left-right),math.max(1,viewport.h-top-bottom)
    return {x=left,y=top,w=w,h=h,compact=w<1000 or h<520,short=h<520,
        gap=h<440 and 8 or 12,touch=44,body=18,caption=14,
        drawer=math.min(w-24,math.max(280,math.min(460,w*.42))),
        inset=h<440 and 8 or 16}
end
function R.SideWidth(viewport,safe,workbench)
    local m=R.Metrics(viewport,safe)
    return math.floor(m.compact and m.drawer or m.w*.26)
end
function R.CaptureScroll(root)
    local result={}
    local function visit(node,path)
        if node.GetScroll then
            local x,y=node:GetScroll();result[path]={x=x,y=y}
        end
        for i=1,node:GetNumChildren() do
            local child=node:GetChildAt(i)
            visit(child,path.."/"..tostring(child.props.id or i))
        end
    end
    visit(root,"");return result
end
function R.RestoreScroll(root,saved)
    local function visit(node,path)
        local position=saved[path]
        if position and node.SetScrollDirect then node:SetScrollDirect(position.x,position.y) end
        for i=1,node:GetNumChildren() do
            local child=node:GetChildAt(i)
            visit(child,path.."/"..tostring(child.props.id or i))
        end
    end
    visit(root,"")
end
return R
