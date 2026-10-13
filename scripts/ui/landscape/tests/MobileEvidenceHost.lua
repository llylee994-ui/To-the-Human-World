-- Export actual view trees against an explicit simulated phone host.
local UI=require("urhox-libs/UI") --[[@as table]]
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local View=require "ui.PlayView"
local U=require "core.StateUtil"
local T={}
function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local content=U.Copy(Data);content.furniture=require "data.furniture"
    local x=F.New(content,{targetSchema=3})
    local view=View.New(x.session,content)
    GetPlatform=function() return "iOS" end
    local oldViewport,oldInsets=UI.GetViewportSize,UI.GetSafeAreaInsets
    for _,size in ipairs({{2048,917,1.8},{1280,720,1},{800,360,.8},{1024,768,1}}) do
        local w,h=size[1]/size[3],size[2]/size[3]
        local safe={left=52,top=0,right=12,bottom=14}
        local menu={left=.88,top=.055,right=.986,bottom=.14}
        sdk={GetNativeExitMenuRect=function() return menu end}
        UI.GetViewportSize=function() return w,h end
        UI.GetSafeAreaInsets=function() return safe end
        local function bind()
            host.Bind(view.root)
            local full={x=0,y=0,w=w,h=h}
            for _,id in ipairs({"playPanel","homeView","seasideView"}) do
                assert(view.root:FindById(id)).GetAbsoluteLayout=function() return full end
            end
            view.root.parent={GetAbsoluteLayout=function() return {x=safe.left,y=0,w=w-safe.left-safe.right,h=h-safe.bottom} end}
            if view.panelHeader then
                view.panelHeader.GetAbsoluteLayout=function(self)
                    return {x=0,y=self.props.marginTop or 0,w=w,h=64}
                end
            end
            view.Update()
        end
        for _,scene in ipairs({"home","seaside","shop","shop-page2","shop-furniture","shop-furniture-page2","shop-ticket","brew","journal"}) do
            local shop=scene:match("^shop")
            view.Navigate(shop and "seaside" or scene=="journal" and "home" or scene);view.Update();bind()
            if shop then
                view.shopCategory=scene:match("^shop%-furniture") and "furniture" or scene=="shop-ticket" and "tickets" or "ingredients"
                view.shopPage=scene:match("page2$") and 2 or 1
                view.shopSelectedId=false;view.Open("shop");view.Update();bind()
            elseif scene=="journal" then view.Open("journal");view.Update();bind() end
            local capture=rawget(_G,"MOBILE_EVIDENCE")
            if capture then capture(size[1],size[2],size[3],scene,safe,menu,view.root,view.home.Fit(),view.home.manifest,view.seaside.manifest) end
        end
        view.root.parent=nil
    end
    UI.GetViewportSize,UI.GetSafeAreaInsets=oldViewport,oldInsets
    print("[MobileEvidence] exported 36 actual view trees; simulated host, NOT phone/Yoga rendering")
    return true
end
return T
