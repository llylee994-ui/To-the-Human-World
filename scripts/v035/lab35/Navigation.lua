-- Missing optional 3D poses must not disable existing main gameplay pages.
local V=require "v035.lab35.Math3"
local U=require "v035.core.StateUtil"
local N={}
function N.New(cameras,getPose,setPose,home,onRoute)
    local n={active=false}
    local names={home="Home",brew="Brew",seaside="Seaside"}
    function n.Start(_,target,done)
        if n.active or not names[target] then return false end
        local destination=cameras[names[target]]
        if not destination then
            -- Retain the calibrated Home behind the original 2D page. No
            -- receive, brew, reward or storage command is issued here.
            setPose(U.Copy(home))
            if onRoute then onRoute(target,"existing-main-ui",false) end
            done(true);return true
        end
        n.active=true;n.elapsed=0;n.from=U.Copy(getPose());n.to=U.Copy(destination)
        n.to.handedness=home.handedness;n.to.lookSign=home.lookSign;n.done=done
        if onRoute then onRoute(target,"3d-camera",true) end
        return true
    end
    function n.Cancel() n.active=false end
    function n.Update(dt)
        if not n.active then return end
        n.elapsed=math.min(1.5,n.elapsed+math.min(dt,.1));local t=n.elapsed/1.5;t=t*t*(3-2*t)
        local pose=U.Copy(n.to);pose.position=V.Add(V.Mul(n.from.position,1-t),V.Mul(n.to.position,t))
        pose.forward=V.Unit(V.Add(V.Mul(n.from.forward,1-t),V.Mul(n.to.forward,t)))
        local up=V.Add(V.Mul(n.from.up,1-t),V.Mul(n.to.up,t))
        pose.up=V.Unit(V.Sub(up,V.Mul(pose.forward,V.Dot(up,pose.forward))))
        setPose(pose)
        if n.elapsed>=1.5 then n.active=false;n.done(true) end
    end
    return n
end
return N
