local F={}
function F.Run(check)
    local U=require "core.StateUtil"
    local Fixture=require "lab35.tests.Fixture"
    local Loader=require "lab35.MeshLoader"
    local Package=require "lab35.ScenePackage"
    local base=Fixture.New()
    local catalog={}
    for i=1,9 do catalog[i]={id="full"..i,path="meshes/part-"..i..".json",materialId="test",vertices=3,triangles=1} end
    local rows=Package.Catalog({meshFiles=catalog})
    check("full catalog exceeds six-mesh sample without dropping entries",#rows==9)
    local bad=U.Copy(catalog);bad[2].path="../outside.json"
    check("stream rejects package path escape",not pcall(Package.Catalog,{meshFiles=bad}))
    bad=U.Copy(catalog);bad[2].path="MESHES/PART-1.JSON"
    check("stream rejects Windows case-colliding file paths",not pcall(Package.Catalog,{meshFiles=bad}))
    bad=U.Copy(catalog);bad[1].vertices=60001
    check("stream rejects source batches above 60000 vertices",not pcall(Package.Catalog,{meshFiles=bad}))
    local header=U.Copy(base);header.meshes={}
    for _,a in ipairs(header.anchors) do a.visibleMeshIds={"full1"} end
    local function backend()
        local b={begins=0,removes=0,commits=0,publishes=0,vertices=0}
        b.Material=function(m) return m.id end
        b.Begin=function() b.begins=b.begins+1;return {} end
        b.Geometry=function(_,id) return {id=id} end
        b.Vertex=function() b.vertices=b.vertices+1 end
        b.Commit=function() b.commits=b.commits+1 end
        b.Remove=function() b.removes=b.removes+1 end
        b.Publish=function() b.publishes=b.publishes+1 end
        return b
    end
    local function payload(entry) local mesh=U.Copy(base.meshes[1]);mesh.id=entry.id;mesh.sourceObjects={"source-"..entry.id};return mesh end
    local reads={};local b=backend()
    local job=Loader.Stream(header,rows,function(entry) reads[#reads+1]=entry.id;return payload(entry) end,b,{retainMeshIds={full1=true}})
    check("stream creation is lazy and does not read or mutate engine",#reads==0 and b.begins==0)
    local steps=0
    while job.Snapshot().status~="complete" and job.Snapshot().status~="failed" do job.Step();steps=steps+1;assert(steps<1000) end
    local result=job.Result()
    check("stream reads every declared mesh in order",result and #reads==9 and reads[1]=="full1" and reads[9]=="full9")
    check("stream geometry yields across update steps",steps>9 and job.Snapshot().yields>9 and b.vertices==27)
    check("stream publishes only one complete root",b.begins==1 and b.publishes==1 and b.removes==0)
    check("stream totals use actual emitted meshes and source members",result.stats.meshes==9 and result.stats.triangles==9 and result.stats.sourceObjects==9)
    check("stream releases ordinary Lua mesh geometry",result.meshById.full2.geometryReleased and result.meshById.full2.positions==nil and #result.prepared.meshes==1)
    check("stream retains explicit ship geometry for alpha picking",result.meshById.full1.positions~=nil and result.stats.retainedGeometryMeshes==1)
    check("cancel after publish does not destroy complete scene",not job.Cancel() and b.removes==0)
    local failing=backend();local failReads=0
    local fault=Loader.Stream(header,rows,function(entry) failReads=failReads+1;if failReads==2 then error("missing second file") end;return payload(entry) end,failing)
    for _=1,200 do if fault.Step()=="failed" then break end end
    check("stream failure rolls back root and stops later reads",fault.Snapshot().status=="failed" and failReads==2 and failing.removes==1 and failing.publishes==0)
    check("stream failure preserves useful file and error",fault.Snapshot().currentId==rows[2].path and fault.Snapshot().error:find("missing second file",1,true))
    local weak=setmetatable({},{__mode="v"});local commitFaultBackend=backend()
    commitFaultBackend.Commit=function() error("injected native commit error") end
    local commitFault=Loader.Stream(header,rows,function(entry) local p=payload(entry);weak[1]=p;return p end,commitFaultBackend)
    for _=1,200 do if commitFault.Step()=="failed" then break end end
    collectgarbage("collect")
    check("failed coroutine releases the currently parsed mesh",commitFault.Snapshot().status=="failed" and weak[1]==nil)
    local cancelled=backend();local cancelReads=0
    local cancel=Loader.Stream(header,rows,function(entry) cancelReads=cancelReads+1;return payload(entry) end,cancelled)
    for _=1,100 do cancel.Step();if cancelled.commits==1 then break end end
    check("cancel pending import removes partial native root",cancel.Cancel() and cancelled.removes==1 and cancel.Step()=="cancelled" and cancelReads==1)
    local invalid=U.Copy(header);invalid.anchors[1].visibleMeshIds={"not-in-catalog"};local untouched=backend()
    local invalidJob=Loader.Stream(invalid,rows,payload,untouched)
    for _=1,100 do if invalidJob.Step()=="failed" then break end end
    check("bad semantic mesh reference fails before root mutation",invalidJob.Snapshot().status=="failed" and untouched.begins==0)
    local mismatch=backend()
    local mismatchJob=Loader.Stream(header,rows,function(entry) local p=payload(entry);p.id="wrong";return p end,mismatch)
    for _=1,100 do if mismatchJob.Step()=="failed" then break end end
    check("catalog identity mismatch cannot silently substitute geometry",mismatchJob.Snapshot().status=="failed" and mismatch.removes==1 and mismatch.publishes==0)
    local ratio=1920/1080;local full={format="dot-customgeometry-scene-v1",indexBase=0,primitive="TRIANGLE_LIST",
        mainContractSha=require("lab35.ProbeAdapter").mainSha,meshes={},materials={{id="test",baseColorFactor={1,1,1,1},roughness=.7,metallic=0,alphaMode="OPAQUE",doubleSided=false}},
        camera={position={0,-5,2},forward={0,1,0},up={0,0,1},projection="perspective",resolution={1920,1080},horizontalFovDegrees=55,
            verticalFovDegrees=math.deg(2*math.atan(math.tan(math.rad(55)/2)/ratio))},proxyMeshes={},interactionProxies={}}
    for i,a in ipairs(header.anchors) do
        full.proxyMeshes[i]={id="proxy"..i,interactionId=a.id,renderVisible=false,pickable=true,positions={-1,5,-1,1,5,-1,0,5,1},indices={0,1,2}}
        full.interactionProxies[i]={id=a.id,target=require("lab35.Ids")[a.id].target,position=a.position,visibleMeshIds={"full1"},proxyMeshId="proxy"..i,screenAnchor={.5,.5}}
    end
    local converted=require("lab35.ProbeAdapter").Convert(full,{meshCatalog=rows})
    check("full header adapter preserves eight independent invisible proxies",#converted.meshes==0 and #converted.anchors==8 and converted.statistics.fullScene)
    local prepared=require("lab35.MeshContract").Prepare(converted,{meshCatalog=rows})
    check("full header validates without loading all mesh payloads",#prepared.meshes==0 and #prepared.anchors==8)
    converted.materials[1].normalTexture="source-normal.png"
    converted.materials[1].normalMapConvention="tangent-space OpenGL +Y; requires tangent basis derived from uv0"
    converted.materials[1].textureColorSpaces={normalTexture="linear"}
    local normalHeader=require("lab35.MeshContract").Prepare(converted,{meshCatalog=rows})
    check("declared linear tangent normal map survives preparation",#normalHeader.warnings==0 and normalHeader.materials.test.normalTexture=="source-normal.png")
    converted.materials[1].textureColorSpaces.normalTexture="sRGB"
    check("reject gamma-encoded normal map metadata",not pcall(require("lab35.MeshContract").Prepare,converted,{meshCatalog=rows}))
    full.interactionProxies[1].visibleMeshIds=nil
    check("full adapter rejects missing semantic visible mesh mapping",not pcall(require("lab35.ProbeAdapter").Convert,full,{meshCatalog=rows}))
    local UI=require "urhox-libs/UI";local display=require("lab35.LoadStatus").New(UI,function() end)
    display.Update({status="failed",phase="readMesh",currentId="missing.json",error="test file absent"})
    local widgets=require("lab35.tests.FakeUI").registry
    check("failed load remains visible with exact error and no retry",display.root.props.visible and widgets.fullLoadDetail.props.text:find("test file absent",1,true) and not widgets.fullLoadCancel.props.visible)
    local stats=require("lab35.FrameStats").New();stats.Add(.01);stats.Add(.02);stats.Add(.03)
    local report=stats.Report(true)
    check("frame reporting uses measured Update samples and resets",report.frames==3 and math.abs(report.meanFrameMs-20)<1e-9 and report.worstFrameMs==30 and stats.Report().frames==0)
    local Reader=require "lab35.ResourceReader"
    local readsCount,closeCount=0,0
    local file={IsOpen=function() return true end,GetSize=function() return 100 end,
        ReadString=function() readsCount=readsCount+1;return "{}" end,Close=function() closeCount=closeCount+1 end}
    check("oversized mesh is rejected before reading and handle closes",not pcall(Reader.Read,function() return file end,"huge.json",20) and readsCount==0 and closeCount==1)
    file.GetSize=function() return 2 end;file.ReadString=function() error("read failed") end
    check("resource read exception still closes handle",not pcall(Reader.Read,function() return file end,"failed.json",20) and closeCount==2)
    file.ReadString=function() return "{" end
    check("truncated resource read is rejected",not pcall(Reader.Read,function() return file end,"truncated.json",20) and closeCount==3)
    file.ReadString=function() return "{}" end
    check("bounded resource read preserves bytes and closes once",Reader.Read(function() return file end,"ok.json",20)=="{}" and closeCount==4)
    local CameraMath=require "lab35.CameraMath"
    local frame=CameraMath.Frame({position={0,-5,2},forward={0,1,0},up={0,0,1}})
    check("Blender rotation alone does not turn desired camera into a LH basis",math.abs(frame.desiredLhNodeBasisDeterminant+1)<1e-9 and math.abs(frame.conventionalLhRightDot+1)<1e-9)
    check("right-up-backward is a proper RH camera node rotation",math.abs(frame.rhNodeBasisDeterminant-1)<1e-9)
    local uv=CameraMath.Project(frame,require("lab35.Math3").Add(frame.position,require("lab35.Math3").Mul(frame.forward,10)),math.rad(55),16/9)
    check("reference camera projects forward to image center",math.abs(uv[1]-.5)<1e-9 and math.abs(uv[2]-.5)<1e-9)
end
return F
