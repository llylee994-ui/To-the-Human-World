-- Offline evidence only: production tray geometry, supplied real-font measurement.
local T={}
function T.Run()
    local UI=require "urhox-libs/UI"
    local Theme=require "urhox-libs/UI/Core/Theme"
    local Data=require "data.content"
    local Slip=require "ui.landscape.WordSlip"
    local Drawer=require "ui.landscape.WordTrayDrawer"
    local Art=require "ui.landscape.WordTrayArt"
    UI.MeasureTextWidth=assert(rawget(_G,"SLIP_FONT_MEASURE"))
    local export=assert(rawget(_G,"SLIP_EVIDENCE"))
    local samples={"温柔","明天","好好睡一觉","把工钱从下次里洗出来","椅子不该跪着迎客","远行"}
    for _,word in ipairs(Data.words) do samples[#samples+1]=word.displayText end
    local checked=0
    for _,size in ipairs({{1280,720},{800,360},{1920,1080}}) do
        local cards={}
        for i,value in ipairs(samples) do cards[i]={text=value,tokenId="evidence:"..i,categoryId="one",sourceTitle="纸条适配",available=true} end
        cards[4].selectedRole="main"
        local ctx={viewport={w=size[1],h=size[2]},safeInsets={left=0,top=0,right=0,bottom=0},Close=function() end,
            model={message="",Action=function() return {enabled=true} end},
            session={queries={GetWordTray=function() return {ok=true,value={cards=cards,categories={{id="one",title="词语",availableCount=#cards}}}} end}}}
        local root=UI.Panel {};Drawer.Open(ctx);Drawer.Render(ctx,root)
        local outputs={}
        for _,card in ipairs(cards) do
            local node=assert(root:FindById("wordTrayCard_"..card.tokenId))
            local label=assert(root:FindById("wordTrayText_"..card.tokenId))
            local metrics=node.wordSlip
            for line in (metrics.text.."\n"):gmatch("(.-)\n") do
                assert(UI.MeasureTextWidth(line,Theme.FontSize(metrics.fontSize),"story")<=metrics.width-28,"real-font overflow: "..card.text)
                checked=checked+1
            end
            outputs[#outputs+1]={original=card.text,x=node.props.left,y=node.props.top,metrics=metrics,
                fontPixels=Theme.FontSize(metrics.fontSize),label=label.props}
        end
        export(size[1],size[2],Art.Fit(math.floor(size[1]*Drawer.WidthRatio),size[2]-24).cards,outputs)
    end
    print("[WordSlipEvidence] real font lines fit="..checked.."; offline geometry only")
    return checked
end
return T
