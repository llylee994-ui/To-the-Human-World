-- Native framebuffer capture only; never dispatches input or business commands.
-- Captures are actual engine output, not reference images or proof of smooth playback.
local E={}
function E.New()
    local age,modeAge=0.0,0.0
    local mode,lastMode="Home",""
    local serial=0
    local pending=false
    local captured={}
    local stamp=os.date("!%Y%m%dT%H%M%SZ")
    local root="D:/taptap/To-the-Human-World-3D-Lab/docs/evidence/3d-lab-r3/native/"
    local e={}
    function e.Update(dt,rig)
        age=age+dt; mode=rig.mode
        if rig.busy then modeAge=0.0; return end
        if mode~=lastMode then lastMode=mode; modeAge=0.0 end
        modeAge=modeAge+dt
        local slot=math.floor(modeAge/2)
        if slot>=1 and slot<=3 and not captured[mode..":"..slot] then
            captured[mode..":"..slot]=true; pending=true
        end
    end
    function e.Frame()
        if not pending then return end
        pending=false; serial=serial+1
        local path=root..stamp.."-"..serial.."-"..mode..".png"
        local screenshot=Image()
        local capturedFrame=graphics:TakeScreenShot(screenshot)
        local saved=capturedFrame and screenshot:SavePNG(path)
        print(string.format("[D3-LAB native-capture] utc=%s elapsed=%.3f camera=%s size=%dx%d captured=%s saved=%s path=%s",
            os.date("!%Y-%m-%dT%H:%M:%SZ"),age,mode,graphics:GetWidth(),graphics:GetHeight(),tostring(capturedFrame),tostring(saved),path))
    end
    return e
end
return E
