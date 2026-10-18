local T={}
function T.Run()
    local S=require "ui.landscape.ArrivalSequence"
    local s=S.New();assert(not s.active)
    assert(s.Begin() and not s.Begin(),"repeated starts cannot reset the opening")
    local entered=0
    local function tick(dt,focused,ready)
        if s.Update(dt,focused,ready)=="enter" then entered=entered+1 end
        return s.Presentation()
    end
    assert(tick(.1,true,true).blackAlpha>0 and s.phase=="out")
    local before=s.elapsed;tick(.1,false,true);assert(s.elapsed==before,"background pauses the opening")
    for _=1,3 do tick(.1,true,true) end
    assert(entered==1 and s.phase=="room","scene switches at opaque black only once")
    for _=1,30 do tick(.1,true,false) end
    assert(s.phase=="room" and s.Presentation().blackAlpha==1,"unready room stays hidden")
    for _=1,8 do tick(.1,true,true) end
    local p=s.Presentation()
    assert(p.blackAlpha==0 and p.narrationAlpha==0,"room emerges before narration")
    for _=1,3 do tick(.1,true,true) end
    p=s.Presentation();assert(p.paperAlpha==1 and s.phase=="narration","paper lights before narration")
    for _=1,5 do tick(.1,true,true) end
    p=s.Presentation()
    assert(not s.active and p.paperAlpha==1 and p.narrationAlpha==1 and entered==1,"opening finishes without another scene command")
    s.Begin();s.Cancel();assert(not s.active and not s.Update(1,true,true),"cancelled opening never enters later")
    print("[ArrivalSequence] PASS ordered fades, one scene switch, pause, layout wait, cancellation")
    return true
end
return T
