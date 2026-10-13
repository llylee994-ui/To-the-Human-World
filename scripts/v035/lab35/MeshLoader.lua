local Contract=require "v035.lab35.MeshContract"
local L={}
function L.Stream(header,catalog,readMesh,backend,options)
    options=options or {}
    local state={status="pending",phase="pending",done=0,total=#catalog,meshFiles=0,emittedVertices=0,committedBatches=0,stepCalls=0,yields=0}
    local root,result
    local function progress(phase,done,total,id)
        state.phase=phase;state.done=done;state.total=total;state.currentId=id
        state.yields=state.yields+1;coroutine.yield()
    end
    local function cleanup()
        if root then
            local ok,err=pcall(backend.Remove,root);root=nil
            if not ok then state.cleanupError=tostring(err) end
        end
    end
    local co=coroutine.create(function()
        local size=options.chunkVertices or 12000
        assert(size>=3 and size<=60000 and size%3==0,"invalid native chunk size")
        state.status="validating"
        local prepared=Contract.Prepare(header,{meshCatalog=catalog,onProgress=progress})
        local expected={meshes=#catalog,triangles=0,sourceVertices=0,expandedVertices=0}
        for _,entry in ipairs(catalog) do
            expected.triangles=expected.triangles+entry.triangles
            expected.sourceVertices=expected.sourceVertices+entry.vertices
        end
        expected.expandedVertices=expected.triangles*3
        assert(expected.expandedVertices<=(options.maxExpandedVertices or 12000000),"full-scene expanded vertex ceiling exceeded")
        state.expected=expected;state.status="loading"
        local materials,keys={},{}
        for key in pairs(prepared.materials) do keys[#keys+1]=key end;table.sort(keys)
        for i,key in ipairs(keys) do
            state.phase="materials";state.currentId=key
            materials[key]=backend.Material(prepared.materials[key]);progress("materials",i,#keys,key)
        end
        root=backend.Begin()
        local meshById,sourceObjects={},{}
        local stats={meshes=0,triangles=0,sourceVertices=0,expandedVertices=0,drawables=0,retainedGeometryMeshes=0}
        for fileIndex,entry in ipairs(catalog) do
            progress("readMesh",fileIndex-1,#catalog,entry.path)
            local payload=readMesh(entry)
            if type(payload)=="string" then
                progress("decodeMesh",fileIndex-1,#catalog,entry.path)
                payload=assert(cjson.decode(payload))
            end
            assert(type(payload)=="table" and payload.id==entry.id and payload.materialId==entry.materialId,"mesh file identity differs from catalog")
            assert(#payload.positions==entry.vertices*3 and #payload.indices==entry.triangles*3,"mesh file counts differ from catalog")
            local single={format=header.format,axis=header.axis,unitScale=header.unitScale,materials=header.materials,
                meshes={payload},anchors={},cameras=header.cameras}
            local chunk=Contract.Prepare(single,{onProgress=progress,maxExpandedVertices=options.maxExpandedVertices or 12000000})
            local mesh=chunk.meshes[1]
            for _,name in ipairs(mesh.sourceObjects or {}) do assert(type(name)=="string","sourceObjects entries must be names");sourceObjects[name]=true end
            for first=1,#mesh.indices,size do
                local last=math.min(#mesh.indices,first+size-1)
                state.phase="geometry";state.currentId=mesh.id
                local geometry=backend.Geometry(root,mesh.id..":"..tostring(first),materials[mesh.materialId])
                for i=first,last do
                    local index=mesh.indices[i]
                    backend.Vertex(geometry,mesh.positions[index],mesh.normals[index],mesh.uv0[index])
                    state.emittedVertices=state.emittedVertices+1
                    if (i-first+1)%1023==0 then progress("geometry",state.emittedVertices,expected.expandedVertices,mesh.id) end
                end
                backend.Commit(geometry);state.committedBatches=state.committedBatches+1
                progress("geometry",state.emittedVertices,expected.expandedVertices,mesh.id)
            end
            stats.meshes=stats.meshes+1;stats.triangles=stats.triangles+#mesh.indices/3
            stats.sourceVertices=stats.sourceVertices+#mesh.positions;stats.expandedVertices=stats.expandedVertices+#mesh.indices
            if options.retainMeshIds and options.retainMeshIds[mesh.id] then
                meshById[mesh.id]=mesh;prepared.meshes[#prepared.meshes+1]=mesh;stats.retainedGeometryMeshes=stats.retainedGeometryMeshes+1
            else meshById[mesh.id]={id=mesh.id,materialId=mesh.materialId,geometryReleased=true} end
            -- Do not retain all decoded JSON or converted Lua geometry at once.
            payload=nil;single=nil;chunk=nil;mesh=nil
            state.meshFiles=fileIndex
            progress("meshComplete",fileIndex,#catalog,entry.path)
        end
        assert(stats.triangles==expected.triangles and stats.sourceVertices==expected.sourceVertices,"stream totals mismatch")
        stats.sourceObjects=0;for _ in pairs(sourceObjects) do stats.sourceObjects=stats.sourceObjects+1 end
        stats.drawables=state.committedBatches;prepared.stats=stats
        if backend.Publish then backend.Publish(root) end
        result={root=root,prepared=prepared,materials=materials,stats=stats,meshById=meshById,streamed=true}
        state.status="complete";state.phase="complete";state.currentId=nil
    end)
    local job={}
    function job.Snapshot() local out={};for k,v in pairs(state) do out[k]=v end;return out end
    function job.Step(count)
        if state.status=="failed" or state.status=="cancelled" or state.status=="complete" then return state.status end
        count=count or 1;assert(count>=1 and count<=64 and count%1==0,"invalid load work budget")
        state.stepCalls=state.stepCalls+1
        for _=1,count do
            local ok,err=coroutine.resume(co)
            if not ok then state.status="failed";state.error=tostring(err);cleanup();co=nil;break end
            if coroutine.status(co)=="dead" then co=nil;break end
        end
        return state.status
    end
    function job.Result() return result end
    function job.Cancel()
        if state.status=="failed" or state.status=="cancelled" or state.status=="complete" then return false end
        state.status="cancelled";cleanup();co=nil;return true
    end
    return job
end
-- Cooperative job: validation yields before any engine mutation; native emission
-- yields inside a bounded chunk. Call Step from Update, never a busy native loop.
function L.Begin(data,backend,options)
    options=options or {}
    local state={status="pending",phase="pending",done=0,total=0,stepCalls=0,yields=0,emittedVertices=0,committedBatches=0}
    local root,result
    local function progress(phase,done,total,id)
        state.phase=phase;state.done=done;state.total=total;state.currentId=id
        state.yields=state.yields+1;coroutine.yield()
    end
    local co=coroutine.create(function()
        local size=options.chunkVertices or 12000
        assert(type(size)=="number" and size>=3 and size<=60000 and size%3==0,"chunkVertices must be 3..60000 and divisible by three")
        state.status="validating"
        local limits={maxExpandedVertices=options.maxExpandedVertices,onProgress=progress}
        local prepared=Contract.Prepare(data,limits)
        state.status="loading";state.expected=prepared.stats
        local keys={};for key in pairs(prepared.materials) do keys[#keys+1]=key end;table.sort(keys)
        local materials={}
        for i,key in ipairs(keys) do
            state.phase="materials";state.currentId=key
            materials[key]=backend.Material(prepared.materials[key]);progress("materials",i,#keys,key)
        end
        root=backend.Begin()
        for _,mesh in ipairs(prepared.meshes) do
            state.currentId=mesh.id
            for first=1,#mesh.indices,size do
                local last=math.min(#mesh.indices,first+size-1)
                state.phase="geometry"
                local geometry=backend.Geometry(root,mesh.id..":"..tostring(first),materials[mesh.materialId])
                for i=first,last do
                    local index=mesh.indices[i]
                    backend.Vertex(geometry,mesh.positions[index],mesh.normals[index],mesh.uv0[index])
                    state.emittedVertices=state.emittedVertices+1
                    if (i-first+1)%1023==0 then progress("geometry",state.emittedVertices,prepared.stats.expandedVertices,mesh.id) end
                end
                backend.Commit(geometry);state.committedBatches=state.committedBatches+1
                progress("geometry",state.emittedVertices,prepared.stats.expandedVertices,mesh.id)
            end
        end
        prepared.stats.drawables=state.committedBatches
        if backend.Publish then backend.Publish(root) end
        result={root=root,prepared=prepared,materials=materials,stats=prepared.stats}
        state.status="complete";state.phase="complete";state.currentId=nil
    end)
    local function cleanup()
        if root then
            local ok,err=pcall(backend.Remove,root);root=nil
            if not ok then state.cleanupError=tostring(err) end
        end
    end
    local job={}
    function job.Snapshot()
        local copy={};for k,v in pairs(state) do copy[k]=v end;return copy
    end
    function job.Step(maxResumes)
        if state.status=="complete" or state.status=="failed" or state.status=="cancelled" then return state.status end
        maxResumes=maxResumes or 1
        assert(type(maxResumes)=="number" and maxResumes>=1 and maxResumes%1==0 and maxResumes<=64,"invalid load work budget")
        state.stepCalls=state.stepCalls+1
        for _=1,maxResumes do
            local ok,err=coroutine.resume(co)
            if not ok then state.status="failed";state.error=tostring(err);cleanup();co=nil;break end
            if coroutine.status(co)=="dead" then co=nil;break end
        end
        return state.status
    end
    function job.Result() return result end
    function job.Cancel()
        if state.status=="complete" or state.status=="failed" or state.status=="cancelled" then return false end
        state.status="cancelled";cleanup();co=nil;return true
    end
    return job
end
function L.Load(data,backend,options)
    options=options or {}
    -- Validate every mesh, camera, path and index before touching the engine.
    local prepared=Contract.Prepare(data,options)
    local materials={}
    for key,m in pairs(prepared.materials) do materials[key]=backend.Material(m) end
    local root=backend.Begin()
    local draws=0
    local ok,err=pcall(function()
        local size=options.chunkVertices or 60000
        assert(size>=3 and size%3==0,"chunkVertices must be divisible by three")
        for _,mesh in ipairs(prepared.meshes) do
            for first=1,#mesh.indices,size do
                local last=math.min(#mesh.indices,first+size-1)
                local geometry=backend.Geometry(root,mesh.id..":"..tostring(first),materials[mesh.materialId])
                for i=first,last do
                    local index=mesh.indices[i]
                    backend.Vertex(geometry,mesh.positions[index],mesh.normals[index],mesh.uv0[index])
                end
                backend.Commit(geometry);draws=draws+1
            end
        end
    end)
    if not ok then backend.Remove(root);error(err) end
    prepared.stats.drawables=draws
    return {root=root,prepared=prepared,materials=materials,stats=prepared.stats}
end
function L.DecodeAndLoad(text,backend,options)
    assert(type(text)=="string","scene JSON text required")
    assert(cjson and cjson.decode,"runtime JSON decoder unavailable")
    return L.Load(cjson.decode(text),backend,options)
end
return L
