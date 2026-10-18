-- Shared measured geometry for the note and compact hints; no fixed text boxes.
local UI=require "urhox-libs/UI"
local Theme=require "urhox-libs/UI/Core/Theme"
local Layout=require "ui.landscape.LetterLayout"
local M={}
function M.Text(text,width,size,lineHeight,family)
    local pixels=Theme.FontSize(size)
    local face=Theme.FontFace(family or "story","normal")
    local layout=Layout.Layout({{text=text}},math.max(1,width-4),pixels*lineHeight,function(value)
        return UI.MeasureTextWidth(value,pixels,face)
    end)
    local rows={};local measured=0
    for _,run in ipairs(layout.runs) do rows[#rows+1]=run.text;measured=math.max(measured,run.w) end
    local wrapped=table.concat(rows,"\n")
    -- Glyph ascenders/descenders can exceed size * lineHeight. Use the
    -- registered font's actual box, rather than assuming its nominal line box.
    local bounds=UI.MeasureTextFit and UI.MeasureTextFit(wrapped,{fontSize=pixels,fontFace=face,
        width=width,lineHeight=lineHeight,multiline=true})
    local height=math.max(layout.height,bounds and bounds.height or 0)
    return {text=wrapped,width=math.ceil(measured),height=math.ceil(height+pixels*.22)}
end
function M.Tooltip(text,availableWidth,know)
    local padding,gap,button=12,8,40
    local cap=math.max(1,math.min(320,availableWidth)-padding*2)
    local one=M.Text(text,10000,15,1.45)
    local contentWidth=math.min(cap,math.max(know and 104 or 1,one.width+4))
    local content=M.Text(text,contentWidth,15,1.45)
    return {width=contentWidth+padding*2,height=content.height+padding*2+(know and gap+button or 0),content=content}
end
return M
