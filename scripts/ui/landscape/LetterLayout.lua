-- Pure typesetting geometry. Measurement always comes from the registered font.
local L={}
function L.Layout(segments,width,lineHeight,measure)
    width=math.max(1,width)
    local runs={};local x,y=0,0
    local function newline() x=0;y=y+lineHeight end
    local function place(text,span)
        local w=measure(text)+(span and 6 or 0)
        if x>0 and x+w>width then newline() end
        local last=runs[#runs]
        if not span and last and not last.spanId and last.y==y then
            last.text=last.text..text;last.w=last.w+w
        else
            runs[#runs+1]={text=text,x=x,y=y,w=w,h=lineHeight,
                spanId=span and span.spanId or false,cut=span and span.cut or false}
        end
        x=x+w
    end
    for _,segment in ipairs(segments or {}) do
        local span=segment.kind=="word" and segment or nil
        local text=segment.text or ""
        if span and measure(text)+6<=width and not text:find("\n",1,true) then place(text,span)
        else
            for _,code in utf8.codes(text) do
                local char=utf8.char(code)
                if char=="\n" then newline()
                elseif char~="\r" then place(char,span) end
            end
        end
    end
    return {runs=runs,height=y+lineHeight}
end
local function intersection(a,b)
    local x,y=math.max(a.x,b.x),math.max(a.y,b.y)
    local right,bottom=math.min(a.x+a.w,b.x+b.w),math.min(a.y+a.h,b.y+b.h)
    if right<=x or bottom<=y then return nil end
    return {x=x,y=y,w=right-x,h=bottom-y}
end
L.Intersection=intersection
function L.VisibleRegions(frame,holes)
    local regions={frame}
    for _,hole in ipairs(holes or {}) do
        local nextRegions={}
        for _,r in ipairs(regions) do
            local h=intersection(r,hole)
            if not h then nextRegions[#nextRegions+1]=r
            else
                local function add(x,y,w,height)
                    if w>0 and height>0 then nextRegions[#nextRegions+1]={x=x,y=y,w=w,h=height} end
                end
                add(r.x,r.y,r.w,h.y-r.y)
                add(r.x,h.y+h.h,r.w,r.y+r.h-h.y-h.h)
                add(r.x,h.y,h.x-r.x,h.h)
                add(h.x+h.w,h.y,r.x+r.w-h.x-h.w,h.h)
            end
        end
        regions=nextRegions
    end
    return regions
end
return L
