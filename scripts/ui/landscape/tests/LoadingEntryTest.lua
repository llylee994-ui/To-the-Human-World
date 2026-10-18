-- 启动加载页与首次场景门禁专项；无头布局/状态，不宣称原生渲染或手机验收。
local T={}
local U=require "core.StateUtil"
local Host=require "ui.landscape.tests.ZoomTestHost"
local View=require "ui.PlayView"
local LoadingView=require "ui.landscape.LoadingView"

local function fakePreloader()
    local p={calls={},ready={},pending=nil}
    function p.IsReady(group) return p.ready[group]==true end
    function p.Begin(group,callback) p.calls[#p.calls+1]=group;p.pending=callback end
    return p
end
local function fakeLoadingView()
    local v={shown=false,group=false,pending=nil,shows=0}
    function v:Show(group,callback) self.shown=true;self.group=group;self.pending=callback;self.shows=self.shows+1 end
    function v:IsActive() return self.shown end
    function v:Hide() self.shown=false;self.pending=nil end
    return v
end

local function entryChecks()
    local R=require "debug.fixtures.ReleaseFixtures"
    local host=Host.New()
    local x=R.New()
    local preloader=fakePreloader()
    local loading=fakeLoadingView()
    local view=View.New(x.session,x.content,nil,{preloader=preloader,loadingView=loading})
    local before=x.state.GetSnapshot()
    local sounds=0
    local playSound=view.PlayObjectSound
    view.PlayObjectSound=function(id) sounds=sounds+1;return playSound(id) end

    assert(view.panel~="shop")
    view.Open("shop")
    assert(sounds==0,"gated entry must not play a placeholder/click sound")
    assert(loading.group=="seaside","shop must wait for the seaside group")
    assert(view.panel~="shop" and U.Equal(before,x.state.GetSnapshot()),"gated shop must not open or mutate state")
    preloader.ready.seaside=true
    assert(loading.pending,"loading view must hold the navigation intent")
    loading.pending()
    assert(view.panel=="shop","ready gate performs the original open once")
    assert(U.Equal(before,x.state.GetSnapshot()),"opening shop is presentation only")
    local shows=loading.shows
    view.Open("shop")
    assert(loading.shows==shows,"already-ready group must not request again")
    view.Close()

    view.Navigate("brew")
    assert(loading.group=="brew","brew must wait for its group")
    assert(view.scene~="brew")
    preloader.ready.brew=true;loading.pending()
    assert(view.scene=="brew","ready gate performs the original navigation once")
    assert(U.Equal(before,x.state.GetSnapshot()))

    view.Open("ending")
    assert(loading.group=="endings","ending must wait for its group")
    assert(view.panel~="ending")
    preloader.ready.endings=true;loading.pending()
    assert(view.panel=="ending","ready gate opens the ending once")
    assert(U.Equal(before,x.state.GetSnapshot()))
    view.root:Destroy()

    -- 已保存的结局只在展示层等待资源；门禁前后事务与写入次数不变。
    local E=require "debug.fixtures.ReleaseEndingFixtures"
    local sx,token=E.WishSeed()
    E.Must(sx.state.ConfirmEnding(E.Request(sx,{kind="wish"})))
    local endingBefore=sx.state.GetSnapshot();local endingWrites=sx.writes
    local savedPre=fakePreloader();local savedLoading=fakeLoadingView()
    local savedView=View.New(sx.session,sx.content,nil,{preloader=savedPre,loadingView=savedLoading})
    assert(savedView.panel~="ending","saved ending must not open before its group is ready")
    assert(savedLoading.group=="endings","saved ending uses the endings gate")
    assert(U.Equal(endingBefore,sx.state.GetSnapshot()) and sx.writes==endingWrites,"opening an ending must not replay its transaction")
    savedPre.ready.endings=true;savedLoading.pending()
    assert(savedView.panel=="ending","ready gate shows the already saved ending")
    assert(U.Equal(endingBefore,sx.state.GetSnapshot()) and sx.writes==endingWrites,"ending gate never re-confirms or re-awards")
    savedView.ShowTitle();savedPre.ready.endings=false
    savedView.ShowMemory({kind="wish"})
    assert(savedView.panel=="title","memory waits on title while downloading")
    savedPre.ready.endings=true;savedLoading.pending()
    assert(savedView.panel=="memoryReview" and savedView.atTitle,"first memory click must resume from the title")
    assert(U.Equal(endingBefore,sx.state.GetSnapshot()) and sx.writes==endingWrites)
    savedView.root:Destroy()
    host=nil
    print("[LoadingEntry] PASS gated navigation/open, saved ending transaction unchanged, one shot per group")
    return true
end

local function loaderStatus()
    return {state="downloading",stage="download",progress=0.2,done=1,total=3,errors={},error=nil,slow=false,
        needsDownload=true,downloadedBytes=0,totalBytes=0,ready=false}
end
local function fakeLoader()
    local l={status=loaderStatus()}
    function l.Begin(group,callback) l.group=group;l.callback=callback end
    function l.Update(_) l.updates=(l.updates or 0)+1 end
    function l.GetStatus() return U.Copy(l.status) end
    function l.WarmFrame(_) end
    function l.IsReady(group) return l.status.state=="ready" and l.group==group end
    function l.Retry() l.retried=(l.retried or 0)+1;return true end
    function l.Cancel() l.cancelled=true end
    return l
end

local mainStartupChecks
local function entryLoadingChecks()
    local loader=fakeLoader()
    local dismissed=0
    local view=LoadingView.New(loader,function() dismissed=dismissed+1 end)
    local target=0
    view:Show("core",function() target=target+1 end)
    view:Update(0.1)
    assert(target==0,"target must not assemble before resources are ready")
    assert(view.root:FindById("loadingFirst").props.visible==true,"first download note is visible")
    assert(view.root:FindById("loadingPercent"):GetText()=="已准备 1 / 3 项","no byte total uses item count")
    loader.status.state="ready";loader.status.progress=0.98
    loader.callback()
    view:Update(0.1)
    assert(target==1,"target assembles once when resources are ready")
    assert(view.root:FindById("loadingPercent"):GetText()~="100%","target frame must not claim 100% yet")
    view:Update(0.1);view:MarkRendered();view:Update(0.1)
    assert(view.root:FindById("loadingPercent"):GetText()=="100%","target render completes the 100% state")
    view:Update(0.3)
    assert(dismissed==1,"loading view dismisses once after target render")
    assert(view.root.props.visible==false,"dismiss hides the overlay")
    local updates=loader.updates;view:Update(0.1)
    assert(loader.updates==updates+1,"hidden overlay must keep background downloads running")
    view:Destroy()

    local failed=fakeLoader();failed.status.state="failed"
    local failedView=LoadingView.New(failed,function() end)
    failedView:Show("core",function() end);failedView:Update(0.1)
    assert(failedView.root:FindById("loadingRetry").props.visible==true,"failure exposes retry")
    failedView.root:FindById("loadingRetry").props.onClick()
    assert(failed.retried==1,"retry calls the loader once")
    failedView:Destroy()

    local slow=fakeLoader();slow.status.state="loading";slow.status.slow=true
    local slowView=LoadingView.New(slow,function() end)
    slowView:Show("core",function() end);slowView:Update(0.1)
    assert(slowView.root:FindById("loadingSlow").props.visible==true,"slow progress is explained")
    slowView:Destroy()
    print("[LoadingEntry] PASS gated navigation/open, target frame gate, retry and slow status")
    return mainStartupChecks()
end

mainStartupChecks = function()
    local UI=require "urhox-libs/UI"
    local cacheModule=package.loaded["urhox-libs/UI/Core/ImageCache"]
    local oldCache,oldTime=rawget(_G,"cache"),rawget(_G,"GetTime")
    local oldNvg={}
    for _,name in ipairs({"nvgBeginPath","nvgRoundedRect","nvgFillColor","nvgRGBA","nvgFill","nvgSave","nvgTranslate",
        "nvgRotate","nvgRect","nvgRestore","nvgImagePattern","nvgFillPaint"}) do
        oldNvg[name]=rawget(_G,name)
    end
    local failFirst=true
    local downloads=0
    local fakeCache={
        DownloadResources=function(_,paths,onComplete,onProgress)
            downloads=downloads+1
            if onProgress then onProgress(0,#paths,0,0) end
            if failFirst then failFirst=false;onComplete(false,1)
            else onComplete(true,0) end
            return 9
        end,
        CancelDownloadGroup=function() end,
        GetResourceAsync=function(_,_,_,callback) callback({SetLooped=function() end}) end,
    }
    package.loaded["urhox-libs/UI/Core/ImageCache"]={
        Get=function() return 1 end,GetSize=function() return 32,32 end,Release=function() end,
    }
    for _,name in ipairs({"nvgBeginPath","nvgRoundedRect","nvgFillColor","nvgRGBA","nvgFill","nvgSave","nvgTranslate",
        "nvgRotate","nvgRect","nvgRestore","nvgImagePattern","nvgFillPaint"}) do
        _G[name]=function() return 0 end
    end
    cache=fakeCache
    local host=Host.New()
    Stop()
    local Data=require "data.content"
    local originalLoad=Data.Load
    local loads=0
    Data.Load=function() loads=loads+1;return originalLoad() end
    Start()
    local state=GetStartupState()
    assert(state.hasLoader and state.hasLoading and not state.gameStarted,"formal view must wait behind the loading gate")
    local root=UI.GetRoot()
    host.Bind(root)
    local bar=assert(root:FindById("loadingBar"))
    local function tick()
        HandleUpdate("Update",{TimeStep={GetFloat=function() return 0.016 end}} --[[@as UpdateEventData]])
    end
    tick()
    local retry=assert(root:FindById("loadingRetry"))
    assert(retry.props.visible==true,"failed download exposes retry before formal assembly")
    assert(not GetStartupState().gameStarted and loads==0,"failed download must not start or load the game")
    retry.props.onClick()
    local guard=0
    while not GetStartupState().gameStarted and guard<200 do
        bar:Render({})
        tick()
        guard=guard+1
    end
    assert(GetStartupState().gameStarted,"core resources must eventually assemble the target")
    assert(root:FindById("playPanel")~=nil,"formal game root is added behind the overlay")
    guard=0
    while root:FindById("loadingRoot").props.visible~=false and guard<80 do
        bar:Render({})
        tick()
        guard=guard+1
    end
    assert(root:FindById("loadingRoot").props.visible==false,"overlay dismisses after target frames")
    assert(loads==1,"retry after a failed download must load the game once, not twice")
    tick();tick();tick()
    assert(downloads>=5,"main queues all three background groups after core retry")
    Stop()
    Start();Stop() -- repeated start/stop must not leave a second loader or target
    -- 引擎 cache 是 _G.__index getter，不是 rawget 可见的字段。
    local oldMeta=getmetatable(_G)
    cache=nil
    setmetatable(_G,{__index=function(t,key)
        if key=="cache" then return fakeCache end
        local index=oldMeta and oldMeta.__index
        if type(index)=="function" then return index(t,key) end
        if type(index)=="table" then return index[key] end
    end})
    Start()
    local nativeState=GetStartupState()
    Stop();setmetatable(_G,oldMeta)
    assert(nativeState.hasLoader and not nativeState.gameStarted,"native cache getter must activate the startup gate")
    Data.Load=originalLoad
    package.loaded["urhox-libs/UI/Core/ImageCache"]=cacheModule
    cache=oldCache;GetTime=oldTime
    for name,value in pairs(oldNvg) do _G[name]=value end
    print("[LoadingEntry] PASS main gate, target after readiness, no input/music before target, Start/Stop cleanup")
    return true
end
function T.Run()
    local suite=rawget(_G,"PRELOAD_SUITE")
    if suite=="entry" then return entryLoadingChecks() end
    if suite=="navigation" then return entryChecks() end
    error("unknown or missing PRELOAD_SUITE")
end
return T
