-- Native diagnostics, not an offline claim that either handedness is correct.
local C={}
function C.Run(camera,node,home,raw,aspect)
    local V=require "v035.lab35.Math3"
    local Native=require "v035.lab35.NativeGeometry"
    local U=require "v035.core.StateUtil"
    local referenceAspect=raw.camera.resolution[1]/raw.camera.resolution[2]
    local reference=require("v035.lab35.CameraMath").Frame(raw.camera)
    local mappedRight=reference.right
    local candidates,best={},nil
    for _,hand in ipairs({HANDEDNESS_LH,HANDEDNESS_RH}) do
        for _,sign in ipairs({1,-1}) do
            local pose=U.Copy(home);pose.handedness=hand;pose.lookSign=sign
            Native.ApplyCamera(camera,node,pose,aspect)
            local center=camera:GetScreenRay(.5,.5).direction
            local side=camera:GetScreenRay(.51,.5).direction
            local centerVector={center.x,center.y,center.z}
            local sideDelta=V.Sub({side.x,side.y,side.z},centerVector)
            local screenRight=V.Unit(V.Sub(sideDelta,V.Mul(centerVector,V.Dot(sideDelta,centerVector))))
            local nodeRight=node.worldRight
            local row={handedness=hand,lookSign=sign,centerDot=V.Dot(centerVector,home.forward),points={},pointError=0,rayError=0,pose=pose,
                mappedRight=mappedRight,screenRightDot=V.Dot(mappedRight,screenRight),nodeRightDot=V.Dot(mappedRight,{nodeRight.x,nodeRight.y,nodeRight.z}),
                upCrossForwardDot=V.Dot(mappedRight,V.Unit(V.Cross(home.up,home.forward)))}
            if row.centerDot>.999 then
                for _,a in ipairs(raw.interactionProxies) do
                    local point=V.Convert(a.position)
                    local expected={a.screenAnchor[1],.5+(a.screenAnchor[2]-.5)*aspect/referenceAspect}
                    local uv=assert(Native.ScreenUV(camera,node,point),"forward point cannot be projected")
                    local legacy=camera:WorldToScreenPoint(Vector3(point[1],point[2],point[3]))
                    local ray=camera:GetScreenRay(expected[1],expected[2]).direction
                    local target=V.Unit(V.Sub(point,home.position))
                    local dot=V.Dot({ray.x,ray.y,ray.z},target)
                    row.pointError=row.pointError+(uv.x-expected[1])^2+(uv.y-expected[2])^2
                    row.rayError=row.rayError+(1-dot)^2
                    row.points[#row.points+1]={id=a.id,expected=expected,actual={uv.x,uv.y},legacyWorldToScreen={legacy.x,legacy.y},rayDot=dot}
                end
                if not best or row.rayError<best.rayError then best=row end
            end
            candidates[#candidates+1]=row
        end
    end
    assert(best,"no forward-facing native camera candidate")
    Native.ApplyCamera(camera,node,best.pose,aspect)
    return best.pose,{ok=best.pointError<.00001 and best.rayError<.0000001 and best.screenRightDot>.999,
        referenceBasis=reference,candidates=candidates,
        pointError=best.pointError,rayError=best.rayError,handedness=best.handedness,lookSign=best.lookSign}
end
return C
