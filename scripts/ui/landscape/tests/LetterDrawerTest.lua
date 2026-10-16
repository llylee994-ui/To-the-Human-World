-- 来信抽屉是独立界面：打开时整块从屏幕上沿滑下来，× / ← / 点外部先收回再关面板。
-- 开合和浏览只动视图状态，读信仍走业务动作，不写快照。
local U=require "core.StateUtil"
local T={}

function T.Run()
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    -- The headless Widget adapter does not load native font measurement.
    local testUI=require "urhox-libs/UI"
    testUI.MeasureTextWidth=testUI.MeasureTextWidth or function(value,size) return utf8.len(value)*size end
    local Data=require "data.content"
    local F=require "debug.fixtures.B5Fixtures"
    local View=require "ui.PlayView"
    local Drawer=require "ui.landscape.LetterDrawer"
    local Art=require "ui.landscape.LetterDrawerArt"
    local x=F.New(Data,{targetSchema=3})
    local first=F.Must(x.state.ReceiveLetter({letterId="letter_pa_01"}))
    local view=View.New(x.session,Data)
    local count=0
    local function check(ok,why) count=count+1;assert(ok,why) end
    local function find(id) return view.root:FindById(id) end
    local function text(id) local node=assert(find(id),"missing "..id);return node:GetText() end
    local function click(id)
        local node=assert(find(id),"missing "..id)
        check(not node.props.disabled,"disabled "..id)
        node.props.onClick();view.Update()
    end
    local function settle(v,frames)
        local target=v or view
        for _=1,frames or 30 do host.Step(target,1/60) end
    end
    local safe=view.safeInsets or {left=0,top=0,right=0,bottom=0}
    local rows=F.Must(x.session.queries.GetLetters())
    check(#rows>=1,"fixture received at least one letter")
    check(not find("letterDrawerBody"),"drawer stays hidden until it is opened")
    check(Drawer.Progress(view)==0 and Drawer.Settled(view),"a closed drawer is at rest")
    local before,writes=x.state.GetSnapshot(),x.writes
    view.Open("letters");view.Update()
    check(view.panel=="letters","opening letters mounts the drawer panel")
    local panel=assert(find("activePanel"),"drawer keeps the overlay panel id")
    check(find("letterDrawerBody") and find("letterDrawerCavity"),"drawer body and cavity are mounted")
    check(find("letterDrawerPlate") and find("letterDrawerRail"),"title plate and rail are mounted")
    check(find("letterDrawerFlowersTop") and find("letterDrawerFlowersBottom"),"designer flowers are separate decorations")
    check(not find("letterDrawerParcel"),"the removed parcel stays out of the designer layout")
    local function paintedAfter(parent,front,back)
        parent.needsZSort_=true
        local fi,bi=0,0
        for i,node in ipairs(require("urhox-libs/UI/Core/Widget").GetRenderChildren(parent)) do
            if node.props.id==front then fi=i end
            if node.props.id==back then bi=i end
        end
        return fi>bi and bi>0
    end
    check(paintedAfter(panel,"letterDrawerTitleArea","letterDrawerPlate"),"native z-order keeps the title above the copper plate")
    check(find("letterDrawerHandle") and not find("letterDrawerHandle").props.backgroundImage,"the body carries its pull without a second handle image")
    check(text("letterDrawerTitle")=="来信抽屉","the plate names the drawer")
    check(find("closePanelArt_image"),"the drawer closes with the copper cross art")
    check(find("letterDrawerBackArt_image"),"the drawer offers the copper back arrow art")
    check(panel.props.pointerEvents=="auto","the drawer blocks the room hotspots beneath it")
    check(panel.props.left>=safe.left+12,"the drawer respects the left safe inset")
    check(panel.props.width==panel.props.height,"the overhead square drawer is not stretched into a wide panel")
    check(panel.props.height<=720 and panel.props.height>0,"the drawer height leaves the room visible")
    check(Drawer.Progress(view)==0,"the drawer starts tucked above the top edge")
    check(not Drawer.Settled(view),"the drawer animates instead of popping in")
    check(panel.props.top+panel.props.height<=safe.top,"a tucked drawer stays above the safe top")
    settle()
    check(Drawer.Progress(view)==1 and Drawer.Settled(view),"the drawer slides fully down and settles")
    check(panel.props.top==safe.top,"the pulled out drawer meets the top safe edge")
    local card=assert(find("read_"..first.letterInstanceId),"each letter gets a drawer card")
    local row=false --[[@as table|false]]
    for _,entry in ipairs(rows) do if entry.letterInstanceId==first.letterInstanceId then row=entry end end
    check(row~=nil,"the received letter is listed in the drawer query")
    check(text("letterDrawerCardTitle_"..first.letterInstanceId)==row.title,"the card shows the real title")
    check(text("letterDrawerCardSender_"..first.letterInstanceId)==row.senderName,"the card shows the sender")
    check(text("letterDrawerCardState_"..first.letterInstanceId)=="未读","an unread letter reads 未读")
    check(find("letterDrawerCardArt_"..first.letterInstanceId.."_image").props.backgroundImage==Art.Images.unread,"unread cards carry the wax-sealed art")
    check(paintedAfter(card,"letterDrawerCardTitle_"..first.letterInstanceId,"letterDrawerCardArt_"..first.letterInstanceId),"native z-order keeps card text above its paper")
    check(Drawer.StatusText({read=true,remainingCutCount=2})=="可剪 2 处","read letters report remaining cuts")
    check(Drawer.StatusText({read=true,remainingCutCount=0})=="已读","fully cut letters read 已读")
    check(Drawer.StatusText({read=false})=="未读","unread letters ignore stale cut counts")
    check(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes,"opening and browsing never write a snapshot")
    click("read_"..first.letterInstanceId)
    check(view.panel=="reader","tapping a card reads that letter")
    check(Drawer.Settled(view) and Drawer.Progress(view)==0,"leaving for the reader resets the drawer")
    local afterRead,writesAfter=x.state.GetSnapshot(),x.writes
    view.Open("letters");view.Update();settle()
    check(find("letterDrawerCardArt_"..first.letterInstanceId.."_image").props.backgroundImage==Art.Images.read,"opening a read letter changes its paper art")
    click("closePanel")
    check(not Drawer.Settled(view) and view.panel=="letters","× starts the retract instead of closing at once")
    host.Step(view,1/60)
    check(Drawer.Progress(view)>0 and Drawer.Progress(view)<1,"the drawer is on its way back in, not closed yet")
    settle()
    check(Drawer.Progress(view)==0,"the retracted drawer reaches the closed pose")
    check(view.panel==false,"and only then leaves the panel")
    view.Open("letters");view.Update();settle()
    click("letterDrawerBack")
    settle()
    check(Drawer.Progress(view)==0 and view.panel==false,"the back arrow retracts the same way")
    view.Open("letters");view.Update();settle()
    click("modalBlocker")
    settle()
    check(Drawer.Progress(view)==0 and view.panel==false,"tapping outside retracts and closes the drawer")
    view.Open("letters");view.Update();settle()
    click("closePanel")
    host.Step(view,1/60)
    view.Open("letters");view.Update()
    check(find("letterDrawerBody"),"reopening during the retract mounts the drawer again")
    settle()
    check(Drawer.Progress(view)==1 and view.panel=="letters","a drawer reopened mid-retract stays open")
    view.Navigate("brew")
    check(Drawer.Settled(view) and Drawer.Progress(view)==0,"leaving the scene cancels the drawer")
    check(U.Equal(afterRead,x.state.GetSnapshot()) and x.writes==writesAfter,"closing, retracting and reopening never write a snapshot")
    local empty=F.New(Data,{targetSchema=3})
    local emptyView=View.New(empty.session,Data)
    emptyView.Open("letters");emptyView.Update();settle(emptyView)
    check(emptyView.root:FindById("lettersEmpty"),"an empty drawer explains how letters arrive")
    check(emptyView.root:FindById("read_letter_pa_01")==nil,"an empty drawer mounts no cards")
    local pick=F.New(Data,{targetSchema=3})
    local pickView=View.New(pick.session,Data)
    pickView.OpenPaper();pickView.Update()
    check(pickView.panel=="letters" and pickView.choosingLetter==true,"a paper without a letter opens the drawer in pick mode")
    check(pickView.root:FindById("letterDrawerHint")~=nil
        and pickView.root:FindById("letterDrawerHint"):GetText()=="请选择要放到桌面阅读的信件。","the drawer shows the pick hint")
    for _,size in ipairs({{1280,720},{1600,650},{240,480},{560,400}}) do
        local a=Art.Fit(size[1],size[2])
        check(a.cavity.x>=0 and a.cavity.x+a.cavity.w<=size[1],"cavity stays inside the drawer")
        check(a.cards.x>=a.cavity.x and a.cards.y>=a.hint.y+a.hint.h,"cards sit below the hint band")
        check(a.cards.x+a.cards.w+a.rail.w+6<=a.cavity.x+a.cavity.w,"the rail stays right of the card grid")
        check(a.cards.y+a.cards.h<=a.foot.y,"the card scroll ends above the drawer front")
        local square=math.min(size[1],size[2]);local top=(size[2]-square)/2
        check(a.cards.y+a.cards.h<=top+square*.660001,"scrolling letters never enter the bottom decoration band")
        check(math.abs(a.rail.y-a.cards.y)<.01 and math.abs(a.rail.h-a.cards.h)<.01,"copper rail follows the actual shortened viewport")
        check(a.card.w>0 and a.card.h>0 and a.card.rowStep>a.card.h,"cards keep readable rows with gaps")
        check(a.plate.x>=0 and a.plate.x+a.plate.w<=size[1],"the title plate stays inside the drawer")
        check(a.close.x+a.close.w<=size[1] and a.close.y>=0,"the close button stays inside the drawer")
        check(a.back.x>=0 and a.back.y>=a.foot.y,"the back arrow sits on the drawer front")
        check(a.handle.x>=0 and a.handle.x+a.handle.w<=size[1],"the drawer pull stays centred on the front")
    end
    print("[LetterDrawerTest] PASS assertions="..count.."; slide-down letter drawer, retract-then-close paths, view-state only; native evidence separate")
    return count
end
return T
