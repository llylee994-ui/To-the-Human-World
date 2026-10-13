-- Run real Button initialization inside the isolated business/widget host.
-- Only Yoga/layout is adapted; gradient/color initialization is production code.
local T={}
function T.Run()
    MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT=0,1,2 -- Explicit host enums; no real input.
    local UI=require "urhox-libs/UI"
    local Button=require "urhox-libs/UI/Widgets/Button"
    local original=UI.Button
    rawset(UI,"Button",function(props)
        local button=original(props)
        setmetatable(button,{__index=Button})
        button.renderProps_={}
        Button.Init(button,props)
        return button
    end)
    local called,result=pcall(function()
        require("ui.landscape.tests.ZoomTestHost").New()
        local U=require "core.StateUtil"
        local content=U.Copy(require "data.content")
        content.furniture=require "data.furniture"
        local x=require("debug.fixtures.B5Fixtures").New(content,{targetSchema=3})
        local view=require("ui.PlayView").New(x.session,content)
        view.Open("shop");view.Update()
        local count=0
        local function check(value,why) count=count+1;assert(value,why) end
        local function find(id) return view.root:FindById(id) end
        for _,id in ipairs({"shopTab_ingredients","shopTab_furniture","shopTab_tickets","shop_select_ing_sea_salt","shopItemName","buy_ing_sea_salt","closePanel"}) do
            check(find(id),"background-only shop: missing "..id)
        end
        for _,category in ipairs({"furniture","tickets","ingredients"}) do
            find("shopTab_"..category).props.onClick();view.Update()
            check(find("shopItemName"),"details missing after "..category)
        end
        print("[ShopConstructorTest] PASS assertions="..count.."; real Button.Init/Style with isolated Yoga/File host, not native rendering")
        return count
    end)
    rawset(UI,"Button",original)
    assert(called,"Shop construction aborted: "..tostring(result))
    return result
end
return T
