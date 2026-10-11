-- Explicit headless clock/focus/layout adapters; never device/rendering evidence.
local Host={}
function Host.New()
    local h={now=0,dt=0,focused=true,minimized=false,width=1280,height=720}
    GetTime=function() return {GetElapsedTime=function() return h.now end,GetTimeStep=function() return h.dt end} end
    input={HasFocus=function() return h.focused end,IsMinimized=function() return h.minimized end}
    function h.Step(view,dt)
        h.dt=dt;h.now=h.now+dt;view.Update();h.dt=0
    end
    function h.Bind(root)
        local Widget=require "urhox-libs/UI/Core/Widget"
        local scale=math.max(.625,math.min(math.sqrt(math.min(h.width,h.height)/720),1))
        local w,hh=h.width/scale,h.height/scale
        local full={x=0,y=0,w=w,h=hh};local stage={x=0,y=48,w=w,h=hh-84}
        local function bind(node,area)
            local id=node.props.id
            if id=="homeStage" then area=stage
            elseif id=="homeHud" then area={x=0,y=0,w=w,h=48}
            elseif id=="nextDay" then area={x=w-116,y=0,w=108,h=48}
            elseif id=="returnHome" then area={x=w-232,y=0,w=106,h=48}
            elseif id=="playMessageArea" then area={x=0,y=hh-36,w=w,h=36}
            elseif id=="activePanel" then area={x=w*.04,y=hh*.03,w=w*.92,h=hh*.94} end
            node.renderProps_={};node.testLayout=area
            node.GetAbsoluteLayout=function(self) return self.testLayout end
            node.GetAbsoluteLayoutForHitTest=node.GetAbsoluteLayout
            node.IsVisible=function(self) return self.props.visible~=false end
            node.GetRenderChildren=function(self) return self.children end
            node.HitTest=node.HitTest or Widget.HitTest
            for _,name in ipairs({"OnClick","OnPointerDown","OnPointerUp","OnPointerCancel","OnPointerMove","OnPointerEnter","OnPointerLeave"}) do node[name]=Widget[name] end
            for _,name in ipairs({"OnMouseDown","OnMouseUp","OnMouseEnter","OnMouseLeave","OnBlur","OnFocus"}) do node[name]=function() end end
            -- Panel contents have no Yoga layout in this adapter; do not stretch every
            -- purchase/confirm button across the panel and fabricate a business click.
            local childArea=id=="activePanel" and {x=0,y=-1000,w=0,h=0} or area
            for _,child in ipairs(node.children) do bind(child,childArea) end
        end
        bind(root,full)
    end
    return h
end
return Host
