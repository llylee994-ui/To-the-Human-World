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
    return with({backgroundColor={0,0,0,0},backgroundImage=H.paperImage,backgroundFit="fill",
        backgroundSlice={18,18,18,18},borderWidth=0,borderRadius=0,padding={8,14},pointerEvents="box-none"},props)
end
function H.Paper(props) return UI.Panel(H.PaperProps(props)) end
function H.Tag(props)
    -- Hints need a quiet contrast patch over the room, not a framed text card.
    return UI.Label(with({backgroundColor={39,30,24,205},borderWidth=0,borderRadius=12,
        fontFamily=H.fontFamily,fontWeight="normal",fontColor={255,244,218,255},fontSize=14,padding={5,10},minHeight=30,textAlign="center",
        whiteSpace="nowrap",pointerEvents="none"},props))
end
return H
