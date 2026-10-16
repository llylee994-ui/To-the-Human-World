-- Real transactions/widgets with explicit geometry and pointer adapters.
-- Native Yoga/input/rendering are verified separately, never inferred here.
local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local View=require "ui.PlayView"
local T={}
function T.Run()
    local check,done=R.Checks("EndingPresentationUI")
    local function open(x)
        local host=require("ui.landscape.tests.ZoomTestHost").New()
        local v=View.New(x.session,x.content)
        local function w(id) return assert(v.root:FindById(id),"missing "..id) end
        local function tap(id) local node=w(id);assert(not node.props.disabled,id);node.props.onClick();v.Update() end
        return v,w,tap,host
    end
    local function bind(v)
        local paper=v.journeyView.paper
        for _,card in pairs(paper.cards) do
            card.root.GetAbsoluteLayout=function(self)
                return {x=paper.rect.x+self.props.left,y=paper.rect.y+self.props.top,w=card.width,h=card.height}
            end
        end
    end
    local function event(card,x,y,id)
        local p=card:GetAbsoluteLayout()
        return {x=x-p.x,y=y-p.y,pointerId=id or 1,IsPrimaryAction=function() return true end,StopPropagation=function() end}
    end
    local function down(card,id)
        local p=card:GetAbsoluteLayout();local x,y=p.x+p.w/2,p.y+p.h/2
        card.props.onPointerDown(event(card,x,y,id));return x,y
    end
    check("title start/continue is persistent; completed journey has review instead of business continue",function()
        local x=R.New(700);local v,w,tap=open(x);assert(v.ShowTitle());v.Update()
        assert(w("startJourney") and not v.root:FindById("continueJourney"))
        tap("startJourney");assert(not v.atTitle and x.state.GetSnapshot().chapter.started)
        v.ShowTitle();v.Update();tap("continueJourney");assert(v.panel==false)
        R.Must(x.state.PurchaseTravelTicket(R.Quote(x,"travel_ticket",666)));v.Refresh();v.Update()
        tap("endGame");assert(v.atTitle and w("reviewCurrentEnding") and not v.root:FindById("continueJourney"))
        local writes=x.writes;tap("openMemories");tap("memory_1")
        assert(w("releaseEndingText") and x.writes==writes)
        tap("backToMemories");tap("backToTitle");tap("startNewPlaythrough")
        local old=w("confirmNewPlaythrough").props.onClick
        tap("cancelNewPlaythrough");old();assert(x.writes==writes)
        tap("startNewPlaythrough");tap("confirmNewPlaythrough")
        assert(v.panel==false and #x.state.GetSnapshot().chapter.memories==1)
        v.Navigate("brew");v.Update();v.ShowTitle();v.Update()
        local before=x.state.GetSnapshot();v.Open("shop");v.Navigate("seaside");v.OpenPaper();v.Close();v.Update()
        assert(v.panel=="title" and U.Equal(before,x.state.GetSnapshot()))
    end)
    check("wish editor drag persists once; secondary pointer cannot take over; undo restores positions",function()
        local x,token=E.WishSeed();local v,w,tap=open(x);bind(v)
        local before=x.state.GetSnapshot();local card=w("wish_piece_"..token)
        local sx,sy=down(card);local writes=x.writes
        card.props.onPointerMove(event(card,sx+90,sy+90,2))
        card.props.onPointerUp(event(card,sx+90,sy+90,2))
        assert(v.journeyView.busy and x.writes==writes)
        card.props.onPointerMove(event(card,sx+170,sy+70));assert(x.writes==writes)
        card.props.onPointerUp(event(card,sx+170,sy+70));local saved=x.state.GetSnapshot()
        assert(saved.revision==before.revision+1 and saved.chapter.wishLayout[1].x>before.chapter.wishLayout[1].x)
        writes=x.writes;card.props.onPointerUp(event(card,sx+170,sy+70));assert(x.writes==writes)
        v.Update();tap("wishUndo");assert(U.Equal(x.state.GetSnapshot().chapter.wishLayout,before.chapter.wishLayout))
    end)
    check("outside release clamps to paper; save failure, focus loss, cancellation and destroyed callbacks do not move saved layout",function()
        local x,token=E.WishSeed();local v,w,tap,host=open(x);bind(v)
        local card=w("wish_piece_"..token);local sx,sy=down(card)
        card.props.onPointerMove(event(card,5000,-5000));card.props.onPointerUp(event(card,5000,-5000));v.Update()
        local row=x.state.GetSnapshot().chapter.wishLayout[1]
        assert(row.x<.97 and row.y>=.22)
        for _,mode in ipairs({"write","focus","cancel","destroy"}) do
            bind(v);card=w("wish_piece_"..token);local before=x.state.GetSnapshot();sx,sy=down(card)
            card.props.onPointerMove(event(card,sx-70,sy+65))
            if mode=="write" then x.fault="write";card.props.onPointerUp(event(card,sx-70,sy+65));x.fault=false;v.Update()
            elseif mode=="focus" then host.focused=false;host.Step(v,.02);host.focused=true;card.props.onPointerUp(event(card,sx-70,sy+65))
            elseif mode=="cancel" then card.props.onPointerCancel(event(card,sx,sy));card.props.onPointerUp(event(card,sx-70,sy+65))
            else v.root:Destroy();card.props.onPointerUp(event(card,sx-70,sy+65)) end
            assert(U.Equal(before,x.state.GetSnapshot()),mode)
        end
    end)
    check("apprentice view exposes only letter flow; no conditions or route choice",function()
        local x=E.SmallComplete(10000);E.Homes(x);R.Must(x.state.NextDay())
        local v,w,tap=open(x)
        for _,id in ipairs({"chooseApprentice","chooseWish","releaseProgress","apprenticeMissing"}) do assert(not v.root:FindById(id),id) end
        tap("continueEpilogue");assert(w("merchantLetterText"))
        v.ShowTitle();v.Update();tap("continueJourney");assert(w("merchantLetterText"))
        tap("finishMerchantLetter");assert(v.journeyView.busy)
        tap("skipEndingTransition");tap("endGame");assert(v.atTitle)
    end)
    check("special bottle commit precedes animation and survives interruption",function()
        local x=E.SmallComplete();R.Must(x.state.NextDay());local v,w,tap,host=open(x)
        tap("continueEpilogue")
        v.journeyView.root.GetAbsoluteLayout=function() return {x=0,y=0,w=1280,h=720} end
        local before=x.state.GetSnapshot().live.gameFlow;tap("catchEpilogueBottle")
        assert(v.journeyView.busy and R.Must(x.session.queries.GetEpilogueView()).step=="bottle")
        local writes=x.writes;v.ShowTitle();assert(not v.atTitle)
        host.focused=false;host.Step(v,.02);host.focused=true
        assert(w("openEpilogueBottle") and x.writes==writes)
        tap("openEpilogueBottle");assert(v.panel=="wish")
        assert(U.Equal(before,x.state.GetSnapshot().live.gameFlow))
    end)
    return done()
end
return T
