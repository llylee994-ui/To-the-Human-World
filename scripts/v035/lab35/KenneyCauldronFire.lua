-- Six additive triangles, no light/exposure changes, no event subscriptions.
-- CC0 Kenney flame_01.png; texture alpha masks emission in the official add technique.
local F={}
function F.New(scene,resourcePrefix,options)
    options=options or {}
    assert(scene and resourcePrefix,'scene and resource prefix required')
    assert(options.freezeTime==nil or options.freezeTime==0,'only screenshot harness freezeTime=0 is supported')
    local path=resourcePrefix:gsub('/$','')..'/selected-fire/flame_01.png'
    local texture=assert(cache:GetResource('Texture2D',path),'missing selected Kenney fire texture')
    local tech=assert(cache:GetResource('Technique','Techniques/DiffUnlitParticleAdd.xml'),'missing official additive particle technique')
    local mat=Material:new();mat:SetTechnique(0,tech);mat:SetTexture(TU_DIFFUSE,texture)
    mat:SetShaderParameter('MatDiffColor',Variant(Color(3,1.26,.18,1)));mat:SetCullMode(CULL_NONE)
    local root
    local ok,result=pcall(function()
        root=scene:CreateChild('v035.kenney-cauldron-fire')
        root.position=Vector3(2.0972133447,1.913,-1.8696944304)
        local geometry=root:CreateComponent('CustomGeometry');geometry:SetMaterial(mat)
        geometry.castShadows=false;geometry.viewMask=0x80000000
        geometry:SetDynamic(true)
        local t,stopped=0,false
        local function rebuild(value)
            local height=.060*(1+.08*math.sin(value*7.1))
            local width=.100*(1+.05*math.sin(value*5.3))
            local sway=.004*math.sin(value*3.7)
            geometry:BeginGeometry(0,TRIANGLE_LIST)
            for card=0,2 do
                local angle=card*math.pi/3
                local x,z=math.cos(angle)*width*.5,math.sin(angle)*width*.5
                local vertices={{-x,0,-z,0,1},{x,0,z,1,1},{x+sway,height,z,1,0},{-x+sway,height,-z,0,0}}
                for _,index in ipairs({1,2,3,1,3,4}) do
                    local v=vertices[index]
                    geometry:DefineVertex(Vector3(v[1],v[2],v[3]))
                    geometry:DefineColor(Color(1,1,1,1)) -- particle technique requires COLOR vertex input
                    geometry:DefineTexCoord(Vector2(v[4],v[5]))
                end
            end
            geometry:Commit()
        end
        rebuild(options.freezeTime or 0)
        local api={root=root,geometry=geometry}
        function api.Update(dt)
            if stopped or options.freezeTime~=nil then return end
            assert(dt>=0 and dt<math.huge,'finite nonnegative timestep required')
            t=(t+math.min(dt,.1))%3600;rebuild(t)
        end
        function api.Stop()
            if stopped then return end
            stopped=true;root:Remove()
        end
        return api
    end)
    if not ok then
        local cleanupOk,cleanupError=true,nil
        if root then cleanupOk,cleanupError=pcall(function() root:Remove() end) end
        error(tostring(result)..(cleanupOk and '' or '; fire root cleanup failed: '..tostring(cleanupError)),0)
    end
    return result
end
return F
