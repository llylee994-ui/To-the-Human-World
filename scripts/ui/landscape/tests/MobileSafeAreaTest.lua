-- Real AppView with explicit host binding/layout adapters. NOT mobile rendering proof.
local UI=require("urhox-libs/UI") --[[@as table]]
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local View=require "ui.PlayView"
local U=require "core.StateUtil"
local T={}
function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local x=F.New(Data,{targetSchema=3})
    local view=View.New(x.session,Data);host.Bind(view.root)
    local before,writes=x.state.GetSnapshot(),x.writes
    local count=0
    local function check(ok,message) count=count+1;assert(ok,message) end
    local function widget(id) return assert(view.root:FindById(id),id) end
    local oldSdk,oldPlatform=rawget(_G,"sdk"),rawget(_G,"GetPlatform")
    local oldMeta=getmetatable(_G)
    local meta={};for key,value in pairs(oldMeta or {}) do meta[key]=value end
    -- tolua global properties can be provided through __index, not raw Lua slots.
    local menu={left=.88,top=.055,right=.986,bottom=.14} --[[@as table|nil]]
    local boundSdk={GetNativeExitMenuRect=function() return menu end}
    meta.__index=function(t,key)
        if key=="sdk" then return boundSdk end
        local inherited=oldMeta and oldMeta.__index
        if type(inherited)=="function" then return inherited(t,key) end
        if type(inherited)=="table" then return inherited[key] end
    end
    rawset(_G,"sdk",nil);setmetatable(_G,meta)
    rawset(_G,"GetPlatform",function() return "iOS" end)
    local oldViewport,oldInsets=UI.GetViewportSize,UI.GetSafeAreaInsets
    UI.GetViewportSize=function() return 1140,510 end
    UI.GetSafeAreaInsets=function() return {left=52,top=0,right=12,bottom=14} end
    view.Update()
    check(widget("homeHud").props.paddingRight>100,"bound SDK capsule must clear the HUD instead of rawget silently skipping it")
    check(widget("homeHud").props.left>=52,"HUD starts outside notch")
    -- The parent sits in SafeAreaView, while the scene must extend across its inset.
    view.root.parent={GetAbsoluteLayout=function() return {x=52,y=0,w=1076,h=496} end}
    view.Update()
    check(view.root.props.left==-52 and view.root.props.width==1140,"background fills full viewport instead of exposing a different scene behind the notch")
    check(view.root.props.height==510,"background reaches below bottom safe inset")
    view.Navigate("seaside");view.Update()
    local bar=widget("seasideControls")
    check(bar.props.paddingLeft>=66 and bar.props.paddingRight>=26,"seaside footer avoids both side insets")
    check(bar.props.paddingBottom>=14 and bar.props.height>=90,"seaside controls sit above home indicator")
    view.Open("shop");view.Update();host.Bind(view.root)
    widget("panelHeader").GetAbsoluteLayout=function() return {x=0,y=0,w=1140,h=64} end
    view.Update()
    check(widget("panelHeader").props.paddingLeft>=64,"shop title avoids notch")
    check(widget("panelHeader").props.paddingRight>100,"shop close and balance avoid capsule")
    check(widget("shopContent").props.paddingLeft>=64,"shop goods avoid notch")
    check(widget("shopContent").props.paddingBottom>=26,"shop purchase footer avoids home indicator")
    UI.GetSafeAreaInsets=function() return {left=14,top=12,right=52,bottom=0} end
    view.Update()
    check(widget("shopContent").props.paddingLeft>=26 and widget("shopContent").props.paddingRight>=64,"open shop follows landscape rotation without reopening")
    UI.GetSafeAreaInsets=function() return {left=52,top=0,right=12,bottom=14} end
    view.Update()
    view.Close();view.Update()
    -- SDK may report nil until the host bridge is ready: mobile keeps a reserve.
    menu=nil;view.Update()
    check(widget("homeHud").props.paddingRight>=144,"mobile nil capsule retains conservative right reserve")
    -- Compact narrow landscape falls below the capsule rather than overflowing.
    UI.GetViewportSize=function() return 640,360 end
    view.Update()
    check(widget("homeHud").props.top>=80,"narrow HUD moves below mobile capsule reserve")
    -- Desktop without host menu remains unobstructed and releases mobile offsets.
    rawset(_G,"GetPlatform",function() return "Windows" end)
    UI.GetViewportSize=function() return 1280,720 end
    UI.GetSafeAreaInsets=function() return {left=0,top=0,right=0,bottom=0} end
    view.Update()
    check(widget("homeHud").props.top==8 and widget("homeHud").props.paddingRight==12,"desktop clears mobile reserve")
    check(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes,"screen/capsule changes never mutate game progress")
    view.root.parent=nil
    UI.GetViewportSize,UI.GetSafeAreaInsets=oldViewport,oldInsets
    setmetatable(_G,oldMeta);rawset(_G,"sdk",oldSdk);rawset(_G,"GetPlatform",oldPlatform)
    print("[MobileSafeAreaTest] PASS assertions="..count.."; real view, isolated host adapters; mobile verification separate")
    return count
end
return T
