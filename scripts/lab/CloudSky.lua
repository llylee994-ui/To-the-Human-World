-- Original procedural clouds. This distant sky is a cubemap, not a room image.
local C={}
local function mix(a,b,t)return a+(b-a)*t end
local function noise(x,y,z)
    return (math.sin(x*2.3+y*3.1+z*1.7)+math.sin(x*5.3-y*2.8+z*4.2)*.50+math.sin(x*11.7+y*8.5-z*7.3)*.22)/1.72
end
function C.New(scene)
    local axes={{{0,0,-1},{0,-1,0},{1,0,0}},{{0,0,1},{0,-1,0},{-1,0,0}},{{1,0,0},{0,0,1},{0,1,0}},{{1,0,0},{0,0,-1},{0,-1,0}},{{1,0,0},{0,-1,0},{0,0,1}},{{-1,0,0},{0,-1,0},{0,0,-1}}}
    local tex=TextureCube:new();tex:SetSRGB(true)
    for face=0,5 do
        local img=Image();img:SetSize(256,256,4);local a=axes[face+1]
        for y=0,255 do for x=0,255 do
            local u,v=(x+.5)/128-1,(y+.5)/128-1
            local dx,dy,dz=a[3][1]+u*a[1][1]+v*a[2][1],a[3][2]+u*a[1][2]+v*a[2][2],a[3][3]+u*a[1][3]+v*a[2][3]
            local l=math.sqrt(dx*dx+dy*dy+dz*dz);dx,dy,dz=dx/l,dy/l,dz/l
            local t=math.min(1,math.max(0,dy)*2.2)^.6
            local r,g,b=mix(.81,.27,t),mix(.70,.46,t),mix(.58,.68,t)
            if dy>0 then
                local q=noise(dx*7,dy*23,dz*7)+noise(dx*19,dy*56,dz*19)*.19
                local cloud=math.min(.92,math.max(0,(q+.10)*2.4))*math.min(1,dy*25)
                local warm=math.max(0,1-math.abs(dx+.28)*.9)
                local bright=math.max(0,noise(dx*7,(dy+.03)*23,dz*7)-q)*.4
                r=mix(r,.69+warm*.25+bright,cloud);g=mix(g,.61+warm*.11+bright,cloud);b=mix(b,.64-warm*.20+bright,cloud)
            end
            img:SetPixel(x,y,Color(r,g,b,1))
        end end
        tex:SetData(face,img,false)
    end
    local mat=Material:new();mat:SetTechnique(0,cache:GetResource('Technique','Techniques/DiffSkybox.xml'));mat:SetTexture(TU_DIFFUSE,tex)
    mat:SetShaderParameter('MatDiffColor',Variant(Vector4(1.7,1.7,1.7,1)))
    local n=scene:CreateChild('OriginalCloudSky');local sky=n:CreateComponent('Skybox');sky:SetModel(cache:GetResource('Model','Models/Box.mdl'));sky:SetMaterial(mat)
    return n
end
return C
