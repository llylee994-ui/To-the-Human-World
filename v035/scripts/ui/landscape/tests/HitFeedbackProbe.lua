-- Opt-in runtime evidence. Dispatches through the real Yoga/input tree and holds
-- PointerDown across rendered frames; does not move the OS cursor or run commands.
local UI=require "urhox-libs/UI/Core/UI"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local G=require "ui.landscape.LayoutGeometry"
local U=require "core.StateUtil"
local P={}
function P.New()
    local phase,index="ready",1
    local deadline=0 --[[@as number]]
    local cases={}
    local snapshot=nil
    local originalOpen=nil --[[@as function?]]
    local opens=0
    local function pointer(kind,x,y)
        local scale=UI.GetScale()
        UI["Handle"..kind](Event.new(kind,{x=x*scale,y=y*scale,button=MOUSEB_LEFT,pointerType="mouse"}))
    end
    local function tap(x,y) pointer("PointerDown",x,y);pointer("PointerUp",x,y) end
    local function point(ctx,case)
        local o=ctx.home.manifest.objects[case.object]
        local layer=ctx.home.manifest.layers[o.layer];local fit=ctx.home.Fit()
        local r=G.ObjectRegion(layer,o,fit,case.region or 1)
        local x,y=G.Rotate((case.dx or 0)*r.w/2,(case.dy or 0)*r.h/2,r.rotation)
        local worldX,worldY=G.Rotate(r.x+x,r.y+y,layer.rotation)
        return fit.x+(layer.x+worldX)*fit.scale,fit.y+(layer.y+worldY)*fit.scale,o
    end
    return function(ctx)
        if phase=="done" then return end
        local now=GetTime():GetElapsedTime()
        if now<deadline then return end
        local ok,err=pcall(function()
            if phase=="ready" then
                local cache=require "urhox-libs/UI/Core/ImageCache"
                for _,l in ipairs(ctx.home.manifest.layers) do if (cache.Get(l.path) or 0)<=0 then return end end
                if ctx.home.inspect then print("[HitFeedback] CAPTURE debug-home");phase="done";return end
                snapshot=ctx.session.state.GetSnapshot()
                originalOpen=ctx.Open
                ctx.Open=function(target) opens=opens+1;originalOpen(target) end
                for i,o in ipairs(ctx.home.manifest.objects) do cases[#cases+1]={object=i,name="pressed-"..o.id} end
                cases[#cases+1]={object=1,region=2,name="pressed-drawer-second"}
                for i=1,2 do for _,d in ipairs({{-.98,0,"left"},{.98,0,"right"},{0,-.98,"top"},{0,.98,"bottom"}}) do
                    cases[#cases+1]={object=1,region=i,dx=d[1],dy=d[2],name="drawer"..i.."-"..d[3],edge=true}
                end end
                phase="down";deadline=now+20;return
            end
            local case=cases[index]
            if not case then
                assert(U.Equal(snapshot,ctx.session.state.GetSnapshot()),"navigation changed saved state")
                ctx.Open=originalOpen;phase="done"
                print("[HitFeedback] PASS normal held frames and single navigation; both handles/edges; unchanged saved state; OS mouse/device NOT verified")
                return
            end
            local x,y,o=point(ctx,case)
            if phase=="down" then
                assert(not ctx.panel and ctx.scene=="home","not at home")
                assert(not ctx.home.inspect,"normal capture must have inspection disabled")
                assert(assert(UI.FindWidgetAt(x,y)).props.id==o.id,"wrong native hit: "..case.name)
                opens=0;pointer("PointerMove",x,y);pointer("PointerDown",x,y)
                assert(ctx.home.pressed==o.id,"down missing: "..case.name)
                print("[HitFeedback] "..(case.edge and "EDGE " or "CAPTURE ")..case.name)
                phase="up";deadline=now+(case.edge and .25 or 5)
            elseif phase=="up" then
                -- Reading an existing bound letter may mark it read; do not alter player data.
                if o.target=="paper" and #ctx.session.queries.GetLetters().value>0 then
                    pointer("PointerCancel",x,y)
                    print("[HitFeedback] SKIP paper release with existing letters; held render verified, navigation covered in isolated check")
                    index=index+1;phase="down";deadline=now+.5;return
                end
                pointer("PointerUp",x,y)
                local expected=o.target=="paper" and "letters" or o.target
                assert(opens==1 and (ctx.panel or ctx.scene)==expected,"wrong/multiple navigation: "..case.name)
                assert(not ctx.home.pressed,"pressed survived release")
                phase="close";deadline=now+.5
            else
                if ctx.panel and ctx.panel~="words" and ctx.panel~="journal" then
                    local blocked=UI.FindWidgetAt(x,y)
                    assert(not blocked or blocked.props.id~=o.id,"modal leaks")
                    tap(x,y);assert(opens==1,"modal background reopened object")
                end
                local close=assert(ctx.root:FindById(ctx.panel and "closePanel" or "returnHome"))
                local b=close:GetAbsoluteLayout();tap(b.x+b.w/2,b.y+b.h/2)
                assert(not ctx.panel and ctx.scene=="home" and opens==1,"close leaks or wrong return")
                assert(U.Equal(snapshot,ctx.session.state.GetSnapshot()),"close consumed or cleared state")
                print("[HitFeedback] PASS "..case.name.." -> "..o.target.." -> home (one open, no saved change)")
                index=index+1;phase="down";deadline=now+.5
            end
        end)
        if not ok then
            phase="done";if originalOpen then ctx.Open=originalOpen end
            print("[HitFeedback] FAIL "..tostring(err))
        end
    end
end
return P
