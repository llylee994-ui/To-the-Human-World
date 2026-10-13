-- Reference mathematics only. This does not prove native camera semantics.
local V=require "v035.lab35.Math3"
local C={}
function C.Frame(blender)
    local forward=V.Unit(V.Convert(blender.forward))
    local up=V.Unit(V.Convert(blender.up))
    assert(math.abs(V.Dot(forward,up))<.00001,"camera forward/up are not orthogonal")
    local right=V.Unit(V.Convert(V.Cross(blender.forward,blender.up)))
    local backward=V.Mul(forward,-1)
    return {position=V.Convert(blender.position),forward=forward,up=up,right=right,backward=backward,
        rhNodeBasisDeterminant=V.Dot(V.Cross(right,up),backward),
        desiredLhNodeBasisDeterminant=V.Dot(V.Cross(right,up),forward),
        conventionalLhRightDot=V.Dot(right,V.Unit(V.Cross(up,forward)))}
end
function C.Project(frame,point,horizontalFovRadians,aspect)
    assert(horizontalFovRadians>0 and horizontalFovRadians<math.pi and aspect>0,"invalid perspective parameters")
    local delta=V.Sub(point,frame.position);local depth=V.Dot(delta,frame.forward)
    if depth<=0 then return end
    local halfWidth=math.tan(horizontalFovRadians/2)*depth
    return {.5+V.Dot(delta,frame.right)/(2*halfWidth),.5-V.Dot(delta,frame.up)*aspect/(2*halfWidth)},depth
end
return C
