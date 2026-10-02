-- 仅供 run_b1.py：UI 状态替身，不提供任何渲染/尺寸验收证据。
local UI = { Scale = { DEFAULT = 1 } }
local function widget(props)
    local w = { props = props, children = props.children or {} }
    function w:AddChild(child) self.children[#self.children + 1] = child end
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
    return w
end
UI.Label, UI.Panel, UI.Button, UI.ScrollView, UI.SafeAreaView = widget, widget, widget, widget, widget
function UI.Init(_) end
function UI.Shutdown() end
function UI.SetRoot(root) UI.root = root end
return UI
