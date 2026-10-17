-- Headless layout/state regression; actual Yoga bounds are checked by the native probe.
local T={}
function T.Run()
    local UI=require "urhox-libs/UI"
    UI.MeasureTextWidth=UI.MeasureTextWidth or function(s,size) return utf8.len(s)*size end
    local count=0
    local function check(ok,why) count=count+1;assert(ok,why) end
    local Pages=require "ui.landscape.WordTrayPages"
    local Slip=require "ui.landscape.WordSlip"
    local cards={};for i=1,37 do cards[i]={text=({"困","梦见","合上眼","安安稳稳地睡一觉"})[(i-1)%4+1],tokenId=tostring(i)} end
    for _,rect in ipairs({{160,180},{200,92},{360,410}}) do
        local packed=Pages.Build(cards,rect[1],rect[2],function(c) return Slip.Metrics(c.text,{maxWidth=rect[1],fontSize=16}) end)
        local seen={};check(packed.pageCount==#packed.pages and packed.pageCount>1,"paged result")
        for _,page in ipairs(packed.pages) do for i,a in ipairs(page) do
            check(not seen[a.card.tokenId],"card appears exactly once");seen[a.card.tokenId]=true
            check(a.x>=0 and a.y>=0 and a.x+a.w<=rect[1] and a.y+a.h<=rect[2],"complete card fits page")
            for j=i+1,#page do local b=page[j]
                check(a.x+a.w<=b.x or b.x+b.w<=a.x or a.y+a.h<=b.y or b.y+b.h<=a.y,"no overlap")
            end
        end end
        for _,c in ipairs(cards) do check(seen[c.tokenId],"no missing source") end
    end
    check(Pages.Build({},100,100,function() end).pageCount==1,"empty page remains stable")
    local Drawer=require "ui.landscape.WordTrayDrawer"
    local ctx={viewport={w=1280,h=600},safeInsets={left=50,right=10,top=0,bottom=0},model={message=""},Close=function() end}
    local data={cards=cards,categories={{id="one",title="情绪类",availableCount=#cards}}}
    for _,c in ipairs(cards) do c.categoryId="one";c.available=true;c.sourceTitle="来源" end
    local function mount()
        local root=UI.Panel{};Drawer.Render(ctx,root,{view=data});return root
    end
    local state=Drawer.State(ctx);state.open=1;state.target=1
    local sounds=0;ctx.PlayObjectSound=function() sounds=sounds+1 end
    local root=mount()
    check(root:FindById("activePanel").props.left==0,"normal tray flush with screen left despite safe inset")
    check(root:FindById("wordTrayTitle").props.width<=80,"heading and its paper are small")
    local tab=root:FindById("wordTrayTab_one").props
    local tabPaper=root:FindById("wordTrayCategoryPaper_one").props
    check(not root:FindById("wordTrayStrips").props.scrollY and not root:FindById("wordTrayTabs").props.scrollY
        and math.abs(tab.top+tab.height/2-tabPaper.top-tabPaper.height/2)<.01,"no tray pan scrolling; category paper stays centered on touch target")
    check(root:FindById("wordTrayPrev").props.disabled,"first page previous disabled")
    local nextClick=root:FindById("wordTrayNext").props.onClick
    nextClick();nextClick();root=mount()
    check(sounds==1,"one effective page change plays once, stale replay silent")
    check(state.pages.one==2 and not root:FindById("wordTrayPrev").props.disabled,"arrow changes only category page state")
    ctx.viewport.h=1080;root=mount();check(state.pages.one<=state.pageCount,"resize clamps page")
    local Result=require "ui.landscape.ResultView"
    local safe={left=40,right=0,top=0,bottom=12};local vp={w=1206,h=540}
    local plain=Result.Layout(vp,safe)
    local menu={left=.86,top=.02,right=.99,bottom=.16}
    local mobile=Result.Layout(vp,safe,menu)
    check(mobile.top==plain.top and mobile.height==plain.height,"capsule cannot push the whole letter down")
    check(mobile.width>1000,"wide phone uses available reading width")
    local Notes=require "ui.landscape.PotionNotesView"
    local Workbench=require "ui.landscape.BrewLayout"
    for _,size in ipairs({vp,{w=1920,h=1080},{w=960,h=540}}) do
        local work=Workbench.Compute(size.w,size.h,safe)
        local r=Notes.Layout(size,safe,work)
        check(r.x==work.summary.x and r.w==work.summary.w,"notes occupy only center column")
        check(r.y==work.summary.y and r.y>=work.pot.y+work.pot.h,"drawer starts below cauldron")
        check(r.y+r.h<=size.h-safe.bottom and r.y+r.h>=work.controls.y,"drawer covers lower workbench")
    end
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local R=require "debug.fixtures.ReleaseFixtures"
    local U=require "core.StateUtil"
    local View=require "ui.PlayView"
    local x=R.New(1000);local request=R.Accept(x,1)
    local view=View.New(x.session,x.content);R.Must(view.model.Drop("word",request.mainTokenId));view.Navigate("brew");view.Update()
    local before,writes=x.state.GetSnapshot(),x.writes
    local function node(id) return assert(view.root:FindById(id),id) end
    local function tap(id) node(id).props.onClick();view.Update() end
    check(not view.root:FindById("brewNotesBackdrop"),"notes default closed")
    local slots=U.Copy(node("brewRecipePaper").props)
    tap("brewRecipeDetails")
    check(node("brewNotesHost").props.zIndex>node("brewWordsHost").props.zIndex,"sheet has its own overlay layer")
    check(node("brewDetailBody").props.scrollY and node("brewRequirement").props.fontSize>=18,"large readable notes")
    check(not view.root:FindById("brewMainEffectMeaning") and not view.root:FindById("brewCompanionEffects"),"no outcome prediction block")
    local backdrop=node("brewNotesBackdrop").props
    check(backdrop.onClick~=nil and backdrop.left==0 and backdrop.top==0,"blank outside closes and intercepts underlying controls")
    check(backdrop.backgroundColor[4]==0,"outside remains bright; no dimming scrim")
    local detail=node("brewDetail")
    check(detail.props.borderWidth>=2 and detail.props.width==view.brew.layout.center.w,"approved frame fits only center column")
    local requirement=node("brewRequirement"):GetText()
    local effects=node("brewEffectsSummary"):GetText()
    tap("brewToggleNumbers")
    check(view.brew.notesNumbers and view.root:FindById("brewEffectNumbers"),"existing detailed weights remain accessible")
    check(node("brewRequirement"):GetText()==requirement and node("brewEffectsSummary"):GetText()==effects,"numbers toggle preserves original requirement and current effect")
    tap("brewToggleNumbers")
    detail=node("brewDetail")
    detail.props.onClick();view.Update()
    check(view.brew.selected=="recipe" and node("brewRequirement"):GetText()==requirement,"inside blank space stays open and preserves text")
    tap("brewNotesBackdrop")
    check(U.Equal(slots,node("brewRecipePaper").props),"notes do not reflow recipe")
    check(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes,"open/close notes never changes gameplay or storage")
    view.root:Destroy()
    for _,cash in ipairs({1000,12}) do
        x=R.New(cash);view=View.New(x.session,x.content);view.Open("shop");view.Update()
        tap("shop_select_ing_night_dew")
        local footer=U.Copy(node("shopDetailFooter").props)
        check(node("shopMessageArea").props.position=="absolute","purchase feedback stays outside flow")
        x.fault="write";local saved=x.state.GetSnapshot();tap("buy_ing_night_dew");x.fault=false
        check(U.Equal(saved,x.state.GetSnapshot()) and U.Equal(footer,node("shopDetailFooter").props),"failed save keeps layout and state")
        local n=0
        while not node("buy_ing_night_dew").props.disabled do
            tap("buy_ing_night_dew");n=n+1;check(n<20,"finite stock")
            check(U.Equal(footer,node("shopDetailFooter").props),"purchase/sold-out/insufficient balance use same footer")
            check(node("shopItemReason").props.height==52,"reason always reserves same height")
        end
        check(n>0 and node("shopMessageArea").props.position=="absolute","successful purchases exercised")
        view.root:Destroy()
    end
    print("[FirstBatchTest] PASS assertions="..count.."; headless layout/state only")
    return count
end
return T
