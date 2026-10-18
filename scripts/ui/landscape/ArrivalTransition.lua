-- The cover stays above onboarding, retaining input through the short arrival.
local UI=require "urhox-libs/UI"
local Sequence=require "ui.landscape.ArrivalSequence"
local A={}
function A.New(ctx)
    local sequence=Sequence.New()
    local cover=UI.Panel {id="arrivalCover",position="absolute",left=0,top=0,width="100%",height="100%",
        zIndex=1900,pointerEvents="box-only",visible=false,backgroundColor={0,0,0,0},
        onClick=function() end,onPointerDown=function() end}
    ctx.root:AddChild(cover)
    local enter
    local api={}
    function api.Begin(callback)
        if not sequence.Begin() then return false end
        enter=callback;cover.props.backgroundColor={0,0,0,0};cover:SetVisible(true)
        return true
    end
    function api.Update(dt,focused,roomReady)
        if sequence.Update(dt,focused,roomReady)=="enter" then
            local callback=enter;enter=nil
            -- The scene swap always happens under fully opaque black.
            cover.props.backgroundColor={0,0,0,255}
            if callback then callback() end
        end
        local p=sequence.Presentation()
        cover.props.backgroundColor={0,0,0,math.floor(255*p.blackAlpha+.5)}
        cover:SetVisible(sequence.active)
    end
    function api.IsActive() return sequence.active end
    function api.Presentation() return sequence.Presentation() end
    function api.Cancel() enter=nil;sequence.Cancel();cover:SetVisible(false) end
    return api
end
return A
