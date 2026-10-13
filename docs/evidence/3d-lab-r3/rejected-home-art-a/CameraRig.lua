local S=require "lab.Spatial"
local R={}
---@class LabPose
---@field position number[]
---@field look number[]
---@class LabRig : LabPose
---@field mode string
---@field busy boolean
---@field nearClip number
---@field fov number
---@field completed integer
---@field Go fun(mode:string):boolean
---@field Update fun(dt:number):boolean
---@type table<string,LabPose>
R.views={
    Home={position={0.30,2.45,-2.40},look={0.10,1.50,2.50}},
    Seaside={position={-2.65,1.85,6.2},look={-4.8,1.6,22}},
    Brew={position={1.65,2.35,-0.8},look={1.65,1.65,1.6}},
}
local doorApproach={position={-2.65,1.85,1.4},look={-3.1,1.6,12}}
local doorExit={position={-2.65,1.85,4.3},look={-4,1.6,18}}
function R.New()
    ---@type LabRig
    local rig={mode="Home",busy=false,position=R.views.Home.position,look=R.views.Home.look,nearClip=0.08,fov=54,completed=0}
    ---@type LabPose[]
    local route={}
    local index,time,target=1,0.0,"Home"
    function rig.Go(mode)
        if rig.busy or mode==rig.mode or not R.views[mode] then return false end
        -- Seaside/Brew never cut through the wall/table: return via Home.
        local points={{position=rig.position,look=rig.look}}
        if rig.mode=="Seaside" then points[#points+1]=doorExit; points[#points+1]=doorApproach end
        if rig.mode~="Home" and mode~="Home" then points[#points+1]=R.views.Home end
        if mode=="Seaside" then points[#points+1]=doorApproach; points[#points+1]=doorExit end
        points[#points+1]=R.views[mode]
        route,index,time,target=points,1,0,mode; rig.busy=true
        return true
    end
    function rig.Update(dt)
        if not rig.busy then return false end
        -- Consume overshoot: frame stalls don't teleport or reverse the camera.
        time=time+math.max(0,dt)
        while rig.busy do
            local a,b=assert(route[index]),assert(route[index+1])
            local duration=math.max(0.65,S.Length(S.Sub(b.position,a.position))/2.6)
            if time<duration then
                local t=time/duration; local smooth=t*t*(3-2*t)
                rig.position=S.Lerp(a.position,b.position,smooth); rig.look=S.Lerp(a.look,b.look,smooth)
                break
            end
            rig.position,rig.look=b.position,b.look; time=time-duration; index=index+1
            if index==#route then rig.mode=target; rig.busy=false; rig.completed=rig.completed+1 end
        end
        return true
    end
    return rig
end
return R
