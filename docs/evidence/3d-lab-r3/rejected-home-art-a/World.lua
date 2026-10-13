-- Adjustable defaults from written spatial constraints ONLY.
-- Latest Library pixels are not materialized: these are not reference-approved shapes.
local S=require "lab.Spatial"
local W={}
function W.Build()
    local world={meshes={},occluders={},proxies={},rim={center={1.8,1.94,1.45},radius=0.37}}
    local function mesh(id,shape,position,size,material,rotation,params)
        local m={id=id,shape=shape,position=position,size=size,material=material,rotation=rotation or {0,0,0},params=params}
        world.meshes[#world.meshes+1]=m; return m
    end
    local function box(id,p,s,mat,blocking)
        local m=mesh(id,"box",p,s,mat)
        if blocking then world.occluders[#world.occluders+1]=S.Box(p,s,id) end
        return m
    end
    -- Room 8.8m wide, x [-4.4,4.4], back ocean wall z=3.5.
    -- Door x [-3.75,-1.55], y [0,3.4]; no step. Pier top == floor top == 0.
    -- Blocking boxes are shared with offline camera clearance checks and picking.
    box("room.floor",{0,-0.14,-0.6},{8.8,0.28,8.2},"wood",true)
    box("room.leftWall",{-4.5,2,-0.6},{0.2,4,8.4},"plaster",true)
    box("room.rightWall",{4.5,2,-0.6},{0.2,4,8.4},"plaster",true)
    box("wall.leftOfDoor",{-4.125,2,3.55},{0.75,4,0.2},"plaster",true)
    box("wall.rightOfDoor",{1.475,2,3.55},{6.05,4,0.2},"plaster",true)
    box("wall.aboveDoor",{-2.65,3.8,3.55},{2.2,0.4,0.2},"plaster",true)
    box("door.left",{-3.84,1.8,3.42},{0.18,3.6,0.34},"darkWood",true)
    box("door.right",{-1.46,1.8,3.42},{0.18,3.6,0.34},"darkWood",true)
    box("door.lintel",{-2.65,3.53,3.42},{2.56,0.18,0.34},"darkWood",true)
    box("door.threshold",{-2.65,0.015,3.45},{2.2,0.03,0.42},"wood",true)
    for i=0,19 do
        local z=3.72+i*0.39
        box("dock.plank."..i,{-2.65,-0.1,z},{2.15,0.2,0.37},i%3==0 and "woodLight" or "wood",true)
    end
    for i=0,3 do
        for _,x in ipairs({-3.83,-1.47}) do box("dock.post."..i.."."..x,{x,0.36,4+i*2.2},{0.16,1.4,0.16},"darkWood",true) end
    end
    for i=0,15 do box("floor.seam."..i,{-4.12+i*0.55,0.003,-0.6},{0.018,0.006,8.1},"darkWood",false) end
    for _,x in ipairs({-4.35,4.35}) do box("room.beam."..x,{x,3.83,-0.6},{0.22,0.24,8.2},"darkWood",false) end
    box("table.top",{1.6,1.06,1.4},{4.4,0.18,2.0},"woodLight",true)
    for _,x in ipairs({-0.4,3.6}) do for _,z in ipairs({0.65,2.15}) do box("table.leg."..x.."."..z,{x,0.51,z},{0.17,1.02,0.17},"wood",true) end end
    for i=0,9 do box("table.grain."..i,{-0.42+i*0.44,1.153,1.4},{0.014,0.005,1.96},"wood",false) end
    for _,y in ipairs({1.27,1.96,2.65}) do box("shelf.level."..y,{1.65,y,2.23},{4.0,0.11,0.40},"wood",true) end
    for _,x in ipairs({-0.30,3.60}) do box("shelf.upright."..x,{x,1.91,2.30},{0.12,1.6,0.20},"darkWood",true) end
    for level=1,2 do for i=0,6 do
        local x,y=-0.05+i*0.54,1.38+(level-1)*0.69
        mesh("jar."..level.."."..i,"lathe",{x,y,2.2},{1,1,1},i%2==0 and "ceramic" or "greenGlaze",nil,
            {{0,-0.01},{0.13,0},{0.16,0.08},{0.15,0.26},{0.08,0.31},{0.08,0.34},{0,0.34}})
        mesh("jar.lid."..level.."."..i,"cylinder",{x,y+0.355,2.2},{0.18,0.03,0.18},"wood")
    end end
    box("paper",{0.40,1.168,0.82},{0.70,0.025,0.45},"paper",false)
    box("drawer.front",{0.42,0.85,0.34},{0.95,0.25,0.09},"wood",false)
    mesh("drawer.pull","sphere",{0.42,0.85,0.27},{0.09,0.06,0.06},"copper")
    -- One pot, rim and feet remain in this same world in every view.
    mesh("stove.bowl","lathe",{1.8,1.40,1.45},{1,1,1},"copper",nil,
        {{0,0},{0.22,0.02},{0.38,0.15},{0.46,0.36},{0.45,0.52},{0.40,0.54},{0.385,0.50},{0.39,0.36},{0.32,0.19},{0.18,0.07},{0,0.06}})
    mesh("stove.rim","torus",world.rim.center,{0.88,0.88,0.88},"copper",{90,0,0},{0.5,0.028,10,40})
    mesh("stove.liquid","cylinder",{1.8,1.91,1.45},{0.75,0.025,0.75},"herbal")
    for _,x in ipairs({1.27,2.33}) do mesh("stove.handle."..x,"torus",{x,1.75,1.45},{0.35,0.35,0.35},"copper",{0,90,0},{0.5,0.07,8,24}) end
    for i=0,2 do
        local angle=i*math.pi*2/3
        mesh("stove.foot."..i,"cylinder",{1.8+math.cos(angle)*0.25,1.285,1.45+math.sin(angle)*0.25},{0.045,0.29,0.045},"iron")
    end
    mesh("stove.burner","cylinder",{1.8,1.18,1.45},{0.24,0.045,0.24},"iron")
    mesh("stove.flame","sphere",{1.8,1.28,1.45},{0.085,0.14,0.085},"flame")
    mesh("net.handle","cylinder",{-3.50,0.73,2.75},{0.045,1.45,0.045},"wood",{0,0,-7})
    mesh("net.hoop","torus",{-3.42,1.61,2.75},{0.62,0.82,0.62},"woodLight",{0,-8,0},{0.5,0.03,8,32})
    for i=-3,3 do
        local p=i*0.072; local extent=math.sqrt(math.max(0,0.27*0.27-p*p))
        mesh("net.weave.v."..i,"cylinder",{-3.42+p,1.61,2.78},{0.009,extent*2.7,0.009},"rope")
        mesh("net.weave.h."..i,"cylinder",{-3.42,1.61+p*1.3,2.78},{0.009,extent*2,0.009},"rope",{0,0,90})
    end
    box("sea",{0,-0.32,37},{130,0.08,100},"sea",false)
    -- European sailboat prototype: a single hull, mast and two geometric sails.
    mesh("ship.hull","hull",{-6.5,0.04,22},{1,1,1},"wood",nil,
        {{-1.8,0,0},{-1.0,-0.4,-0.42},{1.3,-0.35,-0.35},{2,0,0},{1.3,0.35,0.35},{-1.1,0.35,0.45},{-1.8,0.35,0}})
    mesh("ship.mast","cylinder",{-6.6,2.0,22},{0.10,4.2,0.10},"darkWood")
    mesh("ship.sail.main","sail",{-6.58,0.65,22},{1,1,1},"sail",nil,{{0,0},{0,3.45},{1.8,0.2}})
    mesh("ship.sail.jib","sail",{-6.72,0.78,22},{1,1,1},"paper",nil,{{0,0},{0,3.1},{-1.5,0.25}})
    for i=0,7 do mesh("coast."..i,"sphere",{6+i*3,0.2,35+i%3},{6,2.5+i%3,6},"coast") end
    world.proxies={
        S.Box({-3.45,1.16,2.75},{0.72,2.1,0.30},"home.net"),
        S.Box({1.8,1.58,1.45},{1.20,0.86,1.05},"home.stove"),
        S.Box({-6.5,1.9,22},{3.85,4.4,0.95},"home.merchantShip"),
        S.Box({0.4,1.20,0.82},{0.78,0.09,0.54},"home.letterPaper"),
        S.Box({0.42,0.85,0.26},{1.0,0.26,0.10},"home.drawer"),
    }
    return require("lab.HomeArt").Apply(world)
end
return W
