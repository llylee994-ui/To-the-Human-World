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
        local full={x=0,y=0,w=w,h=hh};local stage={x=0,y=0,w=w,h=hh}
        local function bind(node,area)
            local id=node.props.id
            if id=="homeStage" then area=stage
            elseif id=="seasideCanvas" then area={x=stage.x,y=stage.y,w=stage.w,h=math.max(0,stage.h-76)}
            elseif id=="seasideControls" then area={x=stage.x,y=stage.y+stage.h-76,w=stage.w,h=76}
            elseif id=="startSalvage" or id=="readCapturedLetter" then area={x=w-388,y=stage.y+stage.h-62,w=240,h=48}
            elseif id=="seasideShop" then area={x=w-136,y=stage.y+stage.h-62,w=122,h=48}
            elseif id=="skipSalvage" then area={x=w-130,y=hh-94,w=116,h=48}
            elseif id=="homeHud" then area={x=0,y=8,w=w,h=48}
            elseif id=="nextDay" then area={x=w-120,y=10,w=108,h=44}
            elseif id=="toggleHomeHints" then area={x=w-200,y=10,w=72,h=44}
            elseif id=="returnHome" then area={x=w-314,y=10,w=106,h=44}
            elseif id=="playMessageArea" then area={x=14,y=hh-56,w=math.min(680,w*.7),h=44}
            elseif id=="playLedger" then area={x=22,y=10,w=210,h=44} end
            if id=="homeHints" or id=="homeObjectFeedback" or (id and id:match("^hint_")) then
                area={x=node.props.left or 0,y=node.props.top or 0,w=node.props.width or 100,h=32}
            elseif id=="rotateGuard" and node.props.visible then area=full
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
