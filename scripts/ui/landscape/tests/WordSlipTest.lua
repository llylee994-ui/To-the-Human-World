-- Catches fixed-width overflow, overlapping variable rows, and inconsistent collage sizes.
-- Font/Widget adapters below are explicit; native rendering is a separate check.
local T={}
function T.Run()
    local UI=require "urhox-libs/UI"
    local Theme=require "urhox-libs/UI/Core/Theme"
    local old=UI.MeasureTextWidth
    UI.MeasureTextWidth=function(value,size)
        local w=0
        for _,cp in utf8.codes(value) do w=w+size*(cp>127 and 1 or cp==87 and 1.2 or .35) end
        return w
    end
    local count=0
    local function check(ok,message) assert(ok,message);count=count+1 end
    local Drawer=require "ui.landscape.WordTrayDrawer"
    local Art=require "ui.landscape.WordTrayArt"
    local samples={"温柔","明天","好好睡一觉","把工钱从下次里洗出来","WWWWWW","iiiiii","椅子不该跪着迎客","远行"}
    for _,vp in ipairs({{w=1280,h=720},{w=800,h=360},{w=1920,h=1080}}) do
        local cards={}
        for i,value in ipairs(samples) do cards[i]={text=value,tokenId="source:"..i,categoryId="one",available=true,sourceTitle="来源"} end
        cards[4].available=false;cards[7].selectedRole="main"
        local ctx={viewport=vp,safeInsets={left=0,top=0,right=0,bottom=0},model={message="",Action=function() return {enabled=true} end},
            session={queries={GetWordTray=function() return {ok=true,value={cards=cards,categories={{id="one",title="情绪类",availableCount=7}}}} end}},Close=function() end}
        local parent=UI.Panel {};Drawer.Open(ctx);Drawer.Render(ctx,parent)
        local area=Art.Fit(math.floor(vp.w*Drawer.WidthRatio),vp.h-24).cards
        ---@type table[]
        local mounted={}
        for _,card in ipairs(cards) do
            local node=assert(parent:FindById("wordTrayCard_"..card.tokenId))
            local label=assert(parent:FindById("wordTrayText_"..card.tokenId))
            local p=label.props
            local pad=14
            for line in (p.text.."\n"):gmatch("(.-)\n") do
                check(UI.MeasureTextWidth(line,Theme.FontSize(p.fontSize))<=node.props.width-2*pad+.01,"long word must fit within real paper padding: "..card.text)
            end
            check(p.text:gsub("\n","")==card.text,"line wrapping preserves full source text")
            check(node.props.left>=0 and node.props.left+node.props.width<=area.w,"slip stays in tray without hitting category tabs")
            mounted[#mounted+1]=node
        end
        for i,a in ipairs(mounted) do for j=i+1,#mounted do
            local b=mounted[j];local x,y=a.props,b.props
            check(x.left+x.width<=y.left or y.left+y.width<=x.left or x.top+x.height<=y.top or y.top+y.height<=x.top,"variable-height rows never overlap")
        end end
        local last=mounted[#mounted].props --[[@as table]]
        check(parent:FindById("wordTrayStrips").children[1].props.height>=last.top+last.height,"scroll content includes the final full strip")
    end
    local Slip=require "ui.landscape.WordSlip"
    local wide=Slip.Metrics("WWWWWW",{maxWidth=300})
    local narrow=Slip.Metrics("iiiiii",{maxWidth=300})
    check(wide.width>narrow.width,"same character count respects actual proportional glyph widths")
    local Paper=require "ui.landscape.WishPaper"
    local U=require "core.StateUtil"
    local collage={words={token=samples[4]},placements={{sourceTokenId="token",x=.94,y=.9,angle=15}}}
    local original=U.Copy(collage)
    for _,width in ipairs({360,700}) do
        local rect={x=0,y=0,w=width,h=width/1.45}
        local edit=Paper.New(UI.Panel {},rect,collage,{editable=true})
        local preview=Paper.New(UI.Panel {},rect,collage)
        check(edit.cards.token.width==preview.cards.token.width and edit.cards.token.height==preview.cards.token.height,"editor and keepsake use identical slip dimensions")
        local label=assert(edit.cards.token.visual:FindById("wish_text_token"))
        for line in (label.props.text.."\n"):gmatch("(.-)\n") do
            check(UI.MeasureTextWidth(line,Theme.FontSize(label.props.fontSize))<=label.props.width,"collage lines fit their paper")
        end
        local card=edit.cards.token --[[@as table]]
        local a=math.rad(15);local ex=(math.cos(a)*card.width+math.sin(a)*card.height)/2
        check(card.root.props.left+card.width/2+ex<=width,"rotated long slip stays on the letter")
    end
    check(U.Equal(original,collage),"display reflow never rewrites saved placements or source text")
    for _,text in ipairs({"安安稳稳","合上眼"}) do
        local paper=Paper.New(UI.Panel {},{x=0,y=0,w=712,h=534},{words={token=text},
            placements={{sourceTokenId="token",x=.5,y=.5,angle=4,scale=1.25}}})
        check(paper.cards.token.visual:FindById("wish_text_token").props.whiteSpace=="nowrap",
            "short collage words keep their canonical single line at fractional scales")
    end
    local Interaction=require "ui.landscape.BrewInteraction"
    local model={Action=function() return {enabled=true} end,Drop=function() return {ok=true} end}
    local motion=Interaction.New(model,function() end)
    local source={kind="word",id="source:4",text=samples[4],wordSlip=Slip.Metrics(samples[4],{maxWidth=190})}
    motion.Begin(source,{button=MOUSEB_LEFT,pointerType="mouse",pointerId=1,x=10,y=10})
    check(motion.drag.wordSlip==source.wordSlip,"drag keeps the source strip's measured dimensions")
    motion.Commit(source,20,20,{x=200,y=200,w=50,h=50})
    check(motion.SampleFlight().wordSlip==source.wordSlip,"accepted flight keeps the source dimensions before animation scaling")
    local Cache=require "urhox-libs/UI/Core/ImageCache"
    local oldGet,oldSize=Cache.Get,Cache.GetSize
    local saved={};local patterns={}
    for _,name in ipairs({"nvgBeginPath","nvgRect","nvgFillPaint","nvgFill","nvgImagePattern"}) do saved[name]=rawget(_G,name) or false end
    Cache.Get=function() return 1 end;Cache.GetSize=function() return 2048,683 end
    nvgBeginPath=function() end;nvgRect=function() end;nvgFillPaint=function() end;nvgFill=function() end
    nvgImagePattern=function(_,_,_,w,h) patterns[#patterns+1]={w=w,h=h};return {} end
    Slip.Draw({}, {x=0,y=0,w=250,h=50},1)
    check(#patterns==3,"paper uses two preserved ends and one stretchable middle")
    check(math.abs(patterns[1].w/2048-50/683)<.0001 and patterns[3].w==patterns[1].w,"torn ends retain the vertical texture scale instead of stretching with text")
    Cache.Get,Cache.GetSize=oldGet,oldSize
    for name,fn in pairs(saved) do _G[name]=fn or nil end
    UI.MeasureTextWidth=old
    print("[WordSlipTest] PASS assertions="..count.."; explicit font/widget adapters; native/mobile separate")
    return count
end
return T
