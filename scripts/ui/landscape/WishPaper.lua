-- One canonical composition for editing, preview, frozen endings and different screens.
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local A=require "ui.landscape.JourneyArt"
local Slip=require "ui.landscape.WordSlip"
local U=require "core.StateUtil"
local C=require "systems.WishCollage"
local Decor=require "data.wish_decorations"
local Art=require "ui.landscape.BrewArt"
local P={image="image/wish-collage-r1/soft-scrollwork-letter-paper.png"}
function P.Metrics(text,width)
    local m=Slip.Metrics(text,{fontSize=18,maxWidth=320})
    local k=width/900;local result=U.Copy(m)
    for _,key in ipairs({"width","height","fontSize","paddingX","paddingY","textHeight"}) do result[key]=m[key]*k end
    return result.width,result.height,result.fontSize,result
end
function P.Size(row,text,width)
    local frame=row.decorationId and Decor.byId[row.decorationId]
    local w,h
    if frame then h=frame.displayHeight*width/900;w=h*frame.w/frame.h
    else w,h=P.Metrics(text or "",width) end
    return w*(row.scale or 1),h*(row.scale or 1)
end
function P.Clamp(row,text,width,height)
    if row.freePlacement then
        -- Keep the chosen decoration size and paper-edge overhang intact.
        row.x=math.max(-1,math.min(2,row.x));row.y=math.max(-1,math.min(2,row.y))
        return row
    end
    local w,h=P.Size(row,text,width)
    local a=math.rad(row.angle or 0)
    local ex=(math.abs(math.cos(a))*w+math.abs(math.sin(a))*h)/2
    local ey=(math.abs(math.cos(a))*h+math.abs(math.sin(a))*w)/2
    local fit=math.min(1,width*.46/math.max(1,ex),height*.37/math.max(1,ey))
    if fit<1 then row.scale=math.max(.25,(row.scale or 1)*fit);ex=ex*fit;ey=ey*fit end
    row.x=math.max(.03+ex/width,math.min(.97-ex/width,row.x))
    row.y=math.max(math.max(.22,.18+ey/height),math.min(.94-ey/height,row.y))
    return row
end
function P.Bounds(row,text,rect)
    local w,h=P.Size(row,text,rect.w);local a=math.rad(row.angle or 0)
    local bw=math.abs(math.cos(a))*w+math.abs(math.sin(a))*h
    local bh=math.abs(math.sin(a))*w+math.abs(math.cos(a))*h
    return {x=rect.x+row.x*rect.w-bw/2,y=rect.y+row.y*rect.h-bh/2,w=bw,h=bh}
end
-- Fit the union of the paper and rotated pieces; placements remain in paper coordinates.
function P.FitComposition(area,rows,words,aspect)
    local base={x=0,y=0,w=900,h=900/aspect}
    local left,top,right,bottom=0,0,base.w,base.h
    for _,row in ipairs(rows) do
        local text=words[row.sourceTokenId] or ""
        local b=P.Bounds(P.Clamp(U.Copy(row),text,base.w,base.h),text,base)
        left=math.min(left,b.x);top=math.min(top,b.y)
        right=math.max(right,b.x+b.w);bottom=math.max(bottom,b.y+b.h)
    end
    local margin=(left<0 or top<0 or right>base.w or bottom>base.h) and 8 or 0
    local width,height=right-left,bottom-top
    local scale=math.min((area.w-2*margin)/width,(area.h-2*margin)/height)
    return {x=area.x+(area.w-width*scale)/2-left*scale,
        y=area.y+(area.h-height*scale)/2-top*scale,w=base.w*scale,h=base.h*scale}
end
function P.Frame(frame,props)
    local panel=UI.Panel(props)
    function panel:Render(vg) Art.Draw(vg,frame,self:GetAbsoluteLayout(),self.props.opacity or 1) end
    return panel
