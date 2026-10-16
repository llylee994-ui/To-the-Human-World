local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local must=E.Must
local T={}
function T.Run()
    local check,done=R.Checks("EndingPresentation")
    check("automatic apprentice route; no wish bypass; same day",function()
        local x=E.SmallComplete(10000);E.Homes(x)
        local day=x.state.GetSnapshot().live.gameFlow.day
        must(x.state.NextDay())
        local ep=must(x.session.queries.GetEpilogueView())
        assert(ep.route=="apprentice" and ep.step=="dawn")
        assert(x.state.GetSnapshot().live.gameFlow.day==day)
        assert(not x.state.BeginWish(E.Request(x)).ok)
        assert(not x.state.ConfirmEnding(E.Request(x,{kind="apprentice"})).ok)
        must(x.state.AdvanceEpilogue(E.Request(x,{expectedStep="dawn"})))
        assert(x.Reload());assert(must(x.session.queries.GetEpilogueView()).step=="letter")
        must(x.state.ConfirmEnding(E.Request(x,{kind="apprentice"})))
        assert(#must(x.session.queries.GetEndingView()).memories==1)
    end)
    check("special bottle survives reload without consuming daily salvage",function()
        local x=E.SmallComplete();must(x.state.NextDay())
        local flow=U.Copy(x.state.GetSnapshot().live.gameFlow)
        assert(not x.state.BeginWish(E.Request(x)).ok)
        local request=E.Request(x,{expectedStep="dawn"})
        must(x.state.AdvanceEpilogue(request));assert(not x.state.AdvanceEpilogue(request).ok)
        assert(x.Reload());assert(must(x.session.queries.GetEpilogueView()).step=="shore")
        assert(not x.state.BeginWish(E.Request(x)).ok)
        must(x.state.AdvanceEpilogue(E.Request(x,{expectedStep="shore"})))
        assert(x.Reload());must(x.state.BeginWish(E.Request(x)))
        assert(U.Equal(flow,x.state.GetSnapshot().live.gameFlow))
    end)
    local base,token=E.WishSeed()
    check("collage layout, consumed words, undo data and frozen keepsake",function()
        local x=E.Clone(base);local words=must(x.session.queries.GetWishView()).samples
        local second=words[2].sourceTokenId
        local layout={{sourceTokenId=token,x=.66,y=.46,angle=9},{sourceTokenId=second,x=.24,y=.31,angle=-6}}
        local inventory=U.Copy(x.state.GetSnapshot().live.wordTokens)
        must(x.state.UpdateWishLayout(E.Request(x,{placements=layout})));assert(x.Reload())
        local wish=must(x.session.queries.GetWishView())
        assert(U.Equal(wish.placements,layout) and wish.draftSourceIds[1]==second)
        assert(U.Equal(inventory,x.state.GetSnapshot().live.wordTokens))
        local request=E.Request(x,{kind="wish"});must(x.state.ConfirmEnding(request))
        local ending=must(x.session.queries.GetEndingView()).ending
        assert(U.Equal(ending.collage.placements,layout))
        must(x.state.ConfirmEnding(request));assert(#must(x.session.queries.GetEndingView()).memories==1)
        must(x.state.RestoreEndingCheckpoint(E.Request(x)))
        local restored=x.state.GetSnapshot();assert(restored.chapter.phase=="operating")
        assert(U.Equal(restored.chapter.memories[1].ending,ending))
        must(x.state.StartNewPlaythrough(E.Request(x)));assert(x.Reload())
        local fresh=x.state.GetSnapshot()
        assert(fresh.live.gameFlow.day==1 and #must(x.session.queries.GetWishView()).samples==0)
        assert(U.Equal(fresh.chapter.memories[1].ending,ending))
        local view=must(x.session.queries.GetEndingView());view.memories[1].ending.text="changed"
        assert(x.state.GetSnapshot().chapter.memories[1].ending.text==ending.text)
    end)
    check("reject duplicate, invented, nonfinite, out of bounds and stale layouts",function()
        local x=E.Clone(base);local before=x.state.GetSnapshot()
        local good={sourceTokenId=token,x=.5,y=.3,angle=0}
        local bads={{good,good},{{sourceTokenId="invented",x=.5,y=.3,angle=0}},
            {{sourceTokenId=token,x=0/0,y=.3,angle=0}},{{sourceTokenId=token,x=2,y=.3,angle=0}},
            {{sourceTokenId=token,x=.5,y=.3,angle=90}}}
        for _,rows in ipairs(bads) do assert(not x.state.UpdateWishLayout(E.Request(x,{placements=rows})).ok) end
        assert(not x.state.UpdateWishLayout({placements={good},expectedRevision=0}).ok)
        assert(U.Equal(before,x.state.GetSnapshot()))
    end)
    check("ending cannot freeze source ids that differ from the saved paper",function()
        local x=E.Clone(base);local before=x.state.GetSnapshot()
        local samples=must(x.session.queries.GetWishView()).samples
        local result=require("systems.ReleaseEndings").New(x.content).PlanEnding(before,
            E.Request(x,{kind="wish",sourceTokenIds={samples[2].sourceTokenId}}))
        assert(not result.ok and result.error.code=="STALE_WISH_DRAFT")
        assert(U.Equal(before,x.state.GetSnapshot()))
    end)
    for _,name in ipairs({"AdvanceEpilogue","UpdateWishLayout","StartNewPlaythrough"}) do
        for _,fault in ipairs({"write","uncertain"}) do
            check(name.." atomic "..fault,function()
                local x=E.Clone(base)
                if name=="AdvanceEpilogue" then
                    must(x.state.RestoreEndingCheckpoint(E.Request(x)));must(x.state.BeginClosing(E.Request(x)))
                end
                local before=x.state.GetSnapshot();x.commitWritten=false;x.fault=fault
                local args=name=="AdvanceEpilogue" and {expectedStep="dawn"}
                    or name=="UpdateWishLayout" and {placements={{sourceTokenId=token,x=.7,y=.4,angle=5}}} or {}
                local r=x.state[name](E.Request(x,args))
                assert(not r.ok and U.Equal(before,x.state.GetSnapshot()))
                x.fault=false;assert(x.state.ReloadCurrent())
                if fault=="write" then assert(U.Equal(before,x.state.GetSnapshot()))
                else assert(x.state.GetSnapshot().revision==before.revision+1) end
            end)
        end
    end
    check("old wish without layout remains readable and acquires layout on edit",function()
        local x=E.Clone(base);local d=x.state.GetSnapshot()
        d.chapter.wishLayout=nil;d.chapter.epilogue=nil;d.chapter.memories=nil;d.chapter.started=nil
        assert(x.save.Save("b5_flow",d,4));assert(x.Reload())
        local w=must(x.session.queries.GetWishView());assert(#w.placements==1)
        must(x.state.UpdateWishLayout(E.Request(x,{placements={{sourceTokenId=token,x=.3,y=.3,angle=-5}}})))
        must(x.state.ConfirmEnding(E.Request(x,{kind="wish"})))
        assert(x.Reload())
    end)
    return done()
end
return T
