-- Adjustable reference-driven dressing; every foreground prop remains geometry.
local D={}
function D.Apply(w)
 local function add(id,shape,p,s,mat,r,params)
  local m={id='detail.'..id,shape=shape,position=p,size=s,material=mat,rotation=r or {0,0,0},params=params}
  w.meshes[#w.meshes+1]=m;return m
 end
 local function box(id,p,s,mat,r)return add(id,'box',p,s,mat,r)end
 local function ball(id,p,s,mat,r)return add(id,'sphere',p,s,mat,r)end
 local function rod(id,a,b,r,mat)return add(id,'tube',{0,0,0},{1,1,1},mat,nil,{points={a,b},radius=r,segments=8})end
 local function ring(id,p,s,mat,r)return add(id,'torus',p,s,mat,r,{.5,.04,8,28})end
 local function leaf(id,p,s,r)
  return add(id,'sail',p,s,'leaf',r,{{0,-.5},{-.23,-.1},{-.17,.23},{0,.5},{.17,.23},{.23,-.1}})
 end
 -- Replace the narrow study runner with a broad cloth and a draped, fringed edge.
 local kept={}
 for _,m in ipairs(w.meshes) do
  if not m.id:match('^art%.linen%.') and not m.id:match('^art%.sea%.glint') then
   if m.id:match('^art%.vine%.leaf') then
    m.shape='sail';m.params={{0,-.5},{-.38,-.12},{-.27,.23},{0,.5},{.27,.23},{.38,-.12}};m.size[3]=1
   end
   kept[#kept+1]=m
  end
 end
 w.meshes=kept
 box('cloth.top',{-1.35,1.185,.34},{1.68,.012,3.12},'linen')
 for i=0,31 do
  local z=-1.14+i*.092;local fold=math.sin(i*1.9)*.022
  box('cloth.drape.'..i,{-2.20+fold,.91,z},{.026,.55,.098},'linen',{0,0,math.sin(i*1.9)*2})
  rod('cloth.tassel.'..i,{-2.22+fold,.64,z},{-2.22+fold,.53+math.sin(i*4)*.02,z+.014},.005,'linen')
 end
 -- Scissors on the near cloth, without replacing live letter content.
 ring('scissors.handle.1',{-1.81,1.215,1.16},{.17,.20,.17},'brass',{90,-28,0})
 ring('scissors.handle.2',{-1.65,1.218,1.11},{.17,.20,.17},'brass',{90,20,0})
 rod('scissors.blade.1',{-1.72,1.22,1.19},{-1.38,1.22,1.60},.013,'brass')
 rod('scissors.blade.2',{-1.70,1.224,1.21},{-1.40,1.224,1.64},.012,'brass')
 ball('scissors.pivot',{-1.65,1.234,1.30},{.038,.022,.038},'brass')
 -- Loose papers are visual props; actual text and cut spans remain in the 2D reader.
 for i=0,3 do box('loose.paper.'..i,{-1.55+i*.035,1.209+i*.006,.02},{.58,.006,.69},'paper',{0,-17+i*3,0}) end
 -- Pot/plant silhouette at the far end of the table, against the door-side wall.
 local function plant(id,c,scale)
  add(id..'.pot','lathe',c,{scale,scale,scale},'ceramic',nil,{{0,0},{.15,0},{.23,.38},{.25,.39},{.25,.43},{.21,.43},{.20,.38},{.12,.04},{0,.04}})
  for branch=0,6 do
   local a=branch*2.399;local bx,bz=c[1]+math.cos(a)*.18*scale,c[3]+math.sin(a)*.18*scale
   local h=(.57+(branch%3)*.12)*scale
   rod(id..'.stem.'..branch,{c[1],c[2]+.32*scale,c[3]},{bx,c[2]+h,bz},.006*scale,'stem')
   for j=0,3 do
    local yy=c[2]+(.45+j*.08)*scale
    local xx=bx+math.sin(a+j)*.12*scale;local zz=bz+math.cos(a+j)*.11*scale
    leaf(id..'.leaf.'..branch..'.'..j,{xx,yy,zz},{.24*scale,.30*scale,1},{30+j*7,branch*53,j%2==0 and 45 or -45})
   end
  end
 end
 plant('tableplant',{-1.28,1.18,2.25},1)
 plant('doorplant',{-4.22,.02,1.80},1.25)
 -- Daisies with individual petals; flower clusters break the regular vessel rows.
 for cluster=0,2 do
  local cx,cy,cz=-.77+cluster*.11,1.65+cluster*.36,2.01-cluster*.62
  for flower=0,3 do
   local fx,fy,fz=cx+math.sin(flower*4+cluster)*.15,cy+(flower%2)*.13,cz+math.cos(flower*3)*.12
   rod('flower.stem.'..cluster..'.'..flower,{cx,cy-.30,cz},{fx,fy,fz},.005,'stem')
   ball('flower.heart.'..cluster..'.'..flower,{fx,fy,fz},{.038,.036,.025},'flowerHeart')
   for petal=0,7 do
    local a=petal*math.pi/4
    ball('flower.petal.'..cluster..'.'..flower..'.'..petal,{fx+math.cos(a)*.043,fy+math.sin(a)*.043,fz},{.035,.071,.012},'petal',{0,0,petal*45-90})
   end
  end
 end
 -- Framed botanical drawings are decoration rather than readable interface text.
 local function frame(id,c,s)
  box(id..'.paper',c,{s[1],s[2],.015},'botany')
  for side=-1,1,2 do
   box(id..'.v.'..side,{c[1]+side*s[1]*.52,c[2],c[3]-.013},{.041,s[2]+.10,.06},'wood')
   box(id..'.h.'..side,{c[1],c[2]+side*s[2]*.53,c[3]-.013},{s[1]+.08,.044,.06},'wood')
  end
 end
 frame('botany.wall',{-1.02,2.12,3.35},{.36,.54})
 frame('botany.small',{-1.12,1.52,3.33},{.24,.32})
 -- Rug and partially visible foreground chair ground the interior.
 box('rug',{-3.18,.020,-.04},{1.65,.018,2.35},'rug',{0,3,0})
 for side=-1,1,2 do
  rod('chair.post.'..side,{-2.45,.03,-.84+side*.30},{-2.45,1.12,-.84+side*.30},.038,'wood')
 end
 for i=0,5 do rod('chair.back.'..i,{-2.45,.35,-1.12+i*.11},{-2.45,1.00,-1.12+i*.11},.018,'wood')end
 rod('chair.top',{-2.45,1.07,-1.20},{-2.45,1.07,-.48},.055,'wood')
 -- Real dark nail heads and straps make nearby timber read at the comparison distance.
 for i=0,19 do for side=-1,1,2 do
  ball('dock.nail.'..i..'.'..side,{-2.65+side*.90,.008,3.72+i*.39},{.021,.008,.021},'iron')
 end end
 for i=0,7 do box('door.plank.'..i,{-3.898,1.66,1.83+i*.187},{.028,3.24,.177},i%3==0 and 'woodLight' or 'wood')end
 for i=0,2 do for side=-1,1,2 do ball('door.nail.'..i..'.'..side,{-3.87,.56+i*1.02,2.48+side*.56},{.018,.027,.027},'iron')end end
 -- Small noninteractive seeds in glass bottles and a few coins; live balance stays in UI.
 for bottle=0,1 do for i=0,8 do
  local x=-1.35+math.sin(i*2.4)*.08;local z=-.12-bottle*.42+math.cos(i*2.4)*.08
  ball('bottle.seed.'..bottle..'.'..i,{x,1.22+(i%3)*.015,z},{.03,.022,.024},bottle==0 and 'herbal' or 'paper')
 end end
 for i=0,3 do add('coin.'..i,'cylinder',{-1.90+i*.043,1.216,-.85+(i%2)*.02},{.066,.009,.066},'brass')end
 -- Hundreds of short glints replace the drafting-like long sea stripes.
 for i=0,170 do
  local xx=-14+(i*6.71%43);local zz=12+(i*3.79%42)
  box('water.glint.'..i,{xx,-.267,zz},{.05+(i%7)*.042,.004,.012+(i%3)*.008},i%5==0 and 'sunlitWater' or 'waterGlint',{0,(i%7-3)*4,0})
 end
 return w
end
return D
