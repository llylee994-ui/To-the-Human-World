-- 仅供 run_b1.py：UI 状态替身，不提供任何渲染/尺寸验收证据。
local UI = { Scale = { DEFAULT = 1 } }
local function widget(props)
    ---@type table
    local w = { props = props, children = props.children or {} }
    for _,child in ipairs(w.children) do child.parent=w end
    function w:AddChild(child) self.children[#self.children + 1] = child; child.parent=self end
    function w:GetNumChildren() return #self.children end
    function w:GetChildAt(index) return self.children[index] end
    function w:Destroy()
        ---@type table|nil
        local parent=self.parent
        if parent then
            for i,child in ipairs(parent.children) do if child==self then table.remove(parent.children,i); break end end
        end
        self.parent=nil; self.children={}
    end
    function w:ScrollToTop() self.testScrollY=0 end -- 无布局/渲染证据
    function w:FindById(id)
        if self.props.id == id then return self end
        for _, child in ipairs(self.children) do
            local found = child:FindById(id)
            if found then return found end
        end
        return nil
    end
    function w:SetText(text) self.props.text = text end
    function w:GetText() return self.props.text or "" end
    function w:SetVisible(visible) self.props.visible = visible end
    function w:SetDisabled(disabled) self.props.disabled = disabled end
    function w:GetProps() return self.props end
    -- Widget.SetStyle can update real props in headless integration tests.
    -- Only its Yoga side effect is unavailable; this is never layout evidence.
    function w:ApplyStyleToYoga(_) end
    return w
end
UI.Label, UI.Panel, UI.Button, UI.ScrollView, UI.SafeAreaView = widget, widget, widget, widget, widget
-- Reuse the actual value/callback methods; only layout/render/event dispatch is absent.
function UI.Slider(props)
    local control=widget(props) --[[@as table]]
    local Slider=require "urhox-libs/UI/Widgets/Slider"
    control.SetValue=Slider.SetValue;control.GetValue=Slider.GetValue
    control.DispatchEvent=function() end
    return control
end
function UI.Toggle(props)
    local control=widget(props) --[[@as table]]
    local Toggle=require "urhox-libs/UI/Widgets/Toggle"
    control.SetValue=Toggle.SetValue;control.GetValue=Toggle.GetValue;control.SetLabel=Toggle.SetLabel
    control.DispatchEvent=function() end
    return control
end
function UI.Init(_) end
function UI.Shutdown() end
function UI.SetRoot(root) UI.root = root end
function UI.GetRoot() return UI.root end
return UI
