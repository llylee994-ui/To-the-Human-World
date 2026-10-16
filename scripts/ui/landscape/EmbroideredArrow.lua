-- Approved embroidered cloth patch. Both controls share one PNG and hit target.
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local Art=require "ui.landscape.BrewArt"
local A={image="image/ui-controls/embroidered-arrow-left-v01.png"}
local frame={path=A.image,width=1536,height=1024,x=0,y=0,w=1536,h=1024}

function A.New(props)
    local p={text="",width=108,height=72,minWidth=108,minHeight=72,padding=0,flexShrink=0,zIndex=20,
        backgroundColor={0,0,0,0},hoverBackgroundColor={0,0,0,0},pressedBackgroundColor={0,0,0,0},
        variantBackgroundGradient={},variantHoverBackgroundGradient={},variantPressedBackgroundGradient={},
        borderWidth=0,hoverBorderWidth=0,pressedBorderWidth=0,borderRadius=0,boxShadow=false,glowShadow={}}
    for key,v in pairs(props or {}) do p[key]=v end
    local b=UI.Button(p)
    function b:RenderFullBackground(vg)
        local r=self:GetAbsoluteLayout()
        local scale=math.min(r.w/frame.w,r.h/frame.h)
        local w,h=frame.w*scale,frame.h*scale
        local pressed=self.state and self.state.pressed
        nvgSave(vg)
        nvgTranslate(vg,r.x+r.w/2,r.y+r.h/2+(pressed and 2 or 0))
        if self.props.arrowDirection=="right" then nvgScale(vg,-1,1) end
        Art.Draw(vg,frame,{x=-w/2,y=-h/2,w=w,h=h},1,pressed and {225,225,225} or nil)
        nvgRestore(vg)
    end
    return b
end
function A.Attach(panel,props)
    local button=A.New(props)
    panel:AddChild(button)
    -- Absolute parents reject their whole subtree outside their layout bounds.
    -- Admit only this visible pull tab as well, so its overhang stays tappable.
    function panel:HitTest(x,y)
        return Widget.HitTest(self,x,y) or button:HitTest(x,y)
    end
    return button
end
return A
