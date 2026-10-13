-- Pure spatial math, shared by picking, camera control and offline path checks.
local S={}
function S.Add(a,b) return {a[1]+b[1],a[2]+b[2],a[3]+b[3]} end
function S.Sub(a,b) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
function S.Mul(a,k) return {a[1]*k,a[2]*k,a[3]*k} end
function S.Dot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
function S.Length(a) return math.sqrt(S.Dot(a,a)) end
function S.Unit(a) local n=S.Length(a); assert(n>1e-8); return S.Mul(a,1/n) end
function S.Lerp(a,b,t) return S.Add(a,S.Mul(S.Sub(b,a),t)) end
function S.Cross(a,b) return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]} end
-- AABBs: min/max in world metres. Ray slab test includes inside-box starts.
function S.RayBox(origin,direction,box)
    local near,far=0.0,math.huge
    for i=1,3 do
        if math.abs(direction[i])<1e-9 then
            if origin[i]<box.min[i] or origin[i]>box.max[i] then return nil end
        else
            local a,b=(box.min[i]-origin[i])/direction[i],(box.max[i]-origin[i])/direction[i]
            if a>b then a,b=b,a end
            near=math.max(near,a); far=math.min(far,b)
            if near>far then return nil end
        end
    end
    return near
end
function S.Box(center,size,id)
    return {id=id,min=S.Sub(center,S.Mul(size,0.5)),max=S.Add(center,S.Mul(size,0.5))}
end
function S.InBox(point,box,margin)
    for i=1,3 do if point[i]<box.min[i]-margin or point[i]>box.max[i]+margin then return false end end
    return true
end
function S.Project(position,look,point,fov,aspect)
    local forward=S.Unit(S.Sub(look,position)); local right=S.Unit(S.Cross({0,1,0},forward)); local up=S.Cross(forward,right)
    local delta=S.Sub(point,position); local depth=S.Dot(delta,forward)
    if depth<=0 then return nil end
    local h=math.tan(math.rad(fov)/2)*depth
    return {0.5+S.Dot(delta,right)/(2*h*aspect),0.5-S.Dot(delta,up)/(2*h),depth}
end
return S
