-- Stable base-coordinate events and real save transactions; no native-device claim.
local T={}
function T.Run()
    local UI=require "urhox-libs/UI"
    UI.MeasureTextWidth=UI.MeasureTextWidth or function(s,n) return utf8.len(s)*n end
    local U=require "core.StateUtil"
    local count=0
    local function check(ok,why) count=count+1;assert(ok,why) end
    local End=require "ui.landscape.DepartureView"
    for _,vp in ipairs({{w=1920,h=1080},{w=1206,h=540},{w=960,h=540}}) do
        for _,safe in ipairs({{left=0,right=0,top=0,bottom=0},{left=48,right=0,top=8,bottom=12},{left=0,right=48,top=8,bottom=12}}) do
            local l=End.Layout(vp,safe)
            for _,r in ipairs({l.heading,l.subtitle,l.button}) do check(math.abs(r.x+r.w/2-vp.w/2)<1,"all ending controls use full-screen center") end
            check(l.button.y>=safe.top and l.button.y+l.button.h<=vp.h-safe.bottom,"return button inside vertical safe area")
        end
    end
    local Layout=require "ui.landscape.WishLayout"
    local l=Layout.Compute({w=1206,h=540},{left=40,right=0,top=0,bottom=12},false,2)
    check(l.paper.w>800 and l.paper.h>390 and l.paper.y<100,"wide letter fills work area")
    check(l.actions.y+l.actions.h<=l.paper.y,"main actions above paper")
    local C=require "systems.WishCollage"
    local legacy={{sourceTokenId="token",x=.5,y=.5,angle=0,scale=1}}
    local wide=C.ForCanvas(legacy,2)
    check(wide[1].canvasAspect==2 and legacy[1].canvasAspect==nil,"canvas conversion never mutates legacy source")
    check(C.Aspect(legacy)==4/3 and C.Aspect(wide)==2,"old keepsakes retain old aspect")
    check(C.Validate(legacy,{token=true}).ok,"legacy canvas still validates")
    local bad=U.Copy(wide);bad[1].canvasAspect=1.7
    check(not C.Validate(bad,{token=true}).ok,"unsupported canvas basis rejects")
    bad=U.Copy(wide);bad[2]={decorationId="daisy",instanceId="decor:1",x=.7,y=.7,angle=0}
    check(not C.Validate(bad,{token=true}).ok,"mixed legacy/wide rows reject")
    local P=require "ui.landscape.WishPaper"
    local G=require "ui.landscape.WishGestures"
    ---@return any
    local function event(x,y,id) return {x=x,y=y,pointerId=id or 1,pointerType="touch",isPrimary=true,IsPrimaryAction=function() return true end,StopPropagation=function() end} end
    ---@return table
    local function harness(locked)
        local parent=UI.Panel{};local rows={{sourceTokenId="token",x=.5,y=.5,angle=0,scale=1,canvasAspect=2,locked=locked}}
        local rect={x=300,y=80,w=900,h=450};local words={token="安安稳稳"}
        local paper=P.New(parent,rect,{placements=rows,words=words},{editable=true})
        local calls,latest=0,nil
        local view={root=parent,Live=function() return true end}
        local ctx={viewport={w=1280,h=600}}
        local selected=false
        local g=G.Bind(view,ctx,paper,rows,words,function(id) selected=id end,function(nextRows) calls=calls+1;latest=U.Copy(nextRows);return true end)
        return {paper=paper,rows=rows,view=view,ctx=ctx,g=g,event=event,node=paper.cards.token.root,
            result=function() return calls,latest,selected end}
    end
    local h=harness();local center={x=750,y=305}
    h.node.props.onPointerDown(event(center.x-18,center.y+6))
    h.node.props.onPointerMove(event(center.x+82,center.y+46))
    h.node.props.onPointerMove(event(center.x+142,center.y+66))
    check(math.abs(h.paper.cards.token.display.x-(.5+160/900))<.001,"moving node cannot double pointer delta")
    check(h.result()==0,"drag previews never save")
    h.node.props.onPointerUp(event(center.x+142,center.y+66));local n,rows=h.result()
    check(n==1 and math.abs(rows[1].y-(.5+60/450))<.001,"release saves whole movement once with grab offset")
    h.node.props.onPointerUp(event(900,400));check(h.result()==1,"duplicate release ignored")
    h=harness();h.g.Select("token")
    local handle=h.view.root:FindById("wishHandle_scale")
    check(handle.props.width>=48 and handle.props.height>=48,"large handle touch targets")
    handle.props.onPointerDown(event(850,305));handle.props.onPointerMove(event(1000,305));handle.props.onPointerUp(event(1000,305))
    n,rows=h.result();check(n==1 and rows[1].scale>2.3,"distance-based resize responds strongly")
    h=harness();h.node.props.onPointerDown(event(750,305));h.node.props.onPointerMove(event(800,330));h.g.Update(.016,false)
    h.node.props.onPointerUp(event(800,330));check(h.result()==0 and not h.view.busy,"focus loss cancels gesture without saving")
    h=harness(true);h.node.props.onPointerDown(event(750,305));h.node.props.onPointerMove(event(800,330));h.node.props.onPointerUp(event(800,330))
    check(h.result()==0,"locked objects cannot move")
    h=harness();local source=UI.Panel{width=100,height=50} --[[@as table]]
    source.GetAbsoluteLayout=function() return {x=50,y=100,w=100,h=50} end
    h.g.Source(source,function() return {decorationId="daisy",instanceId="decor:1",canvasAspect=2} end)
    source.props.onPointerDown(event(80,120),source);source.props.onPointerUp(event(80,120),source);check(h.result()==0,"tap never takes a tray piece")
    source.props.onPointerDown(event(80,120),source);source.props.onPointerMove(event(240,300),source);source.props.onPointerUp(event(240,300),source);check(h.result()==0,"outside release never takes a piece")
    source.props.onPointerDown(event(80,120),source);source.props.onPointerMove(event(700,300),source);source.props.onPointerUp(event(700,300),source)
    n,rows=h.result();check(n==1 and #rows==2 and rows[2].decorationId=="daisy","direct tray drag commits only inside paper")
    h=harness();h.g.Select("token")
    local rotate=h.view.root:FindById("wishHandle_rotate")
    rotate.props.onPointerDown(event(850,305))
    for i=1,10 do local a=math.rad(i*45);rotate.props.onPointerMove(event(750+math.cos(a)*100,305+math.sin(a)*100)) end
    rotate.props.onPointerUp(event(750,405));n,rows=h.result()
    check(n==1 and math.abs(rows[1].angle-90)<.001,"rotation continues through a full turn without angle jumps")
    h=harness();h.node.props.onPointerDown(event(750,305));h.node.props.onPointerMove(event(820,330,2));h.node.props.onPointerUp(event(820,330,2))
    check(h.result()==0 and h.view.busy,"second pointer cannot commit or replace owner")
    h.node.props.onPointerCancel(event(750,305));h.node.props.onPointerUp(event(820,330));check(h.result()==0,"cancellation never commits")
    h=harness();h.node.props.onPointerDown(event(750,305));h.node.props.onPointerMove(event(820,330));h.ctx.safeInsets={left=30};h.g.Update(.016,true)
    h.node.props.onPointerUp(event(820,330));check(h.result()==0,"safe-area change cancels live gesture")
    for _,xy in ipairs({{.07,.22},{.93,.9},{.5,.5},{.5,.9}}) do
        local bounds=P.Bounds({sourceTokenId="token",x=xy[1],y=xy[2],angle=37,scale=1},"安安稳稳",h.paper.rect)
        local r=Layout.Tools(bounds,h.paper.rect)
        check(r.y>=h.paper.rect.y+h.paper.rect.h*.19,"floating tools keep the wish prefix clear")
        check(r.x>=h.paper.rect.x and r.y>=h.paper.rect.y and r.x+r.w<=h.paper.rect.x+h.paper.rect.w and r.y+r.h<=h.paper.rect.y+h.paper.rect.h,"floating tools stay on paper at edges")
        for _,mode in ipairs({"scale","rotate"}) do local handle=Layout.Handle(bounds,h.paper.rect,mode)
            check(r.x+r.w<=handle.x or handle.x+handle.w<=r.x or r.y+r.h<=handle.y or handle.y+handle.h<=r.y,"floating tools do not cover handles")
        end
    end
    local E=require "debug.fixtures.ReleaseEndingFixtures"
    local x=E.WishSeed();local before=x.state.GetSnapshot();local saved=C.Get(before)
    local converted=C.ForCanvas(saved,2)
    local invalid=x.state.ConfirmEnding(E.Request(x,{kind="wish",placements=false}))
    check(not invalid.ok and U.Equal(before,x.state.GetSnapshot()),"invalid visible layout cannot seal or mutate")
    x.fault="write";local failed=x.state.ConfirmEnding(E.Request(x,{kind="wish",placements=converted}));x.fault=false
    check(not failed.ok and U.Equal(before,x.state.GetSnapshot()),"failed freeze preserves original draft and canvas")
    E.Must(x.state.ConfirmEnding(E.Request(x,{kind="wish",placements=converted})));check(x.Reload(),"wide canvas reloads")
    local ending=E.Must(x.session.queries.GetEndingView()).ending
    check(C.Aspect(ending.collage.placements)==2 and U.Equal(ending.collage.placements,converted),"visible wide composition freezes atomically")
    local sealed=x.state.GetSnapshot();local sealWrites=x.writes
    check(E.Must(x.state.ConfirmEnding(E.Request(x,{kind="wish",placements=converted}))).alreadyEnded and x.writes==sealWrites,"same visible freeze retry is idempotent")
    local changed=U.Copy(converted);changed[1].angle=15
    check(not x.state.ConfirmEnding(E.Request(x,{kind="wish",placements=changed})).ok and U.Equal(sealed,x.state.GetSnapshot()),"frozen visible layout cannot be rewritten on retry")
    local uncertain=E.Clone(E.WishSeed());local unknownCanvas=C.ForCanvas(C.Get(uncertain.state.GetSnapshot()),2)
    uncertain.fault="uncertain";local outcome=uncertain.state.ConfirmEnding(E.Request(uncertain,{kind="wish",placements=unknownCanvas}))
    check(not outcome.ok and not uncertain.state.CanMutate(),"uncertain wide freeze locks commands")
    uncertain.fault=false;check(uncertain.state.ReloadCurrent(),"uncertain wide freeze can reconcile")
    check(U.Equal(E.Must(uncertain.session.queries.GetEndingView()).ending.collage.placements,unknownCanvas),"reconciled freeze retains exact visible canvas")
    local R=require "debug.fixtures.ReleaseFixtures"
    local Input=require "ui.landscape.tests.WishTestInput"
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    x=E.WishSeed();local v=require("ui.PlayView").New(x.session,x.content)
    local function node(id) return assert(v.root:FindById(id),id) end
    local current=E.Must(x.session.queries.GetWishView()).placements[1].sourceTokenId
    check(not node("wishInspector").props.visible and not v.root:FindById("wishFooter"),"no fixed inspector or bottom toolbar")
    for _,id in ipairs({"wishRotateLeft","wishRotateRight","wishShrink","wishGrow"}) do check(not v.root:FindById(id),"removed micro-adjustment button") end
    local raw=x.state.GetSnapshot();local writes=x.writes
    Input.Select(v,current)
    check(node("wishInspector").props.visible and x.writes==writes,"tap selects and shows tools without saving or raising")
    node("wishPaper").props.onClick();check(not node("wishInspector").props.visible,"paper blank hides floating tools")
    Input.Select(v,current);v.journeyView.root.props.onClick()
    check(not node("wishInspector").props.visible,"desk blank also hides floating tools")
    check(node("wishLayerDown").props.padding[2]==2,"floating tools retain compact text padding")
    Input.Select(v,current)
    local beforeLeft,beforeTop=node("wishInspector").props.left,node("wishInspector").props.top
    local card=v.journeyView.paper.cards[current] --[[@as table]]
    local rect=v.journeyView.paper.rect
    local cx,cy=rect.x+card.display.x*rect.w,rect.y+card.display.y*rect.h
    card.root.props.onPointerDown(event(cx,cy));card.root.props.onPointerMove(event(cx+90,cy+20))
    check(node("wishInspector").props.left~=beforeLeft or node("wishInspector").props.top~=beforeTop,"tools follow live movement")
    check(x.writes==writes,"live tools movement does not save")
    card.root.props.onPointerUp(event(cx+90,cy+20));v.Update()
    check(x.state.GetSnapshot().revision==raw.revision+1,"one completed real gesture creates one revision")
    node("wishUndo").props.onClick();v.Update();check(U.Equal(raw.chapter.wishLayout,x.state.GetSnapshot().chapter.wishLayout),"one undo restores entire gesture including legacy basis")
    writes=x.writes;node("previewWish").props.onClick();v.Update();node("cancelWishPreview").props.onClick();v.Update()
    check(x.writes==writes,"preview/cancel never saves migration or draft")
    v.root:Destroy()
    print("[SecondBatchTest] PASS assertions="..count.."; headless layout/gesture/real-save checks")
    return count
end
return T
