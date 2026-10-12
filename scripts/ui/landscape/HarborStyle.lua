-- Shared handpainted harbor chrome. Dynamic text stays in UI widgets.
local UI=require "urhox-libs/UI"
local H={}
-- Maker texture generation timed out without a delivery. Keep native UI chrome
-- usable until a verified texture exists; never point the game at missing files.
local paperGradient={direction="vertical",from={247,238,216,255},to={230,211,176,255}}
local function with(base,props)
    local out={};for k,v in pairs(base) do out[k]=v end
    for k,v in pairs(props or {}) do out[k]=v end
    return out
end
function H.Button(props)
    local p=with({minHeight=44,fontSize=15,padding={8,14},flexShrink=0},props)
    -- Clear variant/theme decoration so all interaction states share the art.
    p.backgroundColor={221,185,124,255};p.hoverBackgroundColor={235,205,154,255}
    p.pressedBackgroundColor={174,133,75,255};p.disabledBackgroundColor={171,155,129,255}
    p.backgroundGradient={direction="vertical",from={239,216,172,255},to={202,163,103,255}}
    p.hoverBackgroundGradient={direction="vertical",from={247,228,193,255},to={221,186,132,255}}
    p.pressedBackgroundGradient={direction="vertical",from={190,149,90,255},to={218,182,123,255}}
    p.disabledBackgroundGradient={direction="vertical",from={197,183,159,255},to={172,155,129,255}}
    p.variantBackgroundGradient={};p.variantHoverBackgroundGradient={};p.variantPressedBackgroundGradient={};p.variantDisabledBackgroundGradient={}
    p.textColor={59,40,23,255};p.disabledTextColor={91,80,64,255}
    p.borderWidth=1;p.borderColor={117,79,38,255};p.borderRadius=3
    p.boxShadow={{x=0,y=2,blur=0,color={67,43,21,100}}}
    p.hoverBoxShadow=p.boxShadow;p.pressedBoxShadow=false;p.disabledBoxShadow=false;p.glowShadow={}
    return UI.Button(p)
end
function H.Paper(props)
    return UI.Panel(with({backgroundColor={244,232,208,255},backgroundGradient=paperGradient,
        borderWidth=1,borderColor={174,142,91,255},borderRadius=2,padding={8,14},pointerEvents="box-none"},props))
end
function H.Tag(props)
    return UI.Label(with({backgroundColor={244,232,208,250},backgroundGradient=paperGradient,borderWidth=1,borderColor={174,142,91,230},borderRadius=2,
        fontColor={65,46,28,255},fontSize=14,padding={7,12},minHeight=32,textAlign="center",
        whiteSpace="nowrap",pointerEvents="none"},props))
end
return H
