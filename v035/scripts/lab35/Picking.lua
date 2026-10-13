local V=require "lab35.Math3"
local P={}
function P.New(prepared,isOccluded)
    assert(type(isOccluded)=="function","explicit occlusion query required; no through-wall fallback")
    local api={}
    function api.Pick(origin,direction)
        direction=V.Unit(direction)
        local best,bestDistance
        for _,anchor in ipairs(prepared.anchors) do
            local p=anchor.proxy;local distance
            if p and p.kind=="sphere" then distance=V.Sphere(origin,direction,p.center,p.radius)
            elseif p and p.kind=="triangles" then
                for i=1,#p.indices,3 do
                    local t=V.Triangle(origin,direction,p.positions[p.indices[i]],p.positions[p.indices[i+1]],p.positions[p.indices[i+2]])
                    if t and (not distance or t<distance) then distance=t end
                end
            end
            if distance and (not bestDistance or distance<bestDistance) and not isOccluded(origin,direction,distance,anchor.id) then
                best,bestDistance=anchor.id,distance
            end
        end
        return best,bestDistance
    end
    return api
end
return P
