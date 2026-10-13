-- Home art study A. Reference correspondence: reference-local-map.json.
-- Decorative meshes share the original world; stable interaction IDs are unchanged.
local A={}
function A.Apply(world)
    local byId={}; for _,m in ipairs(world.meshes) do byId[m.id]=m end
    local function add(id,shape,p,s,mat,r,params)
        local m={id=id,shape=shape,position=p,size=s,material=mat,rotation=r or {0,0,0},params=params}
        world.meshes[#world.meshes+1]=m; return m
    end
    local function box(id,p,s,mat,r) return add(id,"box",p,s,mat,r) end
    local function ball(id,p,s,mat,r) return add(id,"sphere",p,s,mat,r) end
    local function rod(id,a,b,width,mat)
        local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
        local flat=math.sqrt(dx*dx+dy*dy); local len=math.sqrt(flat*flat+dz*dz)
        return add(id,"cylinder",{(a[1]+b[1])/2,(a[2]+b[2])/2,(a[3]+b[3])/2},{width,len,width},mat,{math.deg(math.atan(dz,flat)),0,-math.deg(math.atan(dx,dy))})
    end
    local function leaf(id,x,y,z,angle,scale)
        return ball(id,{x,y,z},{0.135*scale,0.24*scale,0.035*scale},"leaf",{angle%31-15,angle%35-17,angle})
    end
    -- Remove the dark full-length drafting-grid seams; actual narrow planks carry texture.
    local kept={}
    for _,m in ipairs(world.meshes) do
        if not m.id:match('^floor.seam') and not m.id:match('^table.grain') then kept[#kept+1]=m end
    end
    world.meshes=kept
    -- The closer Home viewpoint needs the same distant ship framed through the doorway.
    for _,m in ipairs(world.meshes) do if m.id:match('^ship%.') then m.position[1]=m.position[1]-3.5 end end
    for _,p in ipairs(world.proxies) do
        if p.id=="home.merchantShip" then p.min[1]=p.min[1]-3.5; p.max[1]=p.max[1]-3.5 end
    end
    local hullPoints={}
    for _,station in ipairs({{-1.8,0.03},{-1.25,0.36},{0,0.50},{1.2,0.35},{1.9,0.025}}) do
        local x,width=station[1],station[2]
        for _,side in ipairs({-1,1}) do
            hullPoints[#hullPoints+1]={x,0.28,width*side}
            hullPoints[#hullPoints+1]={x*0.91,-0.19,width*0.58*side}
        end
    end
    byId['ship.hull'].params=hullPoints; byId['ship.hull'].material='paintedWood'
    for row=0,13 do
        for segment=0,3 do
            local x=-4.10+row*0.625; local z=-3.68+segment*2.04
            box('art.floor.'..row..'.'..segment,{x,0.004,z},{0.61,0.009,2.025},(row+segment)%4==0 and 'woodLight' or 'wood')
        end
    end
    -- Timber structure, plaster panels and a close cabinet-like workbench.
    for _,x in ipairs({-4.35,-1.20,1.05,4.32}) do
        box('art.wall.post.'..x,{x,2.02,3.36},{0.19,4.04,0.22},'wood')
    end
    for _,y in ipairs({0.35,3.34,3.82}) do box('art.wall.rail.'..y,{1.50,y,3.34},{5.82,0.15,0.21},'wood') end
    box('art.ceiling',{0,4.04,0.8},{8.8,0.16,5.3},'wood')
    for _,z in ipairs({-1.3,1.15,3.25}) do box('art.ceiling.beam.'..z,{0,3.80,z},{8.8,0.24,0.25},'darkWood') end
    -- The open door is a real slab beside the opening, never a second click target.
    box('art.door.open',{-3.98,1.68,2.5},{0.13,3.36,1.5},'wood')
    for _,y in ipairs({0.55,2.60}) do box('art.door.strap.'..y,{-3.88,y,2.5},{0.055,0.075,1.36},'iron') end
    box('art.table.front',{1.70,0.61,0.43},{4.15,0.82,0.12},'wood')
    box('art.table.bottom',{1.7,0.19,0.55},{4.26,0.12,0.36},'darkWood')
    for _,x in ipairs({-0.31,1.00,2.31,3.69}) do box('art.table.pillar.'..x,{x,0.64,0.36},{0.095,0.96,0.10},'darkWood') end
    for col=0,2 do for row=0,1 do
        local x=0.34+col*1.33; local y=0.43+row*0.36
        if not (col==0 and row==1) then
            box('art.drawer.face.'..col..'.'..row,{x,y,0.345},{1.19,0.30,0.055},'woodLight')
            add('art.drawer.pull.'..col..'.'..row,'torus',{x,y,0.293},{0.13,0.085,0.13},'brass',nil,{0.5,0.065,8,20})
        end
    end end
    for i=0,5 do box('art.top.plank.'..i,{1.6,1.157,0.55+i*0.336},{4.38,0.018,0.325},i%3==0 and 'woodLight' or 'wood') end
    -- Linen runner stays below the interactive paper and stove.
    box('art.linen.top',{1.0,1.173,1.21},{1.35,0.015,1.56},'linen')
    box('art.linen.drape',{0.9,0.89,0.42},{1.15,0.53,0.026},'linen')
    for i=0,6 do box('art.linen.fringe.'..i,{0.40+i*0.17,0.607,0.41},{0.025,0.09+(i%2)*0.025,0.025},'rope') end
    byId.paper.position[2]=1.191
    -- Irregular vessel heights/colours replace identical rows of jars.
    for level=1,2 do for i=0,6 do
        local m=byId['jar.'..level..'.'..i]; local lid=byId['jar.lid.'..level..'.'..i]
        local tall=({1.15,0.83,1.47,0.91,1.26,1.57,0.92})[i+1]
        local wide=({0.86,1.20,0.73,1.09,0.93,0.76,1.14})[i+1]
        m.size={wide,tall,wide}; m.position[1]=m.position[1]+(level==2 and 0.05 or -0.02)
        m.material=({'glassGreen','ceramic','glassAmber','greenGlaze','ceramic','glassGreen','glassAmber'})[i+1]
        lid.position={m.position[1],m.position[2]+0.355*tall,m.position[3]}; lid.size={0.18*wide,0.055,0.18*wide}
        if i%3~=1 then box('art.jar.label.'..level..'.'..i,{m.position[1],m.position[2]+0.16*tall,2.2-0.18*wide},{0.15*wide,0.12*tall,0.012},'paper') end
    end end
    -- Rounded hammered bowl silhouette, rolled lip, hanging front-facing rings and splayed feet.
    byId['stove.bowl'].params={{0,0},{0.25,0.015},{0.38,0.075},{0.43,0.20},{0.445,0.32},{0.405,0.44},{0.395,0.49},{0.46,0.525},{0.465,0.55},{0.425,0.55},{0.395,0.50},{0.37,0.43},{0.40,0.31},{0.36,0.15},{0.21,0.06},{0,0.06}}
    byId['stove.rim'].material='brass'
    for _,x in ipairs({1.27,2.33}) do
        local m=byId['stove.handle.'..x]; m.rotation={0,0,x<1.8 and -15 or 15}; m.position[3]=1.36; m.size={0.25,0.32,0.25}; m.material='brass'
        ball('stove.handle.mount.'..x,{x,1.86,1.37},{0.105,0.10,0.08},'brass')
    end
    for i=0,2 do
        local angle=math.pi/6+i*math.pi*2/3; local cs,sn=math.cos(angle),math.sin(angle)
        local top={1.8+cs*0.31,1.48,1.45+sn*0.31}; local foot={1.8+cs*0.43,1.19,1.45+sn*0.43}
        byId['stove.foot.'..i].size={0.001,0.001,0.001}
        rod('stove.leg.curve.'..i,foot,top,0.055,'brass')
        ball('stove.foot.pad.'..i,foot,{0.13,0.045,0.11},'brass')
        ball('stove.leg.rivet.'..i,top,{0.08,0.08,0.07},'brass')
    end
    add('stove.stand','torus',{1.8,1.46,1.45},{0.72,0.72,0.72},'brass',{90,0,0},{0.5,0.025,8,36})
    byId['stove.burner'].size={0.27,0.11,0.27}; byId['stove.burner'].position[2]=1.23; byId['stove.burner'].material='brass'
    byId['stove.flame'].size={0.075,0.13,0.075}; byId['stove.flame'].position[2]=1.34
    for i=0,7 do local a=i*math.pi/4; ball('stove.burner.hole.'..i,{1.8+math.cos(a)*0.138,1.235,1.45+math.sin(a)*0.138},{0.022,0.032,0.022},'iron') end
    for i=0,6 do local a=i*2.4; local herb=leaf('stove.herb.'..i,1.8+math.cos(a)*0.23,1.933,1.45+math.sin(a)*0.23,a*57,0.38); herb.rotation={90,0,a*57} end
    -- Herbs soften the shelving silhouette without covering interaction targets.
    for branch=0,5 do
        local x=0.02+branch*0.61; local start=2.72+(branch%2)*0.38
        for i=0,6 do
            local y=start+i*0.14; local xx=x+math.sin(i*0.8+branch)*0.12
            rod('art.vine.stem.'..branch..'.'..i,{xx,y,2.42},{x+math.sin((i+1)*0.8+branch)*0.12,y+0.14,2.42},0.018,'stem')
            leaf('art.vine.leaf.'..branch..'.'..i,xx+(i%2==0 and 0.07 or -0.07),y,2.35,branch*25+i*47,0.75+(i%3)*0.12)
            leaf('art.vine.leaf.pair.'..branch..'.'..i,xx+(i%2==0 and -0.08 or 0.08),y+0.035,2.38,-branch*25-i*47,0.7+(i%3)*0.12)
        end
    end
    for bunch=0,2 do
        local x=-0.90+bunch*2.10
        for stem=0,5 do
            local xx=x+(stem-2.5)*0.065; local yy=2.60-(stem%3)*0.07
            rod('art.herb.stem.'..bunch..'.'..stem,{x,3.03,3.04},{xx,yy,2.96},0.012,'stem')
            for n=0,3 do ball('art.herb.bud.'..bunch..'.'..stem..'.'..n,{xx,yy+n*0.038,2.95},{0.046,0.06,0.038},bunch%2==0 and 'lavender' or 'leaf') end
        end
    end
    -- Small tabletop detail group, kept away from the existing paper proxy.
    box('art.book.pages',{3.00,1.21,0.90},{0.56,0.095,0.43},'paper',{0,-12,0})
    for _,y in ipairs({1.16,1.27}) do box('art.book.cover.'..y,{3.00,y,0.90},{0.59,0.025,0.46},'book',{0,-12,0}) end
    box('art.tray.base',{0.35,1.182,1.03},{0.95,0.027,0.73},'darkWood')
    for _,x in ipairs({-0.12,0.82}) do box('art.tray.side.'..x,{x,1.22,1.03},{0.028,0.075,0.73},'wood') end
    for _,z in ipairs({0.68,1.38}) do box('art.tray.end.'..z,{0.35,1.22,z},{0.95,0.075,0.028},'wood') end
    byId.paper.position[2]=1.222
    -- Keep the paper target on its visible top after adding the tray.
    -- The previous lower target ray hit the raised front tray rail first.
    for _,p in ipairs(world.proxies) do if p.id=='home.letterPaper' then p.min[2]=p.min[2]+0.045; p.max[2]=p.max[2]+0.045 end end
    -- Real lantern geometry and local warm emitter; no image-based interface text.
    local lx,ly,lz=-0.94,2.64,3.05
    ball('art.lantern.glow',{lx,ly,lz},{0.16,0.26,0.16},'lamp')
    for _,y in ipairs({ly-0.18,ly+0.18}) do add('art.lantern.cap.'..y,'cylinder',{lx,y,lz},{0.30,0.055,0.27},'brass') end
    for i=0,3 do local a=math.pi/4+i*math.pi/2; rod('art.lantern.bar.'..i,{lx+math.cos(a)*0.12,ly-0.17,lz+math.sin(a)*0.12},{lx+math.cos(a)*0.12,ly+0.17,lz+math.sin(a)*0.12},0.025,'iron') end
    add('art.lantern.hook','torus',{lx,ly+0.30,lz},{0.15,0.20,0.15},'iron',nil,{0.5,0.07,8,24})
    -- Keep the original net shape until its exact attachment version is resolved.
    -- Low-amplitude, true mesh wave glints and dock rope break the flat sea plane.
    for i=0,2 do for _,x in ipairs({-3.83,-1.47}) do
        local z=4+i*2.2
        rod('art.dock.rope.a.'..i..'.'..x,{x,0.87,z},{x,0.60,z+1.1},0.035,'rope')
        rod('art.dock.rope.b.'..i..'.'..x,{x,0.60,z+1.1},{x,0.87,z+2.2},0.035,'rope')
    end end
    for i=0,24 do
        local x=-14+(i*7%26); local z=12+i*1.35
        box('art.sea.glint.'..i,{x,-0.267,z},{0.55+(i%4)*0.45,0.012,0.035+(i%3)*0.02},i%4==0 and 'sunlitWater' or 'waterGlint',{0,(i%5-2)*7,0})
    end
    -- Reference stove is a small, slender tabletop tool, not the largest vessel.
    for _,m in ipairs(world.meshes) do
        if m.id:match('^stove%.') then
            m.position={1.4+(m.position[1]-1.8)*0.80,1.18+(m.position[2]-1.18)*0.80,1.45+(m.position[3]-1.45)*0.80}
            for k=1,3 do m.size[k]=m.size[k]*0.80 end
        elseif m.id:match('^coast%.') then m.position[1]=m.position[1]-18 end
    end
    world.rim.center={1.4,1.18+(1.94-1.18)*0.8,1.45}; world.rim.radius=0.37*0.8
    for _,p in ipairs(world.proxies) do if p.id=='home.stove' then
        p.min[1]=p.min[1]-0.40; p.max[1]=p.max[1]-0.40
    end end
    -- Clear bottles and a mortar give the shelf a useful foreground, breaking the grid.
    for i=0,1 do
        local x=2.17+i*0.42; local h=0.61+i*0.13
        add('art.bottle.'..i,'lathe',{x,1.18,1.25},{1,h/0.7,1},'clearGlass',nil,{{0,0},{0.12,0},{0.14,0.05},{0.14,0.39},{0.10,0.48},{0.055,0.53},{0.055,0.70},{0.045,0.70},{0.045,0.54},{0.10,0.48},{0.13,0.38},{0.13,0.035},{0,0.035}})
        add('art.bottle.cork.'..i,'cylinder',{x,1.18+h+0.026,1.25},{0.12,0.055,0.12},'woodLight')
        add('art.bottle.base.'..i,'cylinder',{x,1.235,1.25},{0.20,0.06,0.20},i==0 and 'herbal' or 'sail')
    end
    add('art.mortar','lathe',{2.96,1.18,1.65},{1,1,1},'ceramic',nil,{{0,0},{0.17,0},{0.22,0.1},{0.25,0.27},{0.22,0.27},{0.19,0.1},{0.12,0.055},{0,0.055}})
    rod('art.pestle',{2.91,1.28,1.65},{3.16,1.65,1.62},0.07,'ceramic')
    add('art.lighthouse','cylinder',{-10.3,2.7,47},{0.65,4.5,0.65},'paper')
    add('art.lighthouse.cap','cylinder',{-10.3,5.0,47},{0.86,0.15,0.86},'darkWood')
    return world
end
return A
