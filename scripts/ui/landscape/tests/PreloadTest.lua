-- 启动资源清单与预加载控制器专项。纯数据/端口，不读玩家存档或真实引擎缓存。
local T={}
local function catalogChecks()
    local M=require "ui.landscape.PreloadManifest"
    local A=require "ui.landscape.AudioCatalog"
    local Sea=require "ui.landscape.SeaArt"
    local groups=M.Groups()
    assert(#groups>=4,"missing resource groups")
    for _,name in ipairs(groups) do
        local entries=M.Group(name)
        assert(#entries>0,name.." group is empty")
        local seen={}
        for _,entry in ipairs(entries) do
            assert(type(entry.path)=="string" and entry.path~="",name.." entry has no path")
            assert(not seen[entry.path],name.." duplicate path "..entry.path)
            seen[entry.path]=true
            assert(entry.type=="Image" or entry.type=="Sound" or entry.type=="Font",name.." unknown type "..tostring(entry.type))
            assert(entry.path:match("^image/") or entry.path:match("^audio/") or entry.path:match("^fonts/"),"illegal path "..entry.path)
            if entry.type=="Sound" then assert(entry.loop==true or entry.loop==false,name.." sound loop flag missing") end
        end
    end
    assert(M.CountPath("core",Sea.background)==1,"sea background must appear once in core")
    assert(M.CountPath("seaside",Sea.background)==1,"sea background must appear once in seaside")
    assert(M.CountPath("endings",Sea.background)==1,"sea background must appear once in endings")
    assert(not M.HasPath("core","image/misty-harbor-r1/sea.png"),"historical sea image must not be listed")
    assert(not M.HasPath("core","image/title-screen-r1/shop-doorway.png"),"historical title image must not be listed")
    assert(not M.HasPath("endings","image/wish-collage-r1/table-cloth-background.png"),"historical wish background must not be listed")
    assert(not M.HasPath("core","scripts/layout-editor/.local/project.sqlite3"),"editor data must not be listed")
    for _,entry in ipairs(A.EffectEntries()) do assert(M.HasPath("core",entry.path),"effect missing from core: "..entry.path) end
    for _,entry in ipairs(A.BgmEntries()) do
        local wanted=({hearth="core",seaside="seaside",brewing="brew",traveler="endings",wish="endings"})[entry.id]
        assert(M.HasPath(wanted,entry.path),entry.id.." BGM missing from "..wanted)
    end
    print("[PreloadCatalog] PASS groups="..#groups.."; unique paths per group; audio catalog covered")
end
function T.RunCatalog() catalogChecks();return true end

local function fakeManifest()
    local groups={
        core={
            {path="image/a.png",type="Image"},
            {path="sound/a.wav",type="Sound",loop=false},
            {path="fonts/a.ttf",type="Font"},
        },
        seaside={
            {path="image/b.png",type="Image"},
            {path="sound/b.wav",type="Sound",loop=true},
        },
    }
    return {Group=function(name) return groups[name] or {} end}
end
local function resource(typeName,path)
    if typeName=="Sound" then return {SetLooped=function(self,value) self.looped=value end,path=path} end
    return {path=path}
end
local function newHost(options)
    options=options or {}
    local h={downloads=0,downloadPaths=nil,onDownload=nil,onProgress=nil,pending={},allLoads={},handles={},released={},
        layoutDirty=0,warmed=0,now=0,cancelled={},syncDownload=options.syncDownload==true,syncLoad=options.syncLoad==true}
    function h.download(paths,onComplete,onProgress)
        h.downloads=h.downloads+1;h.downloadPaths=paths;h.onDownload=onComplete;h.onProgress=onProgress
        if h.syncDownload then onComplete(true,0) end
        return 7
    end
    function h.cancelGroup(id) h.cancelled[#h.cancelled+1]=id end
    function h.loadAsync(typeName,path,callback)
        local task={typeName=typeName,path=path,callback=callback}
        h.allLoads[#h.allLoads+1]=task
        if h.syncLoad then callback(resource(typeName,path)) else h.pending[#h.pending+1]=task end
    end
    function h.DeliverRealResources()
        local rows=h.pending;h.pending={}
        for _,task in ipairs(rows) do task.callback(resource(task.typeName,task.path)) end
    end
    function h.DeliverLateCallback()
        local task=h.allLoads[#h.allLoads]
        if task then task.callback(resource(task.typeName,task.path)) end
    end
    function h.DownloadComplete(success) h.onDownload(success==true,success and 0 or 1) end
    function h.DownloadProgress(completed,total,bytes,totalBytes) if h.onProgress then h.onProgress(completed,total,bytes,totalBytes) end end
    function h.RenderWarmFrame(loader) loader.WarmFrame({}) end
    function h.imageGet(path)
        if h.handles[path]==nil then return 0 end
        return h.handles[path]
    end
    function h.imageSize(path)
        local handle=h.imageGet(path)
        if handle and handle>0 then return 32,32 end
        return 0,0
    end
    function h.imageRelease(path) h.released[#h.released+1]=path;h.handles[path]=1 end
    function h.markLayoutDirty() h.layoutDirty=h.layoutDirty+1 end
    function h.warmImage() h.warmed=h.warmed+1 end
    function h.nowValue() return h.now end
    h.ports={
        download=h.download,cancelGroup=h.cancelGroup,loadAsync=h.loadAsync,imageGet=h.imageGet,imageSize=h.imageSize,
        imageRelease=h.imageRelease,markLayoutDirty=h.markLayoutDirty,warmImage=h.warmImage,now=h.nowValue,
    }
    return h
end

local function loaderChecks()
    local P=require "ui.landscape.AssetPreloader"
    local M=fakeManifest()
    local failures={}
    local function check(name,fn)
        local ok,err=pcall(fn)
        if not ok then failures[#failures+1]=name..": "..tostring(err) end
    end
    check("download progress keeps count and bytes distinct",function()
        local h=newHost({});local l=P.New(M,h.ports)
        l.Begin("core");h.DownloadProgress(1,2,100,200)
        assert(math.abs(l.GetStatus().progress-0.35)<0.001,"half downloaded must be 35% overall")
        l.Destroy()
    end)
    check("nil resource can retry",function()
        local h=newHost({});local l=P.New(M,h.ports);local ready=0
        h.handles["image/a.png"]=1
        l.Begin("core",function() ready=ready+1 end);h.DownloadComplete(true)
        h.pending[1].callback(nil)
        assert(l.GetStatus().state=="failed","nil resource must expose failure")
        assert(l.Retry());h.DownloadComplete(true);h.DeliverRealResources();h.RenderWarmFrame(l)
        assert(l.IsReady("core") and ready==1,"retry completes original intent once")
        l.Destroy()
    end)
    check("broken image can retry",function()
        local h=newHost({syncLoad=true});h.ports.imageRelease=function() end
        local l=P.New(M,h.ports);l.Begin("core");h.DownloadComplete(true);h.RenderWarmFrame(l)
        assert(l.GetStatus().state=="failed","broken image must expose failure")
        h.handles["image/a.png"]=1
        assert(l.Retry());h.DownloadComplete(true);h.RenderWarmFrame(l)
        assert(l.IsReady("core"));l.Destroy()
    end)
    check("GPU warm exception cannot pass",function()
        local h=newHost({syncLoad=true});h.handles["image/a.png"]=1
        h.ports.warmImage=function() error("GPU warm failed") end
        local l=P.New(M,h.ports);l.Begin("core");h.DownloadComplete(true);h.RenderWarmFrame(l)
        assert(l.GetStatus().state=="failed" and not l.IsReady("core"),"failed draw cannot become ready")
        l.Destroy()
    end)
    check("cancelled prefetch callback is ignored",function()
        local h=newHost({});local l=P.New(M,h.ports)
        l.Prefetch("seaside");l.Update(0);local stale=h.onDownload
        l.Cancel();stale(true,0)
        l.Begin("seaside")
        assert(h.downloads==2,"cancelled callback cannot mark group prefetched")
        l.Destroy()
    end)
    check("return to ready group restores ready state",function()
        local h=newHost({syncDownload=true,syncLoad=true});h.handles["image/a.png"]=1
        local l=P.New(M,h.ports);l.Begin("core");h.RenderWarmFrame(l)
        l.Begin("seaside");l.Begin("core")
        assert(l.GetStatus().state=="ready" and l.IsReady("core"),"ready reuse cannot remain cancelled")
        l.Destroy()
    end)
    assert(#failures==0,table.concat(failures,"\n"))
    local h=newHost({})
    local l=P.New(M,h.ports,{imagesPerFrame=2,frameBudgetMs=1000,slowAfter=30})
    local ready=0
    assert(l.Begin("core",function() ready=ready+1 end))
    assert(h.downloads==1 and l.GetStatus().state=="downloading")
    assert(not l.IsReady("core"))
    h.DownloadComplete(true);assert(l.GetStatus().state=="loading" and ready==0)
    h.DeliverRealResources();assert(l.GetStatus().state=="warming" and ready==0)
    h.RenderWarmFrame(l);assert(l.IsReady("core") and ready==1)
    assert(l.GetStatus().progress<=0.98,"progress must not claim 100 before target frame")
    l.Destroy();h.DeliverLateCallback();assert(ready==1,"late callback after destroy must not fire")

    -- 同步缓存命中：下载/载入同步回调也先登记，再在真实预热帧后 ready。
    local sh=newHost({syncDownload=true,syncLoad=true});sh.handles["image/a.png"]=1
    local sl=P.New(M,sh.ports,{imagesPerFrame=2,frameBudgetMs=1000});local sready=0
    assert(sl.Begin("core",function() sready=sready+1 end))
    assert(not sl.IsReady("core"),"sync hit still needs a warm render frame")
    sh.RenderWarmFrame(sl);assert(sl.IsReady("core") and sready==1)
    sl.Destroy()

    -- 失败、重试与同组复用。
    local fh=newHost({});local fl=P.New(M,fh.ports,{imagesPerFrame=2,frameBudgetMs=1000});local fready=0
    fl.Begin("core",function() fready=fready+1 end)
    fh.DownloadComplete(false);assert(fl.GetStatus().state=="failed" and fready==0)
    assert(fl.Retry());assert(fh.downloads==2)
    fh.DownloadComplete(true);fh.DeliverRealResources();fh.RenderWarmFrame(fl)
    assert(fl.IsReady("core") and fready==1,"retry must finish once")
    fl.Destroy()

    local rh=newHost({});local rl=P.New(M,rh.ports,{imagesPerFrame=2,frameBudgetMs=1000});local r1,r2=0,0
    rl.Begin("core",function() r1=r1+1 end);rl.Begin("core",function() r2=r2+1 end)
    assert(rh.downloads==1,"same-group Begin must reuse the download")
    rh.DownloadComplete(true);rh.DeliverRealResources();rh.RenderWarmFrame(rl)
    assert(r1==1 and r2==1,"both same-group callbacks fire once")
    rl.Destroy()

    -- 取消后的迟到回调和下载回调不能改状态。
    local ch=newHost({});local cl=P.New(M,ch.ports,{imagesPerFrame=2,frameBudgetMs=1000});local cread=0
    cl.Begin("core",function() cread=cread+1 end);cl.Cancel()
    ch.DownloadComplete(true);ch.DeliverRealResources();ch.RenderWarmFrame(cl)
    assert(cl.GetStatus().state=="cancelled" and cread==0)
    cl.Destroy()

    -- 预取只下载；前台 Begin 复用已下载结果，再执行载入与预热。
    local ph=newHost({});local pl=P.New(M,ph.ports,{imagesPerFrame=2,frameBudgetMs=1000});local pready=0
    assert(pl.Prefetch("seaside"));pl.Update(0);assert(ph.downloads==1)
    ph.DownloadComplete(true);assert(not pl.IsReady("seaside"))
    assert(pl.Begin("seaside",function() pready=pready+1 end));assert(ph.downloads==1,"prefetched group must not download twice")
    ph.DeliverRealResources();ph.RenderWarmFrame(pl);assert(pl.IsReady("seaside") and pready==1)
    pl.Destroy()

    -- 30 秒无进展提示，有进度后复位。
    local th=newHost({});local tl=P.New(M,th.ports,{imagesPerFrame=2,frameBudgetMs=1000,slowAfter=30})
    tl.Begin("core",function() end);th.now=31;tl.Update(0);assert(tl.GetStatus().slow)
    th.DownloadProgress(1,2,10,20);tl.Update(0);assert(not tl.GetStatus().slow)
    tl.Destroy()

    print("[PreloadLoader] PASS download/load/warm gate, sync hit, retry, dedupe, cancel, prefetch, timeout")
end
function T.RunLoader() loaderChecks();return true end

function T.Run()
    local suite=rawget(_G,"PRELOAD_SUITE")
    if suite=="catalog" then return T.RunCatalog() end
    if suite=="loader" then return T.RunLoader() end
    error("unknown or missing PRELOAD_SUITE")
end
return T
