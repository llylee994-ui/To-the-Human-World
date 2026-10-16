-- Real reader construction and mutations with isolated File/widgets.
-- Checks the paper/content contract; native glyph rendering still needs a device.
local UI=require("urhox-libs/UI") --[[@as table]]
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local View=require "ui.PlayView"
local U=require "core.StateUtil"
local T={}
local function padding(props,edge)
    if props["padding"..edge]~=nil then return props["padding"..edge] end
    local value=props.padding
    if type(value)=="number" then return value end
    if type(value)=="table" then
        local indices={Top=1,Right=2,Bottom=3,Left=4}
        return value[edge:lower()] or value[indices[edge]] or value[(edge=="Left" or edge=="Right") and 2 or 1] or value[1] or 0
    end
    return 0
end
function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local x=F.New(Data,{targetSchema=3})
    local view=View.New(x.session,Data)
    local count=0
    local function check(ok,message) count=count+1;assert(ok,message) end
    local function must(r) assert(r.ok,cjson.encode(r.error));return r.value end
    local letter=must(view.model.Receive(must(x.session.queries.GetSalvageView()).availableLetterIds[1]))
    must(view.Read(letter.letterInstanceId));view.Update()
    local before,writes=x.state.GetSnapshot(),x.writes
    local oldViewport,oldInsets=UI.GetViewportSize,UI.GetSafeAreaInsets
    for _,size in ipairs({{1140,510},{800,360},{1280,720},{1024,768}}) do
        UI.GetViewportSize=function() return size[1],size[2] end
        UI.GetSafeAreaInsets=function() return {left=52,top=0,right=12,bottom=14} end
        host.Bind(view.root);view.Update()
        local panel=assert(view.root:FindById("activePanel"))
        local scroll=assert(view.root:FindById("playScroll"))
        -- The supplied paper still has fully transparent pixels at inset 18;
        -- its central opaque rectangle starts at inset 32 (source pixel audit).
        for _,edge in ipairs({"Top","Right","Bottom","Left"}) do
            check(padding(panel.props,edge)>=32,"reader "..edge.." content/scroll clip crosses the paper's opaque interior")
        end
        for i=1,4 do check(panel.props.backgroundSlice[i]>=32,"paper slice stretches transparent torn edges into the reading area") end
        check(scroll.parent==panel and scroll.props.flexBasis==0 and scroll.props.flexShrink==1,"long letter must scroll inside the inset paper frame")
        check(assert(view.root:FindById("letterPaper")).props.fontSize==18,"reader bounds must not be repaired by shrinking handwriting")
        local capture=rawget(_G,"READER_BOUNDS_EVIDENCE")
        if capture then capture(size[1],size[2],view.root) end
    end
    check(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes,"relayout never changes the letter or word inventory")
    local scroll=assert(view.root:FindById("playScroll"));scroll.testScrollY=450
    local paper=assert(view.root:FindById("letterPaper"))
    local accept=assert(view.root:FindById("acceptOrder"))
    check(accept.parent.props.id=="readerActions" and accept.parent.parent.props.id=="activePanel","accept action stays outside the scrolling letter")
    check(accept.props.alignSelf=="center" and accept.props.backgroundImage:find("story-result",1,true),"accept action uses centered painted primary skin")
    check(assert(view.root:FindById("readerOrderSummary")).parent.props.id=="readerBody","order summary is separate from the original letter paper")
    local parsed=must(x.modules.letters.GetView(letter.letterInstanceId))
    must(view.model.Cut(parsed.spans[1].spanId));view.Update()
    check(view.root:FindById("playScroll")==scroll and scroll.testScrollY==450,"cutting retains the inset viewport and scroll position")
    check(view.root:FindById("letterPaper")==paper,"cutting does not recreate the reading content")
    local after=x.state.GetSnapshot();view.Close();view.Update()
    must(view.Read(letter.letterInstanceId));view.Update()
    check(U.Equal(after,x.state.GetSnapshot()),"reopening the cut paper does not restore words or settle an order")
    check(view.readerCache.presentation.view.spans[1].cut,"reopened paper retains its cut state")
    UI.GetViewportSize,UI.GetSafeAreaInsets=oldViewport,oldInsets
    print("[ReaderBoundsTest] PASS assertions="..count.."; inset paper/scroll contract, unchanged font, cut/reopen; NOT native/mobile evidence")
    return count
end
return T
