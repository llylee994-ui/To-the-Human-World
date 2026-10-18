-- 启动资源控制器：下载、真实载入、图片预热与分组就绪。只持有资源引用，不播放声音。
local U=require "core.StateUtil"
local P={}
local WEIGHT_DOWNLOAD,WEIGHT_LOAD,WEIGHT_WARM=0.70,0.20,0.08
local CAP=0.98

local function indexByPath(entries)
    local rows,seen={},{}
    for _,entry in ipairs(entries or {}) do
        if type(entry)=="table" and type(entry.path)=="string" and not seen[entry.path] then
            seen[entry.path]=true;rows[#rows+1]=entry
        end
    end
    return rows
end

function P.New(manifest,ports,options)
    options=options or {}
    local api={}
    ---@type string
    local state="idle"
    ---@type string
    local stage="idle"
    local generation=0
    local activeGroup=nil
    local entries={}
    local callbacks={}
    local readyGroups={}
    local loadedPaths,warmedPaths={},{}
    local refs={}
    local failed,retried={},{}
    local groupError=nil
    local loadQueue,loadActive={},0
    local loadTotal,loadDone=0,0
    local warmQueue,warmIndex={},1
    local warmTotal,warmDone=0,0
    local downloadCompleted,downloadTotal,downloadedBytes,totalBytes=0,0,0,0
    local downloadGroup=nil
    local needsDownload=false
    local progress=0
    local lastProgressAt=0
    local slow=false
    local fontLoaded,fontMarked=false,false
    local prefetchQueue,prefetchActive,prefetched={},nil,{}
    local destroyed=false
    local maxLoads=options.maxLoads or 4
    local imagesPerFrame=options.imagesPerFrame or 2
    local frameBudget=options.frameBudgetMs and options.frameBudgetMs/1000 or 0.004
    local slowAfter=options.slowAfter or 30

    local function now()
        local value=ports.now and ports.now()
        return type(value)=="number" and value or 0
    end
    local function setProgress(value)
        value=math.max(0,math.min(CAP,value))
        if value>progress then progress=value end
    end
    local function errors()
        local rows={}
        for path,err in pairs(failed) do rows[#rows+1]={path=path,message=err} end
        table.sort(rows,function(a,b) return a.path<b.path end)
        return rows
    end
    local function totalEntries() return #entries end
    local function readyCount()
        local count=0
        for _,entry in ipairs(entries) do
            if entry.type=="Image" then if warmedPaths[entry.path] then count=count+1 end
            elseif loadedPaths[entry.path] then count=count+1 end
        end
        return count
    end
    local function callbackFor(group)
        callbacks[group]=callbacks[group] or {}
        return callbacks[group]
    end
    local function fireReady()
        state="ready";stage="ready";setProgress(CAP)
        readyGroups[activeGroup]=true
        local list=callbackFor(activeGroup)
        callbacks[activeGroup]=nil
        for _,callback in ipairs(list) do
            local ok,err=pcall(callback)
            if not ok then print("[AssetPreloader] onReady "..tostring(activeGroup)..": "..tostring(err)) end
        end
        prefetchActive=nil
    end
    local function fail(stageName,message)
        state="failed";stage=stageName;groupError=message
        generation=generation+1 -- 让同批未完成的回调失效，重试重新登记剩余项。
        loadQueue={};loadActive=0
        print("[AssetPreloader] "..tostring(activeGroup).." "..stageName..": "..tostring(message))
    end
    local function readyWhenPossible()
        if state~="loading" and state~="warming" then return end
        if loadActive>0 or #loadQueue>0 then return end
        if warmIndex<=#warmQueue then return end
        if warmTotal>0 and warmDone<warmTotal then return end
        fireReady()
    end
    local function pumpLoads()
        while loadActive<maxLoads and #loadQueue>0 and not destroyed and state=="loading" do
            local entry=table.remove(loadQueue,1)
            loadActive=loadActive+1
            local called=false
            local gen=generation
            local function done(resource)
                if called then return end
                called=true
                if gen~=generation or destroyed then return end
                if resource==nil then
                    failed[entry.path]="资源未能载入"
                    fail("load",entry.path.."：资源未能载入")
                    return
                else
                    refs[entry.path]=resource
                    loadedPaths[entry.path]=true
                    loadDone=loadDone+1
                    if entry.type=="Font" then
                        fontLoaded=true
                        if ports.markLayoutDirty then pcall(ports.markLayoutDirty) end
                    elseif entry.type=="Sound" and resource.SetLooped then
                        pcall(resource.SetLooped,resource,entry.loop==true)
                    end
                    lastProgressAt=now()
                    setProgress(WEIGHT_DOWNLOAD+WEIGHT_LOAD*(loadDone/math.max(1,loadTotal)))
                end
                loadActive=loadActive-1
                if loadDone>=loadTotal and loadActive==0 and #loadQueue==0 then
                    if warmIndex<=#warmQueue then state="warming";stage="warm" else readyWhenPossible() end
                end
                pumpLoads()
            end
            local ok,err=pcall(ports.loadAsync,entry.type,entry.path,done)
            if not ok then
                print("[AssetPreloader] load "..tostring(entry.type).." "..tostring(entry.path)..": "..tostring(err))
                done(nil)
            end
        end
    end
    local function startLoading()
        stage="load";state="loading"
        loadQueue,loadActive={},0
        loadTotal,loadDone=0,0
        for _,entry in ipairs(entries) do
            if entry.type~="Image" then
                loadTotal=loadTotal+1
                if loadedPaths[entry.path] then loadDone=loadDone+1
                else loadQueue[#loadQueue+1]=entry end
            end
        end
        warmQueue,warmIndex={},1
        warmTotal,warmDone=0,0
        for _,entry in ipairs(entries) do
            if entry.type=="Image" then
                warmTotal=warmTotal+1
                if warmedPaths[entry.path] then warmDone=warmDone+1
                else warmQueue[#warmQueue+1]=entry end
            end
        end
        if #loadQueue==0 and #warmQueue==0 then readyWhenPossible()
        else
            pumpLoads()
            if state=="loading" and loadActive==0 and #loadQueue==0 and #warmQueue>0 then state="warming";stage="warm" end
        end
    end
    local function startGroup(group,onReady,fromPrefetch)
        if fromPrefetch then return end
        if activeGroup and activeGroup~=group then api.Cancel() end
        activeGroup=group
        entries=indexByPath(manifest.Group(group))
        callbacks[group]=callbacks[group] or {}
        if onReady then callbacks[group][#callbacks[group]+1]=onReady end
        if readyGroups[group] then fireReady();return true end
        generation=generation+1
        local gen=generation
        readyGroups[group]=nil
        state="downloading";stage="download";progress=0
        failed,retried,groupError={},{},nil
        loadQueue,warmQueue={},{};warmIndex=1
        downloadCompleted,downloadTotal,downloadedBytes,totalBytes=0,0,0,0
        needsDownload=false;lastProgressAt=now();slow=false;fontLoaded=false;fontMarked=false
        local paths={}
        for _,entry in ipairs(entries) do paths[#paths+1]=entry.path end
        if #paths==0 or prefetched[group] then startLoading();return true end
        if prefetchActive then
            local prefetchGroup=prefetchActive.group
            if ports.cancelGroup and prefetchActive.groupId then pcall(ports.cancelGroup,prefetchActive.groupId) end
            prefetchActive=nil
            if prefetchGroup~=group and not prefetched[prefetchGroup] then table.insert(prefetchQueue,1,prefetchGroup) end
        end
        local ok,result=pcall(ports.download,paths,function(success,failedCount)
            if gen~=generation or destroyed or activeGroup~=group then return end
            if not success then fail("download","下载失败 "..tostring(failedCount or 0));return end
            downloadGroup=nil
            startLoading()
        end,function(completed,count,bytes,byteTotal)
            if gen~=generation or destroyed or activeGroup~=group then return end
            downloadCompleted,downloadTotal,downloadedBytes,totalBytes=completed or 0,count or 0,bytes or 0,byteTotal or 0
            if totalBytes>0 then
                setProgress(WEIGHT_DOWNLOAD*(downloadedBytes/totalBytes))
                if downloadedBytes<totalBytes then needsDownload=true end
            elseif downloadTotal>0 then
                setProgress(WEIGHT_DOWNLOAD*(downloadCompleted/downloadTotal))
            end
            lastProgressAt=now();slow=false
        end)
        if not ok then fail("download",result);return false end
        downloadGroup=result
        return true
    end
    function api.Begin(group,onReady)
        if destroyed then return false end
        if type(group)~="string" or group=="" then return false end
        if activeGroup==group and (state=="downloading" or state=="loading" or state=="warming") then
            if onReady then callbackFor(group)[#callbacks[group]+1]=onReady end
            return true
        end
        return startGroup(group,onReady,false)
    end
    function api.Prefetch(group)
        if destroyed or type(group)~="string" or group=="" or prefetched[group] or readyGroups[group] then return false end
        for _,queued in ipairs(prefetchQueue) do if queued==group then return true end end
        prefetchQueue[#prefetchQueue+1]=group
        return true
    end
    local function startPrefetch()
        if prefetchActive or destroyed or (state=="downloading" or state=="loading" or state=="warming") then return end
        local group=table.remove(prefetchQueue,1)
        if not group then return end
        local rows=indexByPath(manifest.Group(group))
        local paths={}
        for _,entry in ipairs(rows) do if not loadedPaths[entry.path] and not warmedPaths[entry.path] then paths[#paths+1]=entry.path end end
        if #paths==0 then prefetched[group]=true;return end
        local task={group=group}
        prefetchActive=task
        local ok,groupId=pcall(ports.download,paths,function(value)
            if destroyed or prefetchActive~=task then return end
            prefetchActive=nil
            if value==true then prefetched[group]=true end
        end)
        if prefetchActive==task then
            if ok then task.groupId=groupId else prefetchActive=nil end
        end
    end
    function api.Update(dt)
        if destroyed then return end
        if not slow and state~="ready" and state~="failed" and state~="cancelled" then
            local current=now()
            if current-lastProgressAt>=slowAfter then slow=true end
        end
        if (state=="idle" or state=="ready") and not prefetchActive then
            if prefetchQueue[1] then startPrefetch() end
        end
    end
    function api.WarmFrame(vg)
        if destroyed or state~="warming" then return false end
        local started=now()
        local processed=0
        while warmIndex<=#warmQueue and processed<imagesPerFrame do
            local entry=warmQueue[warmIndex]
            local handle=0
            local width,height=0,0
            if ports.imageGet then handle=ports.imageGet(entry.path) or 0 end
            if handle and handle>0 and ports.imageSize then width,height=ports.imageSize(entry.path) end
            if handle and handle>0 and (width or 0)>0 and (height or 0)>0 then
                local ok,err=true,nil
                if ports.warmImage then ok,err=pcall(ports.warmImage,vg,entry.path,handle) end
                if not ok then
                    failed[entry.path]=tostring(err);fail("warm",entry.path.."："..tostring(err));return false
                end
                warmedPaths[entry.path]=true
                warmDone=warmDone+1
                warmIndex=warmIndex+1
                setProgress(WEIGHT_DOWNLOAD+WEIGHT_LOAD+(WEIGHT_WARM*warmDone/math.max(1,warmTotal)))
                lastProgressAt=now()
            elseif retried[entry.path] then
                failed[entry.path]="图片未进入 UI 缓存"
                fail("warm",entry.path.."：图片未进入 UI 缓存");return false
            else
                retried[entry.path]=true
                if ports.imageRelease then pcall(ports.imageRelease,entry.path) end
                handle=ports.imageGet and ports.imageGet(entry.path) or 0
                if not handle or handle<=0 then
                    failed[entry.path]="图片未进入 UI 缓存"
                    fail("warm",entry.path.."：图片未进入 UI 缓存");return false
                end
            end
            processed=processed+1
            if now()-started>=frameBudget then break end
        end
        if warmIndex>#warmQueue then
            if fontLoaded and not fontMarked then fontMarked=true;if ports.markLayoutDirty then pcall(ports.markLayoutDirty) end end
            readyWhenPossible()
        end
        return state=="ready"
    end
    function api.GetStatus()
        local total=totalEntries()
        local done=readyCount()
        return U.Copy({state=state,stage=stage,progress=progress,done=done,total=total,errors=errors(),error=groupError,slow=slow,
            needsDownload=needsDownload,downloadedBytes=downloadedBytes,totalBytes=totalBytes,ready=state=="ready"})
    end
    function api.IsReady(group) return readyGroups[group]==true end
    function api.Retry()
        if destroyed or not activeGroup or state~="failed" then return false end
        local group=activeGroup
        local pending={}
        for _,entry in ipairs(entries) do
            if entry.type=="Image" then if not warmedPaths[entry.path] then pending[#pending+1]=entry end
            elseif not loadedPaths[entry.path] then pending[#pending+1]=entry end
        end
        state="downloading";stage="download";failed={};retried={};groupError=nil
        lastProgressAt=now();slow=false
        local callbacksForGroup=callbacks[group] or {}
        callbacks[group]=callbacksForGroup
        generation=generation+1
        local gen=generation
        local paths={}
        for _,entry in ipairs(pending) do paths[#paths+1]=entry.path end
        if #paths==0 then startLoading();return true end
        local ok,result=pcall(ports.download,paths,function(success,failedCount)
            if gen~=generation or destroyed then return end
            if not success then fail("download","下载失败 "..tostring(failedCount or 0));return end
            startLoading()
        end)
        if not ok then fail("download",result);return false end
        downloadGroup=result
        return true
    end
    function api.Cancel()
        generation=generation+1
        if downloadGroup and ports.cancelGroup then pcall(ports.cancelGroup,downloadGroup) end
        if prefetchActive and prefetchActive.groupId and ports.cancelGroup then pcall(ports.cancelGroup,prefetchActive.groupId) end
        downloadGroup=nil;prefetchActive=nil
        state="cancelled";stage="cancelled";loadQueue={};warmQueue={};loadActive=0;warmIndex=1
        callbacks={}
    end
    function api.Destroy()
        if destroyed then return end
        api.Cancel();destroyed=true;refs={};prefetchQueue={}
    end
    return api
end
function P.ProductionPorts()
    local ImageCache=require "urhox-libs/UI/Core/ImageCache"
    local UI=require "urhox-libs/UI"
    return {
        download=function(paths,onComplete,onProgress) return cache:DownloadResources(paths,onComplete,onProgress) end,
        cancelGroup=function(id) return cache:CancelDownloadGroup(id) end,
        loadAsync=function(typeName,path,callback)
            if typeName=="Image" then
                local handle=ImageCache.Get(path)
                callback(handle and handle>0 and {image=true,path=path} or nil)
            else
                cache:GetResourceAsync(typeName,path,callback)
            end
        end,
        imageGet=function(path) return ImageCache.Get(path) end,
        imageSize=function(path) return ImageCache.GetSize(path) end,
        imageRelease=function(path) return ImageCache.Release(path) end,
        fontVersion=function() return UI.GetFontVersion and UI.GetFontVersion() or 0 end,
        markLayoutDirty=function() if UI.MarkLayoutDirty then UI.MarkLayoutDirty() end end,
        now=function() local t=GetTime();return t and t:GetElapsedTime() or os.clock() end,
        warmImage=function(vg,path,handle)
            if not vg or not handle or handle<=0 or not nvgBeginPath then return end
            nvgBeginPath(vg);nvgRect(vg,0,0,2,2)
            nvgFillPaint(vg,nvgImagePattern(vg,0,0,2,2,0,handle,0.01));nvgFill(vg)
        end,
    }
end
return P
