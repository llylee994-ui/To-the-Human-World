-- D3-LAB-20261012-r3-v01. Derived from scaffold-3d-scene.lua.
-- No free camera, automatic business commands, save-slot fallback or app binding.
local UI=require "urhox-libs/UI"
---@type table|nil
local app=nil
local elapsed,frames,total,worst=0.0,0,0.0,0.0
function Start()
    graphics.windowTitle="寄往人间 · 独立 3D 试验"
    UI.Init({scale=UI.Scale.DEFAULT,fonts={{family="sans",weights={normal="Fonts/MiSans-Regular.ttf"}}}})
    local ctx=require("lab.Bootstrap").New()
    local world=require("lab.World").Build()
    local rig=require("lab.CameraRig").New()
    local view=require("lab.SceneView").New(world,rig)
    local adapter=require("lab.Interaction").New(ctx,rig,world)
    app={ctx=ctx,world=world,rig=rig,view=view,adapter=adapter,hud=require("lab.Hud").New(ctx,rig,adapter,view)}
    if require("lab.QAConfig").enabled then app.qa=require("lab.NativeQA").New(app) end
    SubscribeToEvent("Update","HandleLabUpdate")
    print("[D3-LAB started] "..graphics:GetWidth().."x"..graphics:GetHeight().." actual native runtime; no assertion of visual acceptance")
end
---@param eventType string
---@param eventData UpdateEventData
function HandleLabUpdate(eventType,eventData)
    if not app then return end
    local dt=eventData["TimeStep"]:GetFloat()
    app.rig.Update(dt); app.view.Update(); app.hud.Update()
    if app.qa then app.qa.Update(dt) end
    elapsed=elapsed+dt; frames=frames+1; total=total+dt; worst=math.max(worst,dt)
    if elapsed>=5 then
        print(string.format("[D3-LAB frame] camera=%s moving=%s frames=%d meanMs=%.2f worstMs=%.2f resolution=%dx%d memoryWrites=%d",
            app.rig.mode,tostring(app.rig.busy),frames,total*1000/math.max(1,frames),worst*1000,graphics:GetWidth(),graphics:GetHeight(),app.ctx.storage.GetWriteCount()))
        elapsed,frames,total,worst=0,0,0,0
    end
end
function Stop()
    UI.Shutdown()
    if app then app.view.scene:Dispose(); app=nil end
end
