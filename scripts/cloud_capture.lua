-- Cloud-only native capture harness. Original main.lua and business logic unchanged.
local originalPrint=print
local readyFrames=nil
local study=os.getenv("D3_LIGHTING_STUDY") and require("cloud_lighting_study") or nil
function print(...)
    local first=select(1,...)
    if type(first)=="string" and first:find("[V035 FULL READY]",1,true) then readyFrames=0 end
    originalPrint(...)
end
require("v035.lab35.FullSceneHost").Install({resourcePrefix="v035-full",manifestPath="manifest.json",flipV=true,maxLoadingSeconds=900,
    deferLoadingViewport=true,loadingMaxSteps=64,loadingBudgetMs=50,cloudNoLut=true,cloudHdr=true,
    onReady=study and study.Ready or nil})
local originalStart=Start
function Start()
    originalStart()
    SubscribeToEvent("EndRendering","CloudCaptureReadyFrame")
end
function CloudCaptureReadyFrame()
    if readyFrames==nil then return end
    readyFrames=readyFrames+1
    if study then study.Frame(readyFrames);return end
    if readyFrames~=20 then return end
    local im=Image()
    local ok=graphics:TakeScreenShot(im)
    local output=os.getenv("D3_CLOUD_CAPTURE")
    if ok and output then ok=im:SavePNG(output) else ok=false end
    originalPrint("[CLOUD NATIVE CAPTURE] "..tostring(ok).." "..tostring(output))
    engine:Exit()
end
