-- Pure geometry shared by drawing, hit testing and offline evidence.
local G={}
---@param bounds table
---@param manifest table
function G.Fit(bounds,manifest)
    local scale=math.min(bounds.w/manifest.width,bounds.h/manifest.height)
    return {x=bounds.x+(bounds.w-manifest.width*scale)/2,y=bounds.y+(bounds.h-manifest.height*scale)/2,
        w=manifest.width*scale,h=manifest.height*scale,scale=scale}
end
-- Keep the complete room/dock, including the ceiling, at its original aspect.
-- Backdrop extensions fill the spare space; input uses the same contained fit.
function G.RoomFit(bounds,manifest)
    local fit=G.Fit(bounds,manifest)
    fit.clip={x=bounds.x,y=bounds.y,w=bounds.w,h=bounds.h}
    return fit
end
-- Sea/dock retains its existing full-width projection.
function G.SceneFit(bounds,manifest)
    if bounds.w<=0 or bounds.h<=0 then return G.Fit(bounds,manifest) end
    if bounds.w/bounds.h<manifest.width/manifest.height then return G.Fit(bounds,manifest) end
    local scale=bounds.w/manifest.width
    return {x=bounds.x,y=bounds.y+bounds.h-manifest.height*scale,w=bounds.w,h=manifest.height*scale,scale=scale,
        clip={x=bounds.x,y=bounds.y,w=bounds.w,h=bounds.h}}
end
function G.Rotate(x,y,degrees)
    local a=math.rad(degrees); local c,s=math.cos(a),math.sin(a)
    return x*c-y*s,x*s+y*c
end
function G.ToScreen(layer,fit,u,v)
    local x,y=G.Rotate((u-.5)*layer.width,(v-.5)*layer.height,layer.rotation)
    return fit.x+(layer.x+x)*fit.scale,fit.y+(layer.y+y)*fit.scale
end
function G.ToLocal(layer,fit,x,y)
    if fit.scale<=0 then return 0,0 end
    return G.Rotate((x-fit.x)/fit.scale-layer.x,(y-fit.y)/fit.scale-layer.y,-layer.rotation)
end
---@param minTouch number|nil
function G.Region(layer,region,fit,minTouch)
    -- The caller supplies the minimum for this specific region.
    local minimum=(minTouch or 0)/math.max(.00001,fit.scale)
    return {x=(region.cx-.5)*layer.width,y=(region.cy-.5)*layer.height,
        w=math.max(region.w*layer.width,minimum),h=math.max(region.h*layer.height,minimum),
        rotation=region.rotation or 0,kind=region.kind}
end
function G.ObjectRegion(layer,object,fit,index)
    local region=object.regions[index]
    -- Existing objects protect only their primary subject. Extra regions opt in.
    local minimum=region.minTouch or (index==1 and object.minTouch or 0)
    local r=G.Region(layer,region,fit,minimum)
    if region.keepInsideCanvas and fit.scale>0 then
        -- Move only the effective hit region inward when its minimum would be clipped.
        -- Visual transforms and the source region center remain unchanged.
        local a=math.rad(layer.rotation+r.rotation)
        local c,s=math.cos(a),math.sin(a)
        local ex,ey
        if r.kind=="ellipse" then
            ex=math.sqrt((r.w*c)^2+(r.h*s)^2)/2
            ey=math.sqrt((r.w*s)^2+(r.h*c)^2)/2
        else
            ex=(math.abs(r.w*c)+math.abs(r.h*s))/2
            ey=(math.abs(r.w*s)+math.abs(r.h*c))/2
        end
        local x,y=G.Rotate(r.x,r.y,layer.rotation)
        x=math.max(ex,math.min(fit.w/fit.scale-ex,layer.x+x))
        y=math.max(ey,math.min(fit.h/fit.scale-ey,layer.y+y))
        r.x,r.y=G.Rotate(x-layer.x,y-layer.y,-layer.rotation)
    end
    return r
end
function G.InRegion(x,y,r)
    local dx,dy=G.Rotate(x-r.x,y-r.y,-r.rotation)
    if r.kind=="ellipse" then return (dx/(r.w/2))^2+(dy/(r.h/2))^2<=1 end
    return math.abs(dx)<=r.w/2 and math.abs(dy)<=r.h/2
end
function G.HitObject(manifest,object,fit,x,y)
    local clip=fit.clip
    if clip and (x<clip.x or y<clip.y or x>clip.x+clip.w or y>clip.y+clip.h) then return false end
    if fit.scale<=0 or x<fit.x or y<fit.y or x>fit.x+fit.w or y>fit.y+fit.h then return false end
    local layer=manifest.layers[object.layer]
    if not layer.visible then return false end
    local lx,ly=G.ToLocal(layer,fit,x,y)
    for i in ipairs(object.regions) do
        if G.InRegion(lx,ly,G.ObjectRegion(layer,object,fit,i)) then return true end
    end
    return false
end
function G.Pick(manifest,fit,x,y)
    for i=#manifest.objects,1,-1 do
        if G.HitObject(manifest,manifest.objects[i],fit,x,y) then return manifest.objects[i] end
    end
end
return G
