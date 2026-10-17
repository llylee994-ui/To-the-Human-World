-- Real placement, freeze and geometry checks; native hit routing is verified separately.
local T={}
function T.Run()
    local UI=require "urhox-libs/UI"
    UI.MeasureTextWidth=UI.MeasureTextWidth or function(s,n) return utf8.len(s)*n end
    local U=require "core.StateUtil"
    local P=require "ui.landscape.WishPaper"
    local C=require "systems.WishCollage"
    local E=require "debug.fixtures.ReleaseEndingFixtures"
    local count=0
    local function check(ok,why) count=count+1;assert(ok,why) end
    local flower={decorationId="daisy",instanceId="decor:1",x=-.08,y=.03,angle=135,scale=3,canvasAspect=2,freePlacement=true}
    local before=U.Copy(flower)
    P.Clamp(flower,"",900,450)
    check(U.Equal(before,flower),"free flowers retain edge position, rotation and full chosen scale")
    check(C.Validate({flower},{}).ok,"free decoration can save above and outside the letter")
    local bad=U.Copy(flower);bad.x=-2
    check(not C.Validate({bad},{}).ok,"off-workspace corruption is rejected")
    bad={sourceTokenId="word",x=.5,y=.5,angle=0,canvasAspect=2,freePlacement=true}
    check(not C.Validate({bad},{word=true}).ok,"decoration freedom cannot bypass word-source rules")
    local rows={flower,{decorationId="fern",instanceId="decor:2",x=1.12,y=1.1,angle=-60,scale=2.5,canvasAspect=2,freePlacement=true}}
    local saved=U.Copy(rows)
    for _,area in ipairs({{x=50,y=80,w=1100,h=420},{x=10,y=90,w=700,h=300}}) do
        local rect=P.FitComposition(area,rows,{},2)
        local all={{x=rect.x,y=rect.y,w=rect.w,h=rect.h}}
        for _,row in ipairs(rows) do all[#all+1]=P.Bounds(row,"",rect) end
        for _,b in ipairs(all) do
            check(b.x>=area.x-.01 and b.y>=area.y-.01 and b.x+b.w<=area.x+area.w+.01 and b.y+b.h<=area.y+area.h+.01,
                "preview includes paper and all rotated flower bounds without cropping")
        end
        local paper=P.New(UI.Panel{},rect,{placements=rows,words={}},{})
        check(U.Equal(paper.cards["decor:1"].display,flower),"read-only rendering never pushes free decoration back onto paper")
    end
    check(U.Equal(saved,rows),"fitting the complete artwork never rewrites placements")
    local old={{decorationId="daisy",instanceId="decor:1",x=.5,y=.5,angle=0,scale=1}}
    local area={x=20,y=30,w=900,h=700}
    local a=P.FitComposition(area,old,{},4/3)
    local b=require("ui.landscape.WishLayout").Fit(area,4/3)
    check(U.Equal(a,b),"old keepsakes with no overflow retain the same paper rectangle")
    local G=require "ui.landscape.WishGestures"
    local rect={x=300,y=100,w=900,h=450};local parent=UI.Panel{}
    local dragRows={{decorationId="daisy",instanceId="decor:1",x=.5,y=.5,angle=0,scale=1,canvasAspect=2,freePlacement=true}}
    local paper=P.New(parent,rect,{placements=dragRows,words={}},{editable=true,hitArea={x=240,y=0,w=1000,h=600}})
    local calls=0;local committed={} --[[@as table]]
    local view={root=parent,interactionRect={x=240,y=0,w=1000,h=600},Live=function() return true end}
    ---@return any
    local function event(x,y) return {x=x,y=y,pointerId=1,isPrimary=true,IsPrimaryAction=function() return true end,StopPropagation=function() end} end
    local gestures=G.Bind(view,{viewport={w=1280,h=600}},paper,dragRows,{},function() end,function(r) calls=calls+1;committed=U.Copy(r);return true end)
    local card=paper.cards["decor:1"].root --[[@as table]]
    card.props.onPointerDown(event(750,325));card.props.onPointerMove(event(260,80));card.props.onPointerUp(event(260,80))
    check(calls==1 and committed[1].x<0 and committed[1].y<0,"dragging across the paper edge commits the exact chosen center once")
    local source=UI.Panel{} --[[@as table]]
    source.GetAbsoluteLayout=function() return {x=40,y=100,w=100,h=50} end
    gestures.Source(source,function() return {decorationId="fern",instanceId="decor:2",x=.5,y=.5,angle=0,scale=1,canvasAspect=2,freePlacement=true} end)
    source.props.onPointerDown(event(90,125),source);source.props.onPointerMove(event(270,70),source);source.props.onPointerUp(event(270,70),source)
    check(calls==2 and #committed==2 and committed[2].x<0,"tray flowers can drop on worktable outside paper")
    require("ui.landscape.tests.ZoomTestHost").New()
    local x,id=E.WishSeed()
    local layout={{sourceTokenId=id,x=.5,y=.5,angle=0,canvasAspect=2},U.Copy(flower)}
    local original=x.state.GetSnapshot()
    x.fault="write";local failed=x.state.UpdateWishLayout(E.Request(x,{placements=layout}));x.fault=false
    check(not failed.ok and U.Equal(original,x.state.GetSnapshot()),"failed free-placement save preserves previous artwork")
    E.Must(x.state.UpdateWishLayout(E.Request(x,{placements=layout})))
    check(x.Reload() and U.Equal(E.Must(x.session.queries.GetWishView()).placements,layout),"outside decoration survives real save/reload")
    local v=require("ui.PlayView").New(x.session,x.content)
    local snapshot=x.state.GetSnapshot();local writes=x.writes
    v.root:FindById("previewWish").props.onClick();v.Update()
    check(v.panel=="wishPreview" and U.Equal(v.journeyView.paper.cards["decor:1"].display,flower),"preview retains complete chosen flower placement")
    check(U.Equal(snapshot,x.state.GetSnapshot()) and writes==x.writes,"opening preview never changes artwork or storage")
    x.fault="write";v.root:FindById("confirmWish").props.onClick();v.Update();x.fault=false
    check(v.panel=="wishPreview" and U.Equal(snapshot,x.state.GetSnapshot()),"failed seal keeps the complete overflowing preview and draft")
    v.root:FindById("confirmWish").props.onClick();v.Update()
    check(x.Reload(),"free composition ending reloads")
    local ending=E.Must(x.session.queries.GetEndingView()).ending
    check(U.Equal(ending.collage.placements,layout),"sealed keepsake freezes outside coordinates without moving or clipping")
    v.root:Destroy()
    print("[WishOverflow] PASS assertions="..count.."; free decorations, whole-art fitting, real persistence and legacy bounds")
    return count
end
return T
