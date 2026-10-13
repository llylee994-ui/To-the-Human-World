local M={}
function M.Finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
function M.Add(a,b) return {a[1]+b[1],a[2]+b[2],a[3]+b[3]} end
function M.Sub(a,b) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
function M.Mul(a,s) return {a[1]*s,a[2]*s,a[3]*s} end
function M.Dot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
function M.Cross(a,b) return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]} end
function M.Unit(a) local n=math.sqrt(M.Dot(a,a)); assert(n>1e-10,"zero direction");return M.Mul(a,1/n) end
function M.Convert(a,scale)
    local out={a[1]*(scale or 1),a[3]*(scale or 1),-a[2]*(scale or 1)}
    for _,n in ipairs(out) do assert(M.Finite(n),"coordinate conversion overflow") end
    return out
end
function M.Triangle(origin,direction,a,b,c)
    local e1,e2=M.Sub(b,a),M.Sub(c,a)
    local h=M.Cross(direction,e2);local det=M.Dot(e1,h)
    if math.abs(det)<1e-10 then return end
    local s=M.Sub(origin,a);local u=M.Dot(s,h)/det
    if u<0 or u>1 then return end
    local q=M.Cross(s,e1);local v=M.Dot(direction,q)/det
    if v<0 or u+v>1 then return end
    local t=M.Dot(e2,q)/det;if t>=0 then return t,u,v end
end
function M.Sphere(origin,direction,center,radius)
    local o=M.Sub(origin,center);local b=M.Dot(o,direction)
    local c=M.Dot(o,o)-radius*radius;local d=b*b-c
    if d<0 then return end
    local t=-b-math.sqrt(d);if t<0 then t=-b+math.sqrt(d) end
    if t>=0 then return t end
end
return M
