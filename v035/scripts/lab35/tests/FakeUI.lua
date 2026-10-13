-- Widget/layout substitute only. Runs real AppView, Panels, PlayModel and business.
-- It proves dispatch/state behavior, never rendering or native input propagation.
local F={width=1920,height=1080,now=0,dt=1/60,registry={}}
local W={};W.__index=W
function W:AddChild(child) self.children[#self.children+1]=child;child.parent=self end
function W:GetNumChildren() return #self.children end
function W:GetChildAt(i) return self.children[i] end
function W:Destroy()
    self.destroyed=true
    for i=#self.children,1,-1 do self.children[i]:Destroy() end
    if self.parent then for i,c in ipairs(self.parent.children) do if c==self then table.remove(self.parent.children,i);break end end end
end
function W:SetStyle(props) for k,v in pairs(props) do self.props[k]=v end end
function W:SetVisible(v) self.props.visible=v end
function W:SetDisabled(v) self.props.disabled=v end
function W:SetText(v) self.props.text=v end
function W:SetBackgroundImage(v) self.props.backgroundImage=v end
function W:GetAbsoluteLayout() return {x=0,y=0,w=F.width,h=F.height} end
function W:GetScrollOffset() return 0,0 end
function W:SetScrollOffset() end
local function widget(props)
    props=props or {};local w=setmetatable({props=props,children={}},W)
    for _,c in ipairs(props.children or {}) do w:AddChild(c) end
    if props.id then F.registry[props.id]=w end
    return w
end
function F.Install()
    local root=widget({})
    local UI={Panel=widget,Label=widget,Button=widget,ScrollView=widget}
    UI.GetRoot=function() return root end
    UI.GetViewportSize=function() return F.width,F.height end
    package.preload["urhox-libs/UI"]=function() return UI end
    package.preload["urhox-libs/UI/Core/Widget"]=function() return W end
    package.preload["urhox-libs/UI/Core/ImageCache"]=function() return {Get=function() return 0 end} end
    MOUSEB_LEFT=0
    GetTime=function() return {GetElapsedTime=function() return F.now end,GetTimeStep=function() return F.dt end} end
    input={HasFocus=function() return true end,IsMinimized=function() return false end}
    return UI
end
function F.Click(id)
    local w=assert(F.registry[id],"missing test widget "..id)
    assert(not w.destroyed,"test widget destroyed "..id)
    assert(not w.props.disabled,"test widget disabled "..id)
    assert(w.props.onClick,"widget has no click handler "..id)
    return w.props.onClick(w,{button=0,x=100,y=100})
end
function F.Advance(ctx,dt)
    F.dt=dt or 1/60;F.now=F.now+F.dt;ctx.Update()
end
return F
