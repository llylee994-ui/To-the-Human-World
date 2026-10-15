local L=require "ui.landscape.LetterLayout"
local Motion=require "ui.landscape.LetterMotion"
local T={}
function T.Run()
    local n=0
    local function check(ok,msg) n=n+1;assert(ok,msg) end
    local function measure(s) return utf8.len(s)*10 end
    local segments={{kind="text",text="前"},{kind="word",text="睡着",spanId="body:1",cut=false},{kind="text",text="后\n第二行"}}
    local a=L.Layout(segments,60,30,measure)
    check(a.runs[1].text=="前" and a.runs[2].x==10 and a.runs[2].w==26,"inline word uses measured handwritten width")
    check(a.height==60,"explicit newline contributes exactly one new line")
    segments[2].cut=true;local b=L.Layout(segments,60,30,measure)
    for i,r in ipairs(a.runs) do local q=b.runs[i];check(q.x==r.x and q.y==r.y and q.w==r.w,"cut must preserve original layout") end
    local narrow=L.Layout({{kind="word",text="长长的词条",spanId="same",cut=true}},22,30,measure)
    check(narrow.height==150,"oversized word wraps into pieces without losing span identity")
    for _,r in ipairs(narrow.runs) do check(r.spanId=="same" and r.w<=22,"every narrow fragment is correctly sourced and bounded") end
    local duplicate=L.Layout({{kind="word",text="字",spanId="a"},{kind="word",text="字",spanId="b"}},100,30,measure)
    check(duplicate.runs[1].spanId~=duplicate.runs[2].spanId,"same text from two positions has distinct cuts")
    local styled=L.Layout({{kind="text",text="前"},{kind="text",text="愿望",fontWeight="bold"},{kind="text",text="后"}},100,30,
        function(s,weight) return utf8.len(s)*(weight=="bold" and 12 or 10) end)
    check(#styled.runs==3 and styled.runs[2].fontWeight=="bold","a wish stays separate from adjacent regular text")
    check(styled.runs[2].w==24 and styled.runs[3].x==34,"bold text is measured at its actual weight")
    local emphasis=require "ui.landscape.LetterEmphasis"
    local letters=require("systems.Letter").New(require "data.content")
    local annotated=0
    for id,phrase in pairs(emphasis.Phrases) do
        local result=letters.ParseDefinition(id);check(result.ok,"approved wish references an actual order letter")
        local view=result.value;local before=cjson.encode(view.segments)
        local parts,strong,sources={},{},{}
        for _,s in ipairs(emphasis.Segments(view)) do
            parts[#parts+1]=s.text
            if s.fontWeight=="bold" then strong[#strong+1]=s.text end
            if s.kind=="word" then sources[#sources+1]=s.spanId..":"..s.wordId..":"..s.text end
        end
        local original,originalSources={},{}
        for _,s in ipairs(view.segments) do
            original[#original+1]=s.text
            if s.kind=="word" then originalSources[#originalSources+1]=s.spanId..":"..s.wordId..":"..s.text end
        end
        check(table.concat(parts)==table.concat(original),"bold wishes never alter the letter text")
        check(table.concat(strong)==phrase,"only the complete approved wish is emphasized")
        check(table.concat(sources,"|")==table.concat(originalSources,"|"),"word identities and source text survive annotation")
        check(cjson.encode(view.segments)==before,"annotation never mutates the authoritative view")
        annotated=annotated+1
    end
    check(annotated==11,"all eleven current order letters have their approved wish")
    local frame={x=0,y=0,w=100,h=80}
    local holes={{x=10,y=10,w=20,h=15},{x=20,y=15,w=20,h=15},{x=-5,y=50,w=10,h=40}}
    local regions=L.VisibleRegions(frame,holes)
    for x=0,99 do for y=0,79 do
        local function contains(r) return x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h end
        local cut=false;for _,h in ipairs(holes) do if contains(h) then cut=true end end
        local count=0;for _,r in ipairs(regions) do if contains(r) then count=count+1 end end
        check(count==(cut and 0 or 1),"paper mask must cover precisely the non-hole region once")
    end end
    local m=Motion.New();check(m.opening and m.OpenPose().opacity<1,"reader opens through a transient paper pose")
    m.Update(.2,true);check(m.OpenPose().opacity>0 and m.OpenPose().opacity<1,"unfold has intermediate frames")
    m.Update(.2,true);check(not m.opening and m.OpenPose().scale==1,"unfold lands on full readable size")
    check(m.Start({text="字",spanId="a",x=10,y=20,w=16,h=30},{x=200,y=100}),"first successful cut starts")
    check(not m.Start({text="字",spanId="b"},{}),"repeated cut is blocked during the display sequence")
    m.Update(.2,true);check(m.Pose().phase=="snip","scissors precede flight")
    m.Update(.3,true);check(m.Pose().phase=="fly" and m.Pose().x>10,"paper strip moves toward visible collection target")
    m.Update(.3,false);check(not m.flight and not m.opening,"focus loss releases presentation immediately")
    m.Start({text="字",spanId="a",x=10,y=20,w=16,h=30},{x=200,y=100})
    for _=1,70 do m.Update(1/60,true) end
    check(not m.flight,"flight completes without a delayed business callback")
    print("[LetterPresentationTest] PASS assertions="..n.."; measured UTF8 layout, exact mask and pure display timeline")
    return n
end
return T
