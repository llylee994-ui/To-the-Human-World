-- Composition rebuild from pixel-verified master image(2).png, 1672x941.
-- Door/back wall and the shelf/right wall form a corner; the table is not parallel to the doorway.
local S=require 'lab.Spatial'
local M={}
local function furniture(id)
    return id=='paper' or id:match('^table%.') or id:match('^shelf%.') or id:match('^jar%.') or id:match('^drawer%.') or id:match('^stove%.')
        or id:match('^art%.table%.') or id:match('^art%.drawer%.') or id:match('^art%.top%.') or id:match('^art%.linen%.')
        or id:match('^art%.jar%.') or id:match('^art%.bottle%.') or id:match('^art%.mortar') or id:match('^art%.pestle')
        or id:match('^art%.book%.') or id:match('^art%.tray%.') or id:match('^art%.vine%.') or id:match('^art%.herb%.')
end
local function turn(p) return {-1.2+(p[3]-1.4),p[2],0.45-(p[1]-1.6)} end
local function turnBox(b)
    local c=turn(S.Mul(S.Add(b.min,b.max),0.5)); local size=S.Sub(b.max,b.min)
    local new=S.Box(c,{size[3],size[2],size[1]},b.id); b.min,b.max=new.min,new.max
end
function M.Apply(world)
    for _,m in ipairs(world.meshes) do
        if m.id:match('^stove%.') then
            -- Undo the rejected study's undersized pot while preserving its final reference position.
            m.position={1.4+(m.position[1]-1.4)/0.8,1.18+(m.position[2]-1.18)/0.8,1.45+(m.position[3]-1.45)/0.8}
            for k=1,3 do m.size[k]=m.size[k]/0.8 end
        end
        if furniture(m.id) then
            if m.id:match('^art%.herb%.') then m.position[3]=m.position[3]-0.20 end
            m.position=turn(m.position); m.rotation[2]=m.rotation[2]+90
        elseif m.id:match('^net%.') then
            if m.id=='net.handle' then
                m.position={-4.168,m.position[2]*1.25,1.15}; m.size={m.size[1]*0.8,m.size[2]*1.25,m.size[3]*0.8}
            else
                m.position={-4.12+(m.position[1]+3.42)*0.6,2.0125+(m.position[2]-1.61)*0.6,1.15+(m.position[3]-2.75)*0.6}
                for k=1,3 do m.size[k]=m.size[k]*0.6 end
            end
        elseif m.id:match('^ship%.') then m.position[1]=m.position[1]+11
        elseif m.id:match('^coast%.') then m.position[1]=m.position[1]+18
        elseif m.id:match('^art%.lighthouse') then m.position[1]=12
        elseif m.id:match('^art%.lantern%.') then m.position[2]=m.position[2]+0.30
        elseif m.id=='room.rightWall' then m.position[1]=0.5
        elseif m.id=='wall.rightOfDoor' then m.position[1]=-0.525; m.size[1]=2.05
        elseif m.id:match('^art%.wall%.post') and m.position[1]>0 then m.position[1]=0.32
        elseif m.id:match('^art%.wall%.rail') then m.position[1]=-0.55; m.size[1]=1.9
        elseif m.id=='room.beam.4.35' then m.position[1]=0.35
        end
    end
    for _,b in ipairs(world.occluders) do
        if furniture(b.id) then turnBox(b)
        elseif b.id=='room.rightWall' then b.min[1]=0.4; b.max[1]=0.6
        elseif b.id=='wall.rightOfDoor' then b.min[1]=-1.55; b.max[1]=0.5 end
    end
    for _,b in ipairs(world.proxies) do
        if b.id=='home.stove' or b.id=='home.letterPaper' or b.id=='home.drawer' then turnBox(b)
        elseif b.id=='home.merchantShip' then b.min[1]=b.min[1]+11; b.max[1]=b.max[1]+11
        elseif b.id=='home.net' then b.min={-4.39,0.02,1.00}; b.max={-3.87,2.30,1.32} end
    end
    world.rim.center=turn({1.4,1.94,1.45}); world.rim.radius=0.37
    world.referenceLayout='master-20261012-corner-v01'
    return world
end
return M
