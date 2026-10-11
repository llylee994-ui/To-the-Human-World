-- Pure geometry shared by drawing, hit testing and offline evidence.
local G={}
---@param bounds table
---@param manifest table
function G.Fit(bounds,manifest)
    local scale=math.min(bounds.w/manifest.width,bounds.h/manifest.height)
    return {x=bounds.x+(bounds.w-manifest.width*scale)/2,y=bounds.y+(bounds.h-manifest.height*scale)/2,
        w=manifest.width*scale,h=manifest.height*scale,scale=scale}
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
    -- Only enlarge the primary subject; secondary components keep precise geometry.
    local minimum=(minTouch or 0)/math.max(.00001,fit.scale)
    return {x=(region.cx-.5)*layer.width,y=(region.cy-.5)*layer.height,
        w=math.max(region.w*layer.width,minimum),h=math.max(region.h*layer.height,minimum),
        rotation=region.rotation or 0,kind=region.kind}
end
function G.InRegion(x,y,r)
    local dx,dy=G.Rotate(x-r.x,y-r.y,-r.rotation)
    if r.kind=="ellipse" then return (dx/(r.w/2))^2+(dy/(r.h/2))^2<=1 end
    return math.abs(dx)<=r.w/2 and math.abs(dy)<=r.h/2
end
function G.HitObject(manifest,object,fit,x,y)
    if fit.scale<=0 or x<fit.x or y<fit.y or x>fit.x+fit.w or y>fit.y+fit.h then return false end
    local layer=manifest.layers[object.layer]
    if not layer.visible then return false end
    local lx,ly=G.ToLocal(layer,fit,x,y)
    for i,region in ipairs(object.regions) do
        if G.InRegion(lx,ly,G.Region(layer,region,fit,i==1 and object.minTouch or 0)) then return true end
    end
    return false
end
function G.Pick(manifest,fit,x,y)
    for i=#manifest.objects,1,-1 do
        if G.HitObject(manifest,manifest.objects[i],fit,x,y) then return manifest.objects[i] end
    end
end
return G
