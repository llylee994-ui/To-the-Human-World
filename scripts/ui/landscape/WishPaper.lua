-- The same normalized composition is used in the editor, preview and keepsake.
local UI=require "urhox-libs/UI"
local Theme=require "urhox-libs/UI/Core/Theme"
local A=require "ui.landscape.JourneyArt"
local P={}
function P.Metrics(text,width)
    local scale=width/700;local count=utf8.len(text) or #text
    local size=21*scale;local pixels=Theme.FontSize(size)
    local w=math.max(82*scale,math.min(320*scale,40*scale+count*pixels*1.05))
    local lines=math.max(1,math.ceil(count*pixels/(w-24*scale)))
    return w,24*scale+lines*pixels*1.3,size
end
function P.Clamp(row,text,width,height)
    local w,h=P.Metrics(text,width)
    local a=math.rad(row.angle or 0);local ex=(math.abs(math.cos(a))*w+math.abs(math.sin(a))*h)/2
    local ey=(math.abs(math.cos(a))*h+math.abs(math.sin(a))*w)/2
    row.x=math.max(math.max(.06,(ex+14)/width),math.min(math.min(.94,1-(ex+14)/width),row.x))
    row.y=math.max(math.max(.22,(ey+14)/height),math.min(math.min(.90,1-(ey+14)/height),row.y))
    return row
end
function P.New(parent,rect,collage,options)
    options=options or {}
    local paper=A.Paper(parent,{id=options.id or "wishPaper",position="absolute",left=rect.x,top=rect.y,width=rect.w,height=rect.h})
    A.Label(paper,"我想……","wishPaperPrefix",28*rect.w/700,{position="absolute",left="9%",top="8%",width="82%",height="12%",fontColor={90,89,67,255}})
    A.Label(paper,"寄往人间",nil,12*rect.w/700,{position="absolute",right="8%",bottom="7%",width="40%",height="6%",textAlign="right",fontColor={148,142,117,255}})
    local cards={}
    for _,row in ipairs(collage.placements) do
        local text=collage.words[row.sourceTokenId] or ""
        local w,h,size=P.Metrics(text,rect.w)
        local card=UI.Panel {id="wish_piece_"..row.sourceTokenId,position="absolute",left=row.x*rect.w-w/2,top=row.y*rect.h-h/2,
            width=w,height=h,pointerEvents=options.editable and "auto" or "none",zIndex=1}
        local visual=UI.Panel {id="wish_visual_"..row.sourceTokenId,width="100%",height="100%",rotate=row.angle,
            backgroundImage="image/界面_纸条_折痕_透明_v01.png",backgroundFit="fill",pointerEvents="none",
            paddingLeft=10*rect.w/700,paddingRight=10*rect.w/700,justifyContent="center",alignItems="center"}
        card:AddChild(visual);paper:AddChild(card)
        A.Label(visual,text,nil,size,{textAlign="center",lineHeight=1.2,width="100%",padding=0})
        cards[row.sourceTokenId]={root=card,visual=visual,width=w,height=h}
    end
    return {root=paper,cards=cards,rect=rect}
end
return P
