-- Catch accidental writes on drag/cancel, duplicate trial commands, and lost pending results.
-- Uses actual GameSession/PlayModel; only File, clock and native widgets are adapted.
local T={}
function T.Run()
    local U=require "core.StateUtil"
    local Data=U.Copy(require "data.content");Data.release=nil
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local UI=require "urhox-libs/UI"
    UI.MeasureTextWidth=UI.MeasureTextWidth or function(value,size) return utf8.len(value)*size end
    local F=require "debug.fixtures.B5Fixtures"
    local x=F.New(Data,{targetSchema=3})
    local model=require("ui.PlayModel").New(x.session,Data)
    local count=0
    local function check(ok,message) count=count+1;assert(ok,message) end
    ---@type BrewSmokePresentation
    local smoke=require "ui.landscape.BrewSmoke"
    check(smoke.Cover(0)==0 and smoke.Cover(.4)>0 and smoke.Cover(.4)<1 and smoke.Cover(.75)==1,"slower magic smoke grows before covering the viewport")
    check(smoke.brewDuration>=1.6 and smoke.revealDuration>=.6,"smoke gives both its rise and story reveal more time")
    local function must(r) return F.Must(r) end
    local feedback=require("ui.landscape.FeedbackMotion").New()
    check(feedback.Record("record-a",true) and not feedback.Record("record-a",true),"one saved record queues one trail")
    feedback.StartRecord({x=20,y=50},{x=500,y=80});feedback.Update(.4)
    check(feedback.record and feedback.Sample(feedback.record),"record trail has a curved intermediate position")
    check(feedback.Reward("pay-a",30,130,{x=400,y=500},{x=80,y=30}) and feedback.Currency(130)==30,"saved reward waits for its visual arrival")
    feedback.Update(.4);check(feedback.Currency(130)==30,"currency does not count up before trail arrives")
    feedback.Update(.5);feedback.Update(.25)
    check(feedback.Currency(130)>30 and feedback.Currency(130)<130,"currency counts up after the gold trail arrives")
    feedback.Update(.5);check(feedback.Currency(130)==130 and not feedback.Reward("pay-a",30,130,{},{}) ,"reward finishes once and cannot replay")
    feedback.Reward("pay-b",130,230,{x=0,y=0},{x=10,y=10});feedback.Cancel(230)
    check(feedback.Currency(230)==230 and not feedback.reward,"interruption settles the display to real currency")
    local notes=require "ui.landscape.PotionNotes"
    local defs={{id="courage",name="勇气",desc="更敢表达"},{id="fear",name="恐惧",desc="感到害怕"},{id="recall",name="忆起",desc="唤起回忆"}}
    local projection=notes.Project({orderId="some_story",requirementDesc="说清自己的决定",requirementHint={evaluated=true,canShip=false},
        potionPreview={effects={courage=1,fear=.05,recall=.6},intensityByEffect={courage="明显",fear="微弱",recall="微弱"}}},defs,{mainTokenId="token"})
    check(projection.primary and projection.primary.name=="勇气" and projection.primary.tier=="明显" and projection.primary.desc=="更敢表达","notes use strongest current effect and configured meaning")
    check(#projection.companions==2 and projection.companions[1].name=="忆起" and projection.companions[2].name=="恐惧","notes preserve every smaller effect in stable descending order")
    check(projection.status=="尚未满足" and projection.requirement=="说清自己的决定","notes retain real requirement and evaluated status")
    for _,effect in ipairs(require("data.content").effects) do
        local p=notes.Project({orderId="any",requirementHint={evaluated=true,canShip=true},potionPreview={effects={[effect.id]=.3},intensityByEffect={[effect.id]="微弱"}}},{effect},{mainTokenId="x"})
        check(p.primary and p.primary.name==effect.name and p.status=="已满足","notes support every configured effect without story-specific text")
    end
    for _,letter in ipairs(require("data.content").letters) do
        if letter.requirement then
            local p=notes.Project({orderId=letter.id,requirementDesc=letter.requirement.desc,requirementHint={}},defs,{})
            check(p.requirement==letter.requirement.desc and p.status=="等待投料","every configured commission uses its own requirement")
        end
    end
    check(notes.Project({requirementHint={}},defs,{}).status=="待接委托","unaccepted scene has no invented result")
    local received=must(model.Receive("letter_pa_01"));must(model.Read(received.letterInstanceId))
    for _,span in ipairs(must(x.modules.letters.GetView(received.letterInstanceId)).spans) do must(model.Cut(span.spanId)) end
    must(model.Accept())
    local sample=require("debug.fixtures.NumericV02Cases")[1].recipe
    local cards=must(x.session.queries.GetWordTray()).cards
    local tokens={};for _,card in ipairs(cards) do tokens[card.wordId]=card.tokenId end
    local main=assert(tokens[sample.mainWordId])
    local View=require "ui.PlayView"
    local view=View.New(x.session,Data)
    view.Navigate("brew");view.Update()
    check(view.root:FindById("brewWorkbench"),"brew scene must mount a real workbench")
    check(view.root:FindById("brewWordsHost") and view.root:FindById("brewJournalHost"),"both independent side hosts mount")
    local layout=require "ui.landscape.BrewLayout"
    for _,size in ipairs({{1280,720},{1280,576},{1600,720},{1024,768},{960,540}}) do
        local l=layout.Compute(size[1],size[2],{left=30,right=42,top=8,bottom=12})
        check(l.wish.y+l.wish.h<=l.drop.y and l.drop.y+l.drop.h<=l.summary.y,"letter then pot precede recipe")
        check(l.summary.y+l.summary.h<=l.shelf.y and l.shelf.y+l.shelf.h<=l.controls.y,"ingredients sit below shallow recipe and above action")
        check(l.summary.h<=120 and l.controls.y+l.controls.h<=size[2]-12,"shallow recipe and fixed action stay inside safe area")
        check(l.wishText.x+l.wishText.w+8<=l.wishButton.x,"letter text has its own clipped area before the button")
        check(l.drop.y>=l.wish.y+l.wish.h and l.drop.y+l.drop.h<l.summary.y,"expanded hidden drop avoids letter and recipe")
    end
    check(view.root:FindById("slot_ingredient_1") and view.root:FindById("slot_ingredient_2"),"empty ingredient slots are always visible")
    check(not view.root:FindById("brewDragText"),"drag has no item name tooltip")
    check(view.root:FindById("brewWishInfo").props.overflow=="hidden","letter glyphs are clipped to the information area")
    for _,size in ipairs({{1280,720},{1280,576},{1600,720},{1024,768}}) do
        local a=require("ui.landscape.WordTrayArt").Fit(size[1]*.26,size[2]-24)
        check(a.title.y>=60 and a.title.y+a.title.h+8<=a.cards.y,"tray title clears coins and first row")
    end
    local beforeRead=x.state.GetSnapshot()
    assert(view.root:FindById("brewLetters")).props.onClick();view.Update()
    check(view.panel=="reader" and view.model.selectedLetter==received.letterInstanceId,"banner reopens the current order letter")
    check(U.Equal(beforeRead,x.state.GetSnapshot()),"rereading accepted letter does not save or change recipe")
    view.Close();view.Update()
    local I=require "ui.landscape.BrewInteraction"
    local shown=0
    local i=I.New(view.model,function() shown=shown+1 end)
    local drop={x=500,y=260,w=160,h=100,landingX=540,landingY=290}
    local function e(x,y,id,touch) return {x=x,y=y,pointerId=id or 0,pointerType=touch and "touch" or "mouse",button=MOUSEB_LEFT} end
    local function begin(kind,id,event,vertical) return i.Begin({kind=kind,id=id,text="来源卡"},event,vertical) end
    begin("word",main,e(100,200,5,true),true)
    i.Move(e(102,203,5,true),drop,true)
    check(i.drag and i.drag.active,"a recognized high-DPI touch pan owns the card before the parent scroll can cancel it")
    i.CancelDrag()
    local before,writes=x.state.GetSnapshot(),x.writes
    begin("ingredient","ing_sea_salt",e(500,600,5,true),"horizontal");i.Move(e(540,603,5,true),drop)
    check(i.drag and i.drag.active,"horizontal touch on an ingredient starts a drag; shelf background keeps scrolling")
    i.CancelDrag()
    begin("word",main,e(100,200),true);i.Move(e(540,290),drop)
    check(i.drag and i.drag.active,"crossing threshold picks up a ghost")
    check(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes,"movement never saves or consumes")
    i.Release(e(430,290),drop)
    check(U.Equal(before,x.state.GetSnapshot()),"drop outside pot cancels")
    check(i.flight and not i.flight.accepted,"invalid drop returns without saving")
    begin("word",main,e(100,200,5,true),true);i.Move(e(100,235,5,true),drop)
    i.Move(e(540,290,5,true),drop);i.Release(e(540,290,5,true),drop)
    check(view.model.GetDraft().mainTokenId==main,"a touch that starts vertically can curve toward the pot in one gesture")
    view.brew.words.wordTray.category=Data.GetWord(sample.mainWordId).category;view.Refresh();view.Update()
    check(assert(view.root:FindById("wordTrayCard_"..main)).props.backgroundImageOpacity==.55,"a successful pot drop immediately uses the shipped dark appearance")
    i.Update(.4,true);must(view.model.TakeOut("word",main));view.Refresh();view.Update()
    check(assert(view.root:FindById("wordTrayCard_"..main)).props.backgroundImageOpacity==1,"taking a word back restores the bright tray source")
    before=x.state.GetSnapshot()
    begin("word",main,e(100,200,5,true),true);i.Move(e(540,290,5,true),drop)
    i.Release(e(540,290,6,true),drop)
    check(U.Equal(before,x.state.GetSnapshot()) and i.drag,"second finger cannot finish another finger's drag")
    i.Release(e(540,290,5,true),drop)
    check(view.model.GetDraft().mainTokenId==main,"pot release saves the exact source token")
    check(i.feedback>0,"successful save earns landing feedback")
    check(i.flight and i.flight.accepted,"saved drop starts a landing transition")
    check(i.SampleFlight().y==290-24,"release transition begins at the last displayed drag position")
    local landed=x.state.GetSnapshot();local landedWrites=x.writes
    check(not i.Start() and not i.active,"cannot brew before the item lands")
    i.Update(.038,true)
    local early=i.SampleFlight()
    check(early and early.y>290-24+3 and early.scale<.95,"release exactly above the pot immediately descends and shrinks instead of hovering")
    i.Update(.122,true)
    local frame=i.SampleFlight()
    check(frame and frame.scale<1 and frame.scale>0,"landing visibly shrinks instead of instantly disappearing")
    i.Release(e(540,290,5,true),drop);i.Update(.24,true)
    check(not i.flight and x.writes==landedWrites and U.Equal(landed,x.state.GetSnapshot()),"landing frames and duplicate release never write again")
    must(view.model.TakeOut("word",main))
    before=x.state.GetSnapshot();x.fault="write"
    begin("word",main,e(100,200),true);i.Move(e(540,290),drop);i.Release(e(540,290),drop);x.fault=false
    check(U.Equal(before,x.state.GetSnapshot()) and i.feedback==0,"failed save cannot show successful landing")
    check(not i.flight or not i.flight.accepted,"failed save has no accepted landing")
    i.Cancel()
    must(view.model.Drop("word",main))
    for _,id in ipairs(sample.auxWordIds) do must(view.model.Drop("word",assert(tokens[id]))) end
    for _,line in ipairs(sample.ingredients) do for _=1,line.quantity do must(view.model.Drop("ingredient",line.ingredientId)) end end
    view.Refresh();view.Update()
    local notesBefore,notesWrites=x.state.GetSnapshot(),x.writes
    view.root:FindById("brewRecipeDetails").props.onClick();view.Update()
    check(view.root:FindById("brewNotesTitle") and view.root:FindById("brewRequirementStatus"),"real recipe opens the shared notes paper")
    check(not view.root:FindById("brewEffectNumbers"),"weights stay collapsed by default")
    view.root:FindById("brewToggleNumbers").props.onClick();view.Update()
    check(view.root:FindById("brewEffectNumbers"),"precise weights are available on request")
    view.root:FindById("dismissIngredient").props.onClick();view.Update()
    view.root:FindById("brewRecipeDetails").props.onClick();view.Update()
    check(not view.root:FindById("brewEffectNumbers"),"reopening notes starts with qualitative information")
    view.root:FindById("dismissIngredient").props.onClick();view.Update()
    check(U.Equal(notesBefore,x.state.GetSnapshot()) and notesWrites==x.writes,"notes browsing does not save or edit the recipe")
    view.feedback.Cancel()
    before=x.state.GetSnapshot();x.fault="write";i.Start();x.fault=false
    check(not i.active and U.Equal(before,x.state.GetSnapshot()),"failed trial never starts smoke")
    check(not view.feedback.motion.record,"failed preview never queues a record trail")
    must(i.Start());check(i.active and shown==0,"saved pending precedes the smoke and reveal")
    local pending=x.state.GetSnapshot();local tid=pending.currentOrder.pending.transactionId
    check(view.feedback.motion.record and view.feedback.motion.record.id==tid,"saved pending queues feedback for its exact stored record")
    local afterWrites=x.writes
    i.Start();i.Update(.5,true);check(shown==0,"repeat start cannot skip the smoke")
    i.Skip();i.Skip();i.Update(2,true)
    check(shown==1 and x.writes==afterWrites and U.Equal(pending,x.state.GetSnapshot()),"skip reveals once without re-preview or delivery")
    local j=I.New(view.model,function() shown=shown+1 end)
    check(not j.Start(),"existing pending is opened without starting a new trial")
    check(shown==2 and not j.active and x.writes==afterWrites,"resume does not replay or write")
    must(view.model.Resolve(false))
    for _,card in ipairs(cards) do if card.tokenId==main then must(view.model.Drop("word",main)) end end
    for _,id in ipairs(sample.auxWordIds) do must(view.model.Drop("word",tokens[id])) end
    for _,line in ipairs(sample.ingredients) do for _=1,line.quantity do must(view.model.Drop("ingredient",line.ingredientId)) end end
    must(i.Start());local saved=x.state.GetSnapshot();i.Update(.2,false);i.Update(2,true)
    check(not i.active and shown==2 and U.Equal(saved,x.state.GetSnapshot()),"focus loss cancels display, retains pending and never late-reveals")
    view.Refresh();view.Update()
    check(view.brew.journal.storyId=="letter_pa_01","book defaults to active story")
    view.brew.words.Close();view.Update()
    check(not view.brew.wordsOpen and view.brew.journalOpen,"left close preserves the right book")
    view.brew.journal.Close();view.Update()
    check(not view.brew.journalOpen and view.root:FindById("brewWords"),"both side tabs remain reachable")
    local draft=view.model.GetDraft();view.Navigate("home");view.Update();view.Navigate("brew");view.Update()
    check(U.Equal(draft,view.model.GetDraft()) and view.brew.wordsOpen and view.brew.journalOpen,"reenter opens both and retains draft")
    view.Open("result");view.Update()
    local function control(id) return assert(view.root:FindById(id),"missing control "..id) end
    check(control("resultStars"):GetText():find(tostring(saved.currentOrder.pending.rating.stars),1,true),"fixed header displays stored stars explicitly")
    check(control("confirmOrder").parent.props.id=="resultActions","delivery button lives outside scroll")
    check(control("resultScroll").props.pointerEvents=="auto","result prose receives pointer hover so wheel reaches its scroll view")
    check(control("resultSeal") and control("resultFeedback").parent.props.id=="resultEcho","stored rating and feedback have their own stamp and echo")
    host.Bind(view.root)
    view.model.Notify({ok=true},"后续已保存，等待确认或重置。");view.Update()
    check(not view.panelNoticeArea.props.visible,"transient success is absent from the story reading area")
    view.Close();view.Update();check(x.state.GetSnapshot().currentOrder.pending,"close never ships")
    view.Open("result");view.Update();before=x.state.GetSnapshot();x.fault="write"
    control("confirmOrder").props.onClick();view.Update();x.fault=false
    check(view.panel=="result" and U.Equal(before,x.state.GetSnapshot()),"failed delivery retains result")
    check(not view.feedback.motion.reward,"failed delivery has no reward trail")
    check(view.panelNoticeArea.props.visible,"persistent delivery failure remains visible")
    control("resetOrder").props.onClick();view.Update()
    check(must(x.session.queries.GetAttempt(tid)).status=="reset","earlier reset is permanently stored")
    check(view.scene=="brew" and not view.panel,"reset returns to workbench")
    -- Real source callback binding, including pan arbitration and one final release.
    local mainCard=false --[[@as table|false]]
    for _,card in ipairs(cards) do if card.tokenId==main then mainCard=card end end
    view.brew.words.wordTray.category=mainCard.categoryId;view.Refresh();view.Update()
    local source=control("wordTrayCard_"..main)
    check(source.props.backgroundImageOpacity==1,"reset restores the bright tray source")
    source.props.onPointerDown(e(90,180,7,true))
    check(source:OnPanStart(e(92,183,7,true)),"the first small native touch pan is captured on a card")
    source.props.onPointerCancel(e(90,215,7,true))
    source.props.onPointerDown(e(90,180,7,true))
    local r=view.brew.layout.drop
    local release=e(r.x+r.w/2,r.y+r.h/2,7,true)
    check(source:OnPanStart(release),"horizontal source gesture owns drag")
    source.props.onPointerCancel(e(0,0,8,true))
    check(view.brew.interaction.drag,"secondary pointer cancellation cannot cancel the owning drag")
    source:OnPanEnd(release);source.props.onPointerUp(release)
    check(view.model.GetDraft().mainTokenId==main,"real source binding drops once with native-style pan/up sequence")
    local rebuilds=0;local rebuild=view.brew.Refresh
    view.brew.Refresh=function() rebuilds=rebuilds+1;rebuild() end
    view.Update()
    check(rebuilds==0 and view.model.dirty,"saved landing gets its first animation frame before rebuilding the side drawers")
    local flyingState,flyingWrites=x.state.GetSnapshot(),x.writes
    control("clearDraft").props.onClick()
    check(U.Equal(flyingState,x.state.GetSnapshot()) and flyingWrites==x.writes,"the unreplaced clear button cannot edit a saved landing in progress")
    view.brew.interaction.Update(.4,true)
    view.Update()
    check(rebuilds==1 and not view.model.dirty,"deferred draft refresh runs once after landing")
    view.brew.Refresh=rebuild
    local after=x.state.GetSnapshot();source.props.onClick()
    check(U.Equal(after,x.state.GetSnapshot()),"drag release does not trigger the source click")
    view.Refresh();view.Update()
    local ingredientSource=control("brewIngredient_ing_sea_salt")
    local ingredientSlot=view.brew.layout.slots[4] --[[@as BrewDropRect]]
    local slotEnd=e(ingredientSlot.x+ingredientSlot.w/2,ingredientSlot.y+ingredientSlot.h/2)
    ingredientSource.props.onPointerDown(e(slotEnd.x,view.brew.layout.shelf.y+35))
    ingredientSource.props.onPointerMove(slotEnd);ingredientSource.props.onPointerUp(slotEnd)
    check(view.model.GetDraft().ingredients[1].ingredientId=="ing_sea_salt","ingredient slot and pot share one real draft")
    local savedDrop=x.state.GetSnapshot();view.brew.Cancel()
    check(not view.brew.interaction.flight and U.Equal(savedDrop,x.state.GetSnapshot()),"cancelling visual flight keeps the saved ingredient")
    view.Update()
    check(not view.model.dirty and view.root:FindById("slot_ingredient_1"),"cancelled landing immediately flushes the deferred UI refresh")
    must(view.model.TakeOut("ingredient","ing_sea_salt"));view.Refresh();view.Update()
    ingredientSource=control("brewIngredient_ing_sea_salt")
    local wordSlot=view.brew.layout.slots[2] --[[@as BrewDropRect]]
    local wrongEnd=e(wordSlot.x+wordSlot.w/2,wordSlot.y+wordSlot.h/2)
    local beforeWrong=x.state.GetSnapshot()
    ingredientSource.props.onPointerDown(e(wrongEnd.x,view.brew.layout.shelf.y+35))
    ingredientSource.props.onPointerMove(wrongEnd);ingredientSource.props.onPointerUp(wrongEnd)
    check(U.Equal(beforeWrong,x.state.GetSnapshot()),"ingredient cannot land in an auxiliary word slot")
    control("slot_main").props.onClick();view.Update()
    check(view.root:FindById("brewWordDescription") and view.root:FindById("brewRemoveSlot"),"filled slot opens source details and explicit withdrawal")
    check(U.Equal(beforeWrong,x.state.GetSnapshot()),"viewing a slot cannot remove or save it")
    control("dismissIngredient").props.onClick();view.Update()
    local tapped=control("brewIngredient_ing_sea_salt")
    tapped.props.onPointerDown(e(500,600));tapped.props.onPointerUp(e(500,600));tapped.props.onClick();view.Update()
    check(view.root:FindById("brewIngredientDescription") and view.root:FindById("add_ing_sea_salt"),"ingredient detail is available on demand")
    control("dismissIngredient").props.onClick();view.Update()
    local clickBefore=x.writes
    local clickResult=view.brew.Throw("ingredient","ing_sea_salt")
    check(clickResult.ok and view.brew.interaction.flight and x.writes>clickBefore and view.model.GetDraft().ingredients[1].quantity==1,
        "click-to-add shares one saved portion and landing transition")
    local clickWrites=x.writes
    local clickSaved=x.state.GetSnapshot()
    check(not view.brew.Throw("ingredient","ing_sea_salt") and U.Equal(clickSaved,x.state.GetSnapshot()),"repeat click during landing cannot add another portion")
    view.brew.interaction.Update(.4,true)
    check(x.writes==clickWrites and U.Equal(clickSaved,x.state.GetSnapshot()),"click landing frames do not save again")
    must(view.model.TakeOut("ingredient","ing_sea_salt"));view.Refresh();view.Update()
    must(view.model.TakeOut("word",main))
    must(view.brew.words.model.Drop("word",main))
    check(view.brew.interaction.flight and view.model.dirty,"word tray click uses landing and forwards dirty state to the shared model")
    view.brew.interaction.Update(.4,true);view.Refresh();view.Update()
    must(view.model.Drop("ingredient","ing_sea_salt"));must(view.model.Drop("ingredient","ing_night_dew"))
    local full=x.state.GetSnapshot()
    view.brew.interaction.Begin({kind="ingredient",id="ing_ashen_herb",text="灰烬草"},e(400,160),false)
    local fullRelease=e(r.x+r.w/2,r.y+r.h/2)
    view.brew.interaction.Move(fullRelease,r)
    check(view.brew.interaction.drag.active,"full-slot check actually drags an ingredient into the pot")
    view.brew.interaction.Release(fullRelease,r)
    check(U.Equal(full,x.state.GetSnapshot()) and view.brew.interaction.feedback==0,"full ingredient slots reject drag without changing the recipe")
    for _,size in ipairs({{1280,720},{1280,576},{1600,720},{1024,768}}) do
        local l=require("ui.landscape.BrewLayout").Compute(size[1],size[2],{left=30,right=42,top=8,bottom=12})
        check(l.drop.x>=l.center.x and l.drop.x+l.drop.w<=l.center.x+l.center.w,"pot remains between the drawers")
        check(l.controls.y+l.controls.h<=size[2]-12,"fixed action stays inside bottom safe area")
    end
    local mobile=layout.Compute(1200,540,{left=48,right=0,top=0,bottom=0})
    check(mobile.pot.h>=180,"short phone screen gives the cauldron useful height instead of a miniature")
    local sub=view.brew.words;sub.safeInsets={left=48,right=0,top=0,bottom=0}
    require("ui.landscape.WordTrayDrawer").State(sub).open=1
    require("ui.landscape.WordTrayDrawer").Render(sub,require("urhox-libs/UI").Panel {})
    check(sub.wordTray.panel.props.left==0,"workbench word tray bleeds to the left screen edge even with a notch inset")
    local leftClose=view.brew.words.wordTray.panel:FindById("closePanel")
    local rightClose=view.brew.journal.journalBook.panel:FindById("brewJournalClose")
    check(leftClose.props.bottom~=nil and leftClose.props.right~=nil and leftClose.props.arrowDirection=="left","tray closes with a left stitched arrow at its inner bottom edge")
    check(rightClose.props.bottom~=nil and rightClose.props.left~=nil and rightClose.props.arrowDirection=="right","book closes with the same arrow mirrored at its inner bottom edge")
    local arrow=require "ui.landscape.EmbroideredArrow"
    check(arrow.image=="image/ui-controls/embroidered-arrow-left-v01.png","both arrows use the approved embroidered PNG")
    check(leftClose.props.width>=108 and leftClose.props.height>=72 and rightClose.props.width>=108,"larger patch retains a generous phone touch target")
    check(leftClose.props.right<0 and rightClose.props.left<0,"pull tabs extend beyond each inner cloth edge")
    -- Exercise the engine library's actual hit traversal outside an absolute parent.
    -- Only rectangles are supplied by the headless adapter; this is not Yoga evidence.
    MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT=0,1,2 -- Existing headless enum adapters.
    local NativeUI=require "urhox-libs/UI/Core/UI"
    local testUI=require "urhox-libs/UI"
    local hitRoot=testUI.Panel {}
    local hitPanel=testUI.Panel {position="absolute",overflow="visible"}
    hitRoot:AddChild(hitPanel)
    local pull=arrow.Attach(hitPanel,{arrowDirection="left"})
    host.Bind(hitRoot)
    hitPanel.GetAbsoluteLayout=function() return {x=100,y=50,w=200,h=300} end
    pull.GetAbsoluteLayout=function() return {x=212,y=278,w=108,h=72} end
    hitPanel.GetAbsoluteLayoutForHitTest=hitPanel.GetAbsoluteLayout
    pull.GetAbsoluteLayoutForHitTest=pull.GetAbsoluteLayout
    NativeUI.SetRoot(hitRoot)
    check(NativeUI.FindWidgetAt(310,310)==pull,"the protruding arrow routes taps beyond its absolute parent")
    check(NativeUI.FindWidgetAt(310,100)~=hitPanel,"nearby space is not swallowed by an enlarged parent strip")
    NativeUI.SetRoot(view.root)
    hitRoot:Destroy()
    local resultView=require "ui.landscape.ResultView"
    local paper=resultView.Layout({w=1200,h=540},{left=48,right=0,top=0,bottom=0},{left=.88,right=.99,top=.02,bottom=.14})
    check(paper.top<30 and paper.height>=480,"centered story paper stays tall when it does not intersect the host capsule")
    check(paper.height-paper.headerHeight-paper.paddingTop-paper.paddingBottom-paper.actionsHeight>=260,"compact story leaves a useful scrolling body after fixed header and actions")
    view.root:Destroy()
    -- Production uses schema 4; exercise the same view against its real coordinator.
    local releaseData=require "data.content"
    local real=F.New(releaseData,{targetSchema=4})
    local releaseView=View.New(real.session,releaseData)
    releaseView.Navigate("brew");releaseView.Update()
    check(releaseView.root:FindById("brewWishText"):GetText()=="尚未接下委托" and releaseView.root:FindById("previewOrder").props.disabled,
        "unaccepted order has a short banner and disabled brewing")
    local letter=must(releaseView.model.Receive("letter_pa_01"));must(releaseView.model.Read(letter.letterInstanceId))
    local releaseTokens={}
    for _,span in ipairs(must(real.modules.letters.GetView(letter.letterInstanceId)).spans) do
        releaseTokens[span.wordId]=must(releaseView.model.Cut(span.spanId)).tokenId
    end
    must(releaseView.model.Accept());releaseView.Navigate("brew");releaseView.Update()
    must(releaseView.model.Drop("word",releaseTokens[sample.mainWordId]))
    for _,word in ipairs(sample.auxWordIds) do must(releaseView.model.Drop("word",releaseTokens[word])) end
    for _,line in ipairs(sample.ingredients) do for _=1,line.quantity do must(releaseView.model.Drop("ingredient",line.ingredientId)) end end
    releaseView.brew.journal.Close();releaseView.Update()
    check(not releaseView.brew.journalOpen,"feedback test starts with a closed book")
    releaseView.Update();must(releaseView.brew.Start());releaseView.brew.Skip();releaseView.Update()
    check(releaseView.panel=="result" and releaseView.root:FindById("resultStars"),"schema 4 reveals saved stars after smoke")
    check(releaseView.brew.revealTail>0 and releaseView.root:FindById("brewSmokeBlocker").props.visible,"story opens under a full-screen fading veil")
    host.Step(releaseView,.35);host.Step(releaseView,.35)
    check(releaseView.brew.revealTail==0 and not releaseView.root:FindById("brewSmokeBlocker").props.visible,"veil releases controls after the story appears")
    check(releaseView.brew.journalOpen and releaseView.feedback.motion.record and releaseView.feedback.motion.record.started,"saved story automatically opens the existing book and starts its trail after smoke")
    releaseView.Close();releaseView.Update();releaseView.brew.Start();releaseView.Update()
    check(releaseView.brew.revealTail==0 and releaseView.panel=="result","reopening saved pending does not replay the smoke")
    local deliver=assert(releaseView.root:FindById("confirmOrder"))
    local oldCurrency=real.state.GetSnapshot().live.economy.currency
    deliver.props.onClick();releaseView.Update()
    check(not real.state.GetSnapshot().currentOrder and real.state.GetSnapshot().live.gameFlow.deliveredOrders==1,"schema 4 explicit shipping settles once")
    local rewardSnapshot,rewardWrites=real.state.GetSnapshot(),real.writes
    check(releaseView.feedback.motion.reward and releaseView.feedback.motion.reward.amount==rewardSnapshot.live.economy.currency-oldCurrency,"reward trail uses the actual committed currency delta")
    check(releaseView.root:FindById("playLedger"):GetText():find("金币 "..oldCurrency,1,true),"visible ledger keeps old amount until trail arrives")
    host.Step(releaseView,.5);host.Step(releaseView,.5);host.Step(releaseView,.5)
    check(releaseView.root:FindById("playLedger"):GetText():find("金币 "..rewardSnapshot.live.economy.currency,1,true),"ledger reaches the committed amount after the arrival count")
    check(U.Equal(rewardSnapshot,real.state.GetSnapshot()) and real.writes==rewardWrites,"feedback animation never writes or awards currency again")
    local function countBooks(node)
        ---@type number
        local n=node.props.id=="bookArtFrame" and 1 or 0
        for _,child in ipairs(node.children or {}) do n=n+countBooks(child) end
        return n
    end
    check(not releaseView.panel and releaseView.brew.journalOpen and countBooks(releaseView.root)==1,"shipping reuses the open pot-side book without a second overlay book")
    releaseView.root:FindById("brewJournalClose").props.onClick()
    host.Step(releaseView,.3)
    check(not releaseView.brew.journalOpen and countBooks(releaseView.root)==0,"one close hides the only record book")
    releaseView.storyId="letter_pa_01";releaseView.Open("journal");releaseView.Open("journal");releaseView.Update()
    check(not releaseView.panel and releaseView.brew.journalOpen and countBooks(releaseView.root)==1,"repeated open on the workbench still reuses one book")
    local journal=must(real.session.queries.GetJournalPage("letter_pa_01"))
    local collected=false --[[@as table|false]]
    for _,entry in ipairs(require("ui.landscape.JournalBook").Entries(journal)) do if entry.collected then collected=entry;break end end
    check(collected and collected.transactionId,"collected production branch retains its saved transaction")
    releaseView.Close();releaseView.Update()
    releaseView.brew.journal.storyId="letter_pa_01"
    require("ui.landscape.JournalBook").Select(releaseView.brew.journal,"letter_pa_01")
    local historyBefore=real.state.GetSnapshot()
    require("ui.landscape.JournalBook").OpenEntry(releaseView.brew.journal,collected.fragmentId);releaseView.Update()
    check(releaseView.panel=="attempt" and releaseView.model.selectedAttempt==collected.transactionId and releaseView.root:FindById("historyBody"),"embedded pot-side book opens the same saved large paper")
    check(U.Equal(historyBefore,real.state.GetSnapshot()),"opening pot-side history does not change production progress")
    local shipped=real.state.GetSnapshot();deliver.props.onClick();releaseView.Update()
    check(U.Equal(shipped,real.state.GetSnapshot()),"stale double delivery cannot settle schema 4 twice")
    releaseView.root:Destroy()
    print("[BrewWorkbench] PASS assertions="..count.."; real business/File-widget-clock adapters; native and phone separate")
    return true
end
return T
