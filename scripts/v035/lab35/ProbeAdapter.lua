-- Explicit normalization of the received cloud probe; never renders proxyMeshes.
local A={mainSha="1cd0cdbec06487a5c60f109d5fd477198cfc8846"}
function A.Convert(probe,options)
    options=options or {}
    local full=probe.format=="dot-customgeometry-scene-v1"
    assert(full or probe.format=="dot-customgeometry-probe-v1","unexpected cloud scene format")
    assert(probe.indexBase==0 and probe.primitive=="TRIANGLE_LIST","unexpected index/primitive convention")
    assert(probe.mainContractSha==A.mainSha,"probe uses another main contract")
    local out={format="d3-v035-mesh-v1",axis="BLENDER_Z_UP",unitScale=1,
        meshes=probe.meshes or {},materials={},anchors={},cameras={},statistics={probeOnly=not full,fullScene=full},source=probe.source}
    local used={};for _,m in ipairs(out.meshes) do used[m.materialId]=true end
    for _,m in ipairs(options.meshCatalog or {}) do used[m.materialId]=true end
    for _,m in ipairs(probe.materials) do
        if used[m.id] then
            assert(m.renderVisible~=false,"visible mesh refers to invisible proxy material")
            out.materials[#out.materials+1]={id=m.id,baseColor=m.baseColorFactor,baseColorTexture=m.baseColorTexture,
                roughness=m.roughness,metallic=m.metallic,alphaMode=m.alphaMode,alphaCutoff=m.alphaCutoff,doubleSided=m.doubleSided,cullMode=m.cullMode,unlit=m.unlit==true,
                normalTexture=m.normalTexture,normalMapConvention=m.normalMapConvention,textureColorSpaces=m.textureColorSpaces,
                roughMetalOcclusionTexture=m.roughMetalOcclusionTexture,emissiveFactor=m.emissiveFactor,emissiveStrength=m.emissiveStrength,emissiveTexture=m.emissiveTexture}
        end
    end
    local proxies={}
    for _,m in ipairs(probe.proxyMeshes) do
        assert(m.renderVisible==false and m.pickable==true,"proxy visibility/picking mismatch")
        assert(not proxies[m.id],"duplicate proxy mesh");proxies[m.id]=m
    end
    local ids=require "v035.lab35.Ids"
    local seen={}
    for _,a in ipairs(probe.interactionProxies) do
        assert(ids[a.id] and ids[a.id].target==a.target,"semantic target differs from pinned main")
        assert(not seen[a.id],"duplicate semantic proxy");seen[a.id]=true
        local p=assert(proxies[a.proxyMeshId],"missing semantic proxy")
        assert(p.interactionId==a.id,"wrong proxy owner")
        if full then assert(type(a.visibleMeshIds)=="table" and #a.visibleMeshIds>0,"full scene requires visibleMeshIds for "..a.id) end
        out.anchors[#out.anchors+1]={id=a.id,position=a.position,visibleMeshIds=a.visibleMeshIds,
            proxy={kind="triangles",positions=p.positions,indices=p.indices}}
    end
    local c=probe.camera
    local aspect=c.resolution[1]/c.resolution[2]
    assert(math.abs(2*math.atan(math.tan(math.rad(c.horizontalFovDegrees)/2)/aspect)-math.rad(c.verticalFovDegrees))<1e-6,"camera FOV pair mismatch")
    out.cameras[1]={id="Home",position=c.position,forward=c.forward,up=c.up,projection=c.projection,
        fov=c.horizontalFovDegrees,fovAxis="horizontal",fovUnit="degrees",nearClip=.05,farClip=500}
    if not full then assert(#out.meshes==6 and #out.materials==6,"probe format must describe the verified six-mesh sample") end
    assert((#out.meshes>0 or #(options.meshCatalog or {})>0) and #out.materials>0 and #out.anchors==8,"scene must contain visible geometry and exactly eight semantic proxies")
    -- Optional exported cameras use the same explicit vectors/FOV pair as Home.
    for _,extra in ipairs(probe.additionalCameras or {}) do
        assert(extra.id=="Brew" or extra.id=="Seaside","unexpected additional camera")
        out.cameras[#out.cameras+1]={id=extra.id,position=extra.position,forward=extra.forward,up=extra.up,projection=extra.projection,
            fov=extra.horizontalFovDegrees,fovAxis="horizontal",fovUnit="degrees",nearClip=extra.nearClip or .05,farClip=extra.farClip or 500}
    end
    return out
end
return A
