-- Frontend behavior with real game state and explicit layout/time adapters.
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local View=require "ui.PlayView"
local U=require "core.StateUtil"
local T={}
function T.Run()
    local n=0
    local function check(value,message) n=n+1;assert(value,message) end
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local x=F.New(Data,{targetSchema=3})
    local originalStatus=x.state.GetStatus
    local diagnostic="旧档已升级；无正文的旧试做不补历史，旧选料需重选，今日捕捞额度保守用尽，明日恢复。"
    x.state.GetStatus=function() local s=originalStatus();s.migrationNotice=diagnostic;return s end
    local v=View.New(x.session,Data);host.Bind(v.root);v.Update()
    local function widget(id) return assert(v.root:FindById(id),id) end
    local before=x.state.GetSnapshot();local writes=x.writes
    check(widget("playMessage"):GetText():find("旧档",1,true)==nil,"migration diagnostics must not reach player text")
    check(v.model.message==diagnostic,"view preserves original diagnostic")
    check(widget("playMessageArea"):GetProps().position=="absolute","feedback never reserves a permanent bottom strip")
    check(widget("homeHud"):GetProps().backgroundColor==nil,"top status row must not be a full opaque bar")
    check(v.home.HintsVisible(),"first entry exposes interactive object hints")
    local hints=widget("homeHints")
    check(hints:GetProps().pointerEvents=="none","object labels must not intercept taps")
    check(hints:GetNumChildren()==#v.home.manifest.objects,"only actual interactive objects receive hints")
    for _,obj in ipairs(v.home.manifest.objects) do
        local tag=widget("hint_"..obj.id)
        check(tag:GetText()==obj.label,"hint describes the object action")
        check(tag:GetProps().pointerEvents=="none","hint remains input transparent")
    end
    check(widget("hint_home.stove").props.width>=104 and widget("hint_home.stove").props.fontSize==12,"quiet labels still reserve five readable glyphs plus padding")
    for _=1,61 do host.Step(v,.1) end
    check(not v.home.HintsVisible(),"intro hints fade after five seconds")
    check(not widget("playMessageArea"):GetProps().visible,"ordinary migration message expires")
    widget("toggleHomeHints"):GetProps().onClick();v.Update()
    check(v.home.HintsVisible(),"player can reopen hints")
    v.home.SetBlocked(true);v.Update()
    check(not hints:GetProps().visible,"navigation animation hides labels")
    v.home.SetBlocked(false);v.Update()
    widget("toggleHomeHints"):GetProps().onClick();v.Update()
    check(not v.home.HintsVisible(),"player can hide reopened hints")
    check(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes,"hint UI never writes player state")
    v.Navigate("seaside");v.Update();x.fault="write";v.StartSalvage();v.Update();x.fault=false
    check(widget("playMessageArea"):GetProps().visible,"saving failure stays visible")
    for _=1,70 do host.Step(v,.1) end
    check(widget("playMessageArea"):GetProps().visible,"critical error does not expire like a toast")
    check(U.Equal(before,x.state.GetSnapshot()),"failed salvage leaves progress untouched")
    v.model.message="";v.model.dirty=true;v.Update()
    check(not widget("playMessageArea"):GetProps().visible,"empty feedback leaves clear scene")
    local savedSdk=rawget(_G,"sdk")
    rawset(_G,"sdk",{GetNativeExitMenuRect=function() return {left=.86,top=0,right=1,bottom=.13} end})
    v.Update()
    check(widget("homeHud").props.paddingRight>100,"live host capsule adds local HUD clearance")
    v.Open("journal");v.Update()
    v.panelHeader.GetAbsoluteLayout=function() return {x=794,y=0,w=486,h=50} end
    v.Update()
    check(v.panelHeader.props.paddingRight>100,"drawer close button also receives host capsule clearance")
    v.panelHeader.GetAbsoluteLayout=function() return {x=1070,y=v.panelHeader.props.marginTop or 0,w=206,h=50} end
    v.Update();local raised=v.panelHeader.props.marginTop
    check(raised>0,"narrow drawer header moves below capsule")
    v.Update();check(v.panelHeader.props.marginTop==raised,"header avoidance stays stable after layout reflects its offset")
    v.Close();v.Update()
    v.Navigate("brew");v.Update()
    check(widget("functionalScene").props.paddingTop>=64,"functional content starts below floating HUD")
    v.Navigate("seaside");v.Update()
    rawset(_G,"sdk",savedSdk);v.Update()
    check(widget("homeHud").props.paddingRight==12,"absent host capsule releases extra clearance")
    host.width=360;host.height=800;host.Bind(v.root);v.Update()
    check(widget("rotateGuard").props.visible,"portrait viewport explains landscape play")
    v.Open("day");check(not v.panel,"portrait guard rejects gameplay modal callback")
    check(v.StartSalvage()==false,"portrait callback cannot consume a letter")
    host.width=1280;host.height=720;host.Bind(v.root);v.Update()
    check(not widget("rotateGuard").props.visible,"landscape restores normal input")
    check(U.Equal(before,x.state.GetSnapshot()),"capsule and orientation changes never write progress")
    check(v.StartSalvage().ok,"portrait interruption fixture starts real salvage")
    v.Update();local captured=x.state.GetSnapshot();local receipt=v.salvage.letterInstanceId
    host.width=360;host.height=800;host.Bind(v.root);v.Update()
    host.width=1280;host.height=720;host.Bind(v.root);v.Update()
    check(not v.salvage.active and v.salvage.letterInstanceId==receipt,"portrait interruption retains received letter")
    check(widget("readCapturedLetter").props.visible and not widget("readCapturedLetter").props.disabled,"rotate back restores read retry")
    check(not widget("seasideShop").props.disabled,"rotate back restores non-salvage controls")
    check(U.Equal(captured,x.state.GetSnapshot()),"rotation never repeats receive or prematurely reads")
    print("[HomeHudTest] "..n.." checks passed; adapters are not native screen evidence")
    return n
end
return T
