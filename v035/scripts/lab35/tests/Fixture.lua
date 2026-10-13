-- Synthetic data for contract tests. This is NOT the cloud scene or an art sample.
local F={}
function F.New()
    local anchors={}
    for id in pairs(require "lab35.Ids") do
        local p={kind="sphere",radius=.1}
        if id=="home.merchantShip" then
            p={kind="triangles",positions={-1,5,-1,1,5,-1,0,5,1},indices={0,1,2}}
        end
        anchors[#anchors+1]={id=id,position={0,5,0},proxy=p}
    end
    return {format="d3-v035-mesh-v1",axis="BLENDER_Z_UP",unitScale=1,
        source={name="SYNTHETIC TEST ONLY"},
        materials={{id="test",baseColor={1,.5,.2,1},roughness=.7,metallic=0,alphaMode="OPAQUE",doubleSided=false}},
        meshes={{id="test-triangle",materialId="test",positions={0,0,0,1,0,0,0,1,0},normals={0,0,1,0,0,1,0,0,1},uv0={0,0,1,0,0,1},indices={0,1,2}}},
        anchors=anchors,cameras={{id="Home",position={0,-5,2},forward={0,1,0},up={0,0,1},projection="perspective",fov=55,fovAxis="horizontal",fovUnit="degrees"}},statistics={synthetic=true}}
end
return F
