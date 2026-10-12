local UI=require "urhox-libs/UI"
local EngineUI=require "urhox-libs/UI/Core/UI"
local Motion=require "ui.landscape.HomeYawMotion"
local SceneView=require "ui.landscape.HomeYawScene"
local P={}
function P.New(parent,onClosed)
    local a={motion=Motion.New(),closed=false --[[@as boolean]],closeRequested=false --[[@as boolean]]}
    local root=UI.Panel {id="homeYawProbe",position="absolute",left=0,top=0,width="100%",height="100%",
        zIndex=2000,backgroundColor={18,23,29,255},overflow="hidden",onClick=function() end}
    a.root=root;parent:AddChild(root)
    local bar=UI.Panel {width="100%",minHeight=52,flexShrink=0,flexDirection="row",alignItems="center",gap=8,padding=4}
    bar:AddChild(UI.Label {text="开发验证 · 原地向右转头",fontSize=16,fontColor={255,255,255,255},flexGrow=1,minWidth=0})
    root:AddChild(bar)
    local status=UI.Label {id="homeYawStatus",fontSize=13,fontColor={220,230,240,255},height=40,flexShrink=0,whiteSpace="normal",paddingLeft=8,pointerEvents="none"}
    root:AddChild(status)
    local canvas=UI.Panel {id="homeYawCanvas",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,pointerEvents="none"}
    root:AddChild(canvas)
    local hint=UI.Label {text="蓝墙＝前方；橙墙＝右方；红块在上方。仅几何体实验，未接正式美术。",height=30,fontSize=13,fontColor={220,230,240,255},pointerEvents="none"}
    root:AddChild(hint)
    local renderer,err=SceneView.New();a.renderer=renderer
    local function fail(message)
        a.error=tostring(message);a.motion.Reset("failed")
        if a.renderer then a.renderer.Close();a.renderer=nil end
        status:SetText("验证画面创建失败；关闭后可重试。"..a.error)
        print("[HomeYawProbe] ERROR "..a.error)
    end
    local function refreshStatus()
        status:SetText(string.format("固定位置 (0, 1.65, 0) · FOV 50° · 俯仰 8° · yaw %.1f° → %.1f° · %.2f / %.2f 秒 · %s",
            a.motion.yaw,Motion.endYaw,a.motion.elapsed,Motion.duration,a.motion.reason))
    end
    function a.Reset(reason)
        if a.closed or not a.renderer then return end
        a.motion.Reset(reason);a.renderer.SetYaw(a.motion.yaw);a.renderer.Sample(0,a.motion.reason);refreshStatus()
    end
    function a.Play()
        if a.closed or not a.renderer or not a.motion.Play() then return false end
        a.renderer.SetYaw(a.motion.yaw);a.renderer.Sample(0,"playing");refreshStatus();return true
    end
    function a.Close()
        if a.closed then return end
        a.closed=true;a.motion.Reset("closed")
        if a.renderer then a.renderer.Close();a.renderer=nil end
        root:Destroy();onClosed();print("[HomeYawProbe] closed; resources released")
    end
    bar:AddChild(UI.Button {id="homeYawPlay",text="播放",width=76,minHeight=44,onClick=function() a.Play() end})
    bar:AddChild(UI.Button {id="homeYawReset",text="复位",width=76,minHeight=44,onClick=function() a.Reset("reset") end})
    bar:AddChild(UI.Button {id="homeYawClose",text="关闭",width=76,minHeight=44,onClick=function() a.closeRequested=true end})
    function canvas:Render(vg)
        if a.closed or not a.renderer then return end
        local l=self:GetAbsoluteLayout();local w=math.min(l.w,l.h*Motion.aspect);local h=w/Motion.aspect
        if w<=0 or h<=0 then return end
        local ok,message=pcall(a.renderer.Draw,vg,l.x+(l.w-w)/2,l.y+(l.h-h)/2,w,h)
        if not ok then fail(message) end
    end
    function a.Update()
        if a.closed then return end
        if a.closeRequested then a.Close();return end
        if not a.renderer then return end
        local ok,message=pcall(function()
            local l=canvas:GetAbsoluteLayout();local scale=EngineUI.GetScale()
            if l.w<=0 or l.h<=0 then
                if a.motion.active then a.Reset("hidden") end
                return
            end
            if l.w>0 and l.h>0 then
                local size=string.format("%.2f:%.2f",l.w,l.h)
                if a.size and a.size~=size then a.Reset("resized") end
                a.size=size;a.renderer.Resize(l.w*scale,l.h*scale)
            end
            local clock=GetTime()
            local dt=clock:GetTimeStep();local now=clock:GetElapsedTime()
            if a.lastTime and now-a.lastTime>.25 then dt=.26 end
            a.lastTime=now
            -- A standalone visual probe may run unfocused for background capture;
            -- minimization or a clock gap resets it without touching gameplay.
            if a.motion.Update(dt,not input:IsMinimized()) then
                a.renderer.SetYaw(a.motion.yaw);a.renderer.Sample(a.motion.elapsed,a.motion.reason);refreshStatus()
            end
            -- Also refresh while idle to accommodate asynchronously available builtin resources.
            if a.renderer.surface then a.renderer.surface:QueueUpdate() end
        end)
        if not ok then fail(message) end
    end
    if not renderer then fail(err) else a.Reset("ready") end
    return a
end
return P
