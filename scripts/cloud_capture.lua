-- Cloud-only native capture harness. Original main.lua and business logic unchanged.
local originalPrint=print
local readyFrames=nil
local nativeWallTimes={}
function print(...)
    local first=select(1,...)
    if type(first)=="string" and first:find("[V035 FULL READY]",1,true) then readyFrames=0 end
    originalPrint(...)
end
-- Load the actual game entry instead of duplicating its configuration.
require("main")
local originalStart=Start
function Start()
    originalStart()
    SubscribeToEvent("EndRendering","CloudCaptureReadyFrame")
end
function CloudCaptureReadyFrame()
    if readyFrames==nil then return end
    if graphics:GetWidth()~=tonumber(os.getenv('D3_WIDTH') or '1170') or graphics:GetHeight()~=tonumber(os.getenv('D3_HEIGHT') or '658') then
        originalPrint('[CLOUD CAPTURE FAIL] Actual native dimensions do not match explicit D3_WIDTH/D3_HEIGHT');engine:Exit();return
    end
    readyFrames=readyFrames+1
    nativeWallTimes[#nativeWallTimes+1]=time:GetElapsedTime()
    if readyFrames<20 or readyFrames%10~=0 then return end
    local im=Image()
    local ok=graphics:TakeScreenShot(im)
    originalPrint("[CLOUD READBACK] frame="..readyFrames.." ok="..tostring(ok).." width="..tostring(im.width).." height="..tostring(im.height))
    local output=os.getenv("D3_CLOUD_CAPTURE")
    if ok and output then ok=im:SavePNG(output) else ok=false end
    originalPrint("[CLOUD NATIVE CAPTURE] "..tostring(ok).." "..tostring(output))
    if ok or readyFrames>=120 then
        local intervals={};local sum=0
        for i=7,#nativeWallTimes do local d=nativeWallTimes[i]-nativeWallTimes[i-1];intervals[#intervals+1]=d;sum=sum+d end
        table.sort(intervals)
        if #intervals>0 and output then
            local report={resolution={graphics:GetWidth(),graphics:GetHeight()},nativeFrames=readyFrames,successfulReadback=ok,
                excludedInitialFrames=6,intervalSamples=#intervals,meanFrameSeconds=sum/#intervals,
                medianFrameSeconds=intervals[math.ceil(#intervals*.5)],p95FrameSeconds=intervals[math.ceil(#intervals*.95)],
                wallClock='time:GetElapsedTime, not clamped Update dt',renderEnvironment='Mesa software GLES, not target-device performance'}
            local file=File(output..'.metrics.json',FILE_WRITE);file:WriteLine(cjson.encode(report));file:Close()
            originalPrint('[CLOUD WALL METRICS] '..cjson.encode(report))
        end
        engine:Exit()
    end
end
