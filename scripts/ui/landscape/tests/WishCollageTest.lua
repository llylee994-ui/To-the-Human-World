-- Real transactions and widgets; the clock/layout adapter does not claim native rendering.
local U=require "core.StateUtil"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local R=require "debug.fixtures.ReleaseFixtures"
local T={}
function T.Run()
    local check,done=R.Checks("WishCollage")
    check("mixed pieces retain free rotation, scale, locked depth and frozen memories after reload",function()
        local x,id=E.WishSeed()
        local inventory=U.Copy(x.state.GetSnapshot().live.wordTokens)
        local rows={{sourceTokenId=id,x=.4,y=.4,angle=124,scale=1.6,z=7,locked=true},
            {decorationId="paper-short",instanceId="decor:1",x=.5,y=.6,angle=-70,scale=.8,z=2},
            {decorationId="daisy",instanceId="decor:2",x=.6,y=.5,angle=45,scale=1.1,z=8},
            {decorationId="daisy",instanceId="decor:3",x=.3,y=.5,angle=-90,scale=.6,z=9}}
        E.Must(x.state.UpdateWishLayout(E.Request(x,{placements=rows})))
        assert(x.Reload());assert(U.Equal(E.Must(x.session.queries.GetWishView()).placements,rows))
        assert(U.Equal(inventory,x.state.GetSnapshot().live.wordTokens))
        E.Must(x.state.ConfirmEnding(E.Request(x,{kind="wish"})))
        assert(x.Reload());local ending=E.Must(x.session.queries.GetEndingView()).ending
        assert(U.Equal(ending.collage.placements,rows) and #ending.sourceTokenIds==1)
        assert(ending.collage.words[id] and ending.collage.words["decor:1"]==nil)
        E.Must(x.state.StartNewPlaythrough(E.Request(x)));assert(x.Reload())
        assert(U.Equal(x.state.GetSnapshot().chapter.memories[1].ending.collage,ending.collage))
    end)
    check("invalid decoration ids, duplicate instances, scales and nonfinite depth reject atomically",function()
        local x,id=E.WishSeed();local before=x.state.GetSnapshot()
        local word={sourceTokenId=id,x=.5,y=.4,angle=0}
        local flower={decorationId="daisy",instanceId="decor:1",x=.5,y=.5,angle=0}
        local cases={{word,word},{flower,flower},{{decorationId="invented",instanceId="decor:1",x=.4,y=.4,angle=0}}}
        for _,v in ipairs({0,-1,4,math.huge}) do local row=U.Copy(word);row.scale=v;cases[#cases+1]={row} end
        for _,field in ipairs({"angle","z","x"}) do local row=U.Copy(word);row[field]=0/0;cases[#cases+1]={row} end
        for _,rows in ipairs(cases) do assert(not x.state.UpdateWishLayout(E.Request(x,{placements=rows})).ok) end
        assert(U.Equal(before,x.state.GetSnapshot()))
    end)
    check("legacy token rows keep their exact shape and read order",function()
        local x,id=E.WishSeed();local rows={{sourceTokenId=id,x=.5,y=.4,angle=-5}}
        E.Must(x.state.UpdateWishLayout(E.Request(x,{placements=rows})));assert(x.Reload())
        assert(U.Equal(E.Must(x.session.queries.GetWishView()).placements,rows))
        E.Must(x.state.ConfirmEnding(E.Request(x,{kind="wish"})));assert(x.Reload())
    end)
    local function open()
        local host=require("ui.landscape.tests.ZoomTestHost").New()
        local x,id=E.WishSeed();local v=require("ui.PlayView").New(x.session,x.content)
        local function node(key) return assert(v.root:FindById(key),key) end
        local function tap(key) local n=node(key);assert(not n.props.disabled,key);n.props.onClick();v.Update() end
        return x,id,v,node,tap,host
    end
    check("wish mounts the existing drawer with its original art, category papers and close arrow",function()
        local x,id,v,node,tap,host=open()
        for _,key in ipairs({"wordTrayCloth","wordTrayFrame","wordTrayTabs","wordTrayLavender","wordTrayDriedFlowers","wordTrayFooter"}) do assert(node(key),key) end
        assert(not v.root:FindById("wishWordTray"),"must not mount a second custom tray")
        local tray=E.Must(x.session.queries.GetWordTray())
        for _,category in ipairs(tray.categories) do assert(node("wordTrayTab_"..category.id)) end
        assert(node("closePanel").props.arrowDirection=="left")
        local before=x.state.GetSnapshot();local writes=x.writes
        tap("wordTrayTab_wish_decor")
        assert(node("wish_decor_paper-short") and U.Equal(before,x.state.GetSnapshot()) and x.writes==writes)
        tap("closePanel");for _=1,20 do host.Step(v,.02) end
        assert(node("wishOpenTray"))
        tap("wishOpenTray");for _=1,20 do host.Step(v,.02) end
        assert(node("wordTrayFrame") and v.panel=="wish")
    end)
    check("wood editor keeps original word art; blank papers add independently and can repeat",function()
        local x,id,v,node,tap=open()
        assert(node("wishDeskBackdrop").props.backgroundImage=="image/wish-collage-r1/table-background.png")
        assert(node("wishPaper").props.backgroundImage=="image/wish-collage-r1/soft-scrollwork-letter-paper.png")
        assert(node("wish_visual_"..id).props.backgroundImage=="image/界面_纸条_折痕_透明_v01.png")
        local original=E.Must(x.session.queries.GetWordTray())
        local category
        for _,card in ipairs(original.cards) do if card.tokenId==id then category=card.categoryId end end
        assert(v.wishDrawerState.category==category,"initial category="..tostring(v.wishDrawerState.category)..", expected="..tostring(category))
        assert(node("wish_add_"..id).props.disabled)
        tap("wordTrayTab_wish_decor");tap("wish_decor_paper-short");tap("wish_decor_paper-short")
        local rows=E.Must(x.session.queries.GetWishView()).placements
        assert(#rows==3 and rows[2].decorationId=="paper-short" and rows[3].instanceId~=rows[2].instanceId)
        assert(not v.root:FindById("wish_text_"..rows[2].instanceId))
        tap("wishUndo");assert(#E.Must(x.session.queries.GetWishView()).placements==2)
    end)
    check("scale rotation layers and lock persist; selection does not change stacking",function()
        local x,id,v,node,tap=open()
        tap("wishGrow");tap("wishRotateRight");tap("wishLayerUp")
        local row=E.Must(x.session.queries.GetWishView()).placements[1]
        assert(row.scale>1 and row.angle>0 and row.z>1)
        tap("wishLock");local locked=E.Must(x.session.queries.GetWishView()).placements[1]
        assert(locked.locked and node("wishGrow").props.disabled and node("wishRemove").props.disabled)
        local card=node("wish_piece_"..id)
        local event={x=0,y=0,pointerId=1,IsPrimaryAction=function() return true end,StopPropagation=function() end}
        local writes=x.writes;card.props.onPointerDown(event);card.props.onPointerUp(event)
        assert(x.writes==writes and U.Equal(locked,E.Must(x.session.queries.GetWishView()).placements[1]))
        tap("wishLock");tap("wishRemove");assert(#E.Must(x.session.queries.GetWishView()).placements==0)
        tap("wishUndo");assert(#E.Must(x.session.queries.GetWishView()).placements==1)
    end)
    check("rotated scaled pieces clamp entirely to paper at compact and wide sizes",function()
        local P=require "ui.landscape.WishPaper"
        for _,width in ipairs({380,900}) do
            local row=P.Clamp({sourceTokenId="sample",x=4,y=-4,angle=135,scale=3},"长长的一段心愿",width,width*.75)
            local w,h=P.Size(row,"长长的一段心愿",width)
            local ex=(w+h)/math.sqrt(2)/2
            assert(row.x*width+ex<=width*.97+.1 and row.x*width-ex>=width*.03-.1)
            assert(row.y>=.18 and row.scale>=.25)
        end
    end)
    check("wish narration keeps frozen prose, excludes concatenated sources and ends with read-only collage",function()
        local x,id=E.WishSeed()
        E.Must(x.state.ConfirmEnding(E.Request(x,{kind="wish"})))
        local host=require("ui.landscape.tests.ZoomTestHost").New()
        local v=require("ui.PlayView").New(x.session,x.content)
        assert(v.journeyView.pages and #v.journeyView.pages==1)
        assert(v.journeyView.pages[1]=="[验收正文]wish")
        local function step(t) for _=1,math.ceil(t/.02) do host.Step(v,.02) end end
        step(1.2)
        local e={pointerId=1,IsPrimaryAction=function() return true end,StopPropagation=function() end}
        local advance=assert(v.root:FindById("departureAdvance"))
        advance.props.onPointerDown(e);advance.props.onClick(nil,e);step(3)
        local before=x.state.GetSnapshot();local writes=x.writes
        assert(v.root:FindById("endGame").props.visible)
        v.root:FindById("viewEndingCollage").props.onClick()
        assert(v.root:FindById("wishFrozenPaper").props.visible~=false)
        v.root:FindById("closeFrozenWish").props.onClick()
        assert(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes)
    end)
    check("free scale handle writes once, rejects second pointer and undoes the whole gesture",function()
        local x,id,v,node,tap=open()
        local paper=v.journeyView.paper;local card=paper.cards[id]
        card.root.GetAbsoluteLayout=function(self) return {x=paper.rect.x+self.props.left,y=paper.rect.y+self.props.top,w=card.width,h=card.height} end
        local b=card.root:GetAbsoluteLayout();local cx,cy=b.x+b.w/2,b.y+b.h/2
        local handle=node("wishHandle_scale")
        handle.GetAbsoluteLayout=function() return {x=cx+40,y=cy+40,w=38,h=38} end
        local function event(x,y,pointer) return {x=x-cx-40,y=y-cy-40,pointerId=pointer or 1,
            IsPrimaryAction=function() return true end,StopPropagation=function() end} end
        local before=x.state.GetSnapshot();local writes=x.writes
        handle.props.onPointerDown(event(cx+50,cy+50))
        handle.props.onPointerMove(event(cx+100,cy+100,2));handle.props.onPointerUp(event(cx+100,cy+100,2))
        assert(x.writes==writes and v.journeyView.busy)
        handle.props.onPointerMove(event(cx+100,cy+100));assert(x.writes==writes)
        handle.props.onPointerUp(event(cx+100,cy+100));assert(x.state.GetSnapshot().revision==before.revision+1)
        local committedWrites=x.writes;assert(committedWrites>writes)
        assert(E.Must(x.session.queries.GetWishView()).placements[1].scale>1.8)
        handle.props.onPointerUp(event(cx+100,cy+100));assert(x.writes==committedWrites)
        v.Update();tap("wishUndo");assert(U.Equal(before.chapter.wishLayout,x.state.GetSnapshot().chapter.wishLayout))
    end)
    return done()
end
return T