end
function P.New(parent,rect,collage,options)
    options=options or {}
    local paper=UI.Panel {id=options.id or "wishPaper",position="absolute",left=rect.x,top=rect.y,width=rect.w,height=rect.h,
        backgroundImage=not options.ghost and P.image or nil,backgroundFit="fill",pointerEvents=options.editable and "auto" or "none",overflow="visible"}
    parent:AddChild(paper)
    if not options.ghost then A.Label(paper,"我想……","wishPaperPrefix",28*rect.w/900,{position="absolute",left="15%",top="9%",width="70%",height="9%",
        textAlign="center",lineHeight=1.1,fontColor={105,91,73,255}}) end
    local cards={}
    for i,row in ipairs(collage.placements) do
        local id=C.Id(row);local text=row.sourceTokenId and collage.words[row.sourceTokenId] or ""
        local display=options.ghost and U.Copy(row) or P.Clamp(U.Copy(row),text,rect.w,rect.h)
        local w,h=P.Size(display,text,rect.w)
        local card=UI.Panel {id="wish_piece_"..id,position="absolute",left=display.x*rect.w-w/2,top=display.y*rect.h-h/2,
            width=w,height=h,pointerEvents=options.editable and "auto" or "none",zIndex=C.Depth(row,i)+i*.00001}
        local visual
        if row.decorationId then
            visual=P.Frame(Decor.byId[row.decorationId],{id="wish_visual_"..id,width="100%",height="100%",rotate=display.angle,pointerEvents="none"})
        else
            visual=Slip.Surface {id="wish_visual_"..id,width="100%",height="100%",rotate=display.angle,pointerEvents="none"}
            local _,_,_,metrics=P.Metrics(text,rect.w*(display.scale or 1))
            local label=Slip.Label(visual,metrics,"wish_text_"..id)
            -- Canonical line breaks scale with the paper; do not rewrap a short word at fractional sizes.
            if metrics.lineCount==1 then Widget.SetStyle(label,{whiteSpace="nowrap"}) end
        end
        function card:HitTest(x,y)
            local b=self:GetAbsoluteLayoutForHitTest();local dx,dy=x-b.x-b.w/2,y-b.y-b.h/2
            local current=cards[id] and cards[id].display or display
            local a=math.rad(-current.angle);local xx,yy=dx*math.cos(a)-dy*math.sin(a),dx*math.sin(a)+dy*math.cos(a)
            return math.abs(xx)<=b.w/2 and math.abs(yy)<=b.h/2
        end
        card:AddChild(visual --[[@as Widget]]);paper:AddChild(card)
        cards[id]={root=card,visual=visual,width=w,height=h,display=display}
    end
    local result={root=paper,cards=cards,rect=rect}
    if options.editable and options.hitArea then
        local area=options.hitArea
        -- UI skips absolute subtrees outside their HitTest: include the worktable so
        -- paper-edge decorations and their handles remain selectable there.
        function paper:HitTest(x,y)
            return x>=area.x and x<=area.x+area.w and y>=area.y and y<=area.y+area.h
        end
    end
    function result.Preview(id,row)
        local card=cards[id];if not card then return end
        local text=collage.words[row.sourceTokenId] or ""
        local w,h=P.Size(row,text,rect.w)
        card.width=w;card.height=h;card.display=U.Copy(row)
        Widget.SetStyle(card.root,{left=row.x*rect.w-w/2,top=row.y*rect.h-h/2,width=w,height=h})
        Widget.SetStyle(card.visual,{rotate=row.angle,scale=1})
        if row.sourceTokenId then
            local _,_,_,m=P.Metrics(text,rect.w*(row.scale or 1))
            local label=card.visual:FindById("wish_text_"..id) --[[@as Label?]]
            if label then
                label:SetText(m.text)
                Widget.SetStyle(label,{left=m.paddingX,top=(m.height-m.textHeight)/2,width=m.width-2*m.paddingX,
                    height=m.textHeight,fontSize=m.fontSize,lineHeight=m.lineHeight,whiteSpace=m.lineCount==1 and "nowrap" or "normal"})
            end
        end
    end
    function result.Select(id)
        for key,card in pairs(cards) do
            Widget.SetStyle(card.visual,{borderWidth=key==id and 1 or 0,borderColor={153,113,59,210},borderRadius=1})
        end
    end
    return result
end
return P
