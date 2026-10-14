-- Shared handpainted harbor chrome. Text remains selectable UI content.
local UI=require "urhox-libs/UI"
local H={
    fontFamily="story",
    woodImage="image/界面_深木牌_透明_v01_20261013070534.png",
    paperImage="image/界面_柔边纸面_透明_v01_20261013070534.png",
}
local function with(base,props)
    local out={};for k,v in pairs(base) do out[k]=v end
    for k,v in pairs(props or {}) do out[k]=v end
    return out
end
function H.Button(props)
    local p=with({minHeight=44,fontSize=15,fontFamily=H.fontFamily,fontWeight="normal",padding={8,14},flexShrink=0},props)
    -- Cover crops transparent source padding instead of squeezing the wood grain.
    p.backgroundImage=H.woodImage;p.backgroundFit="cover"
    p.backgroundColor={0,0,0,0};p.hoverBackgroundColor={0,0,0,0}
    p.pressedBackgroundColor={0,0,0,0};p.disabledBackgroundColor={0,0,0,0}
    p.backgroundGradient=nil;p.hoverBackgroundGradient=nil;p.pressedBackgroundGradient=nil;p.disabledBackgroundGradient=nil
    p.variantBackgroundGradient={};p.variantHoverBackgroundGradient={};p.variantPressedBackgroundGradient={};p.variantDisabledBackgroundGradient={}
    p.backgroundImageOpacity=.96;p.hoverBackgroundImageOpacity=1;p.pressedBackgroundImageOpacity=.82;p.disabledBackgroundImageOpacity=.6
    p.textColor={255,244,218,255};p.disabledTextColor={226,214,193,255}
    p.borderWidth=0;p.hoverBorderWidth=0;p.pressedBorderWidth=0;p.borderRadius=0
    p.boxShadow=false;p.hoverBoxShadow=false;p.pressedBoxShadow=false;p.disabledBoxShadow=false;p.glowShadow={}
    p.pressedPadding=p.padding
    return UI.Button(p)
end
-- Also usable by ScrollView so transient messages share the same paper.
function H.PaperProps(props)
    local p=with({backgroundColor={0,0,0,0},backgroundImage=H.paperImage,backgroundFit="fill",
        backgroundSlice={32,32,32,32},borderWidth=0,borderRadius=0,padding=32,pointerEvents="box-none"},props)
    -- One policy for every paper surface, including callers with legacy padding=0.
    -- Short HUD/sea strips scale the source vertically and need smaller top insets.
    local compact=p.compact==true or (type(p.height)=="number" and p.height<=96) or (type(p.maxHeight)=="number" and p.maxHeight<=96)
    local function edge(name,index)
        local value=p["padding"..name]
        if value==nil then
            local pad=p.padding
            if type(pad)=="number" then value=pad
            elseif type(pad)=="table" then
                value=pad[name:lower()] or (#pad==2 and pad[(index==2 or index==4) and 2 or 1] or pad[index])
            end
        end
        local minimum=(compact and (index==1 or index==3)) and 6 or 32
        return math.max(minimum,type(value)=="number" and value or minimum)
    end
    p.paddingTop=edge("Top",1);p.paddingRight=edge("Right",2)
    p.paddingBottom=edge("Bottom",3);p.paddingLeft=edge("Left",4)
    p.compact=nil
    return p
end
function H.Paper(props) return UI.Panel(H.PaperProps(props)) end
function H.Tag(props)
    -- Hints need a quiet contrast patch over the room, not a framed text card.
    return UI.Label(with({backgroundColor={39,30,24,205},borderWidth=0,borderRadius=12,
        fontFamily=H.fontFamily,fontWeight="normal",fontColor={255,244,218,255},fontSize=14,padding={5,10},minHeight=30,textAlign="center",
        whiteSpace="nowrap",pointerEvents="none"},props))
end
return H
