-- A real UI button with a small painted petal-shaped background and normal input.
local UI=require "urhox-libs/UI"
local H=require "ui.landscape.HarborStyle"
local P={}
function P.New(props)
    local p={height=44,minHeight=44,width=112,minWidth=0,fontFamily=H.fontFamily,fontWeight="normal",fontSize=12,
        padding={7,12},flexShrink=0,textColor={111,65,65,255},disabledTextColor={150,133,126,255},
        backgroundColor={0,0,0,0},hoverBackgroundColor={0,0,0,0},pressedBackgroundColor={0,0,0,0},
        variantBackgroundGradient={},variantHoverBackgroundGradient={},variantPressedBackgroundGradient={},
        borderWidth=0,hoverBorderWidth=0,pressedBorderWidth=0,borderRadius=0,boxShadow=false,glowShadow={}}
    for k,v in pairs(props or {}) do p[k]=v end
    local button=UI.Button(p)
    function button:RenderFullBackground(vg)
        local r=self:GetAbsoluteLayout();local x,y,w,h=r.x+2,r.y+4,r.w-4,r.h-8
        local pressed=self.state and self.state.pressed
        local hovered=self.state and self.state.hovered
        local alpha=self.props.disabled and 110 or 235
        nvgBeginPath(vg);nvgMoveTo(vg,x+1,y+h*.7)
        nvgBezierTo(vg,x+w*.05,y-h*.12,x+w*.61,y-h*.08,x+w-1,y+h*.2)
        nvgBezierTo(vg,x+w*.97,y+h*1.12,x+w*.32,y+h*1.1,x+1,y+h*.7)
        nvgClosePath(vg)
        nvgFillPaint(vg,nvgLinearGradient(vg,x,y,x+w,y+h,nvgRGBA(252,238,226,alpha),
            nvgRGBA(pressed and 210 or 231,hovered and 168 or 189,183,alpha)))
        nvgFill(vg);nvgStrokeWidth(vg,.8);nvgStrokeColor(vg,nvgRGBA(164,119,102,150));nvgStroke(vg)
        nvgBeginPath(vg);nvgMoveTo(vg,x+9,y+h*.76)
        nvgBezierTo(vg,x+w*.3,y+h*.93,x+w*.62,y+h*.92,x+w-9,y+h*.35)
        nvgStrokeWidth(vg,.6);nvgStrokeColor(vg,nvgRGBA(180,136,110,90));nvgStroke(vg)
    end
    return button
end
return P
