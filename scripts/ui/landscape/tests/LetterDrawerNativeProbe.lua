-- Opt-in native rendering; example letters live in an isolated memory fixture.
local UI=require "urhox-libs/UI/Core/UI"
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local N={}
function N.New()
    local frame,phase,done=0,0,false
    ---@type table|nil
    local view
    local before={}
    local function capture(name)
        local image=Image();assert(graphics:TakeScreenShot(image));assert(image:SavePNG(name))
    end
    return function(ctx)
        if done then return end
        frame=frame+1
        if view then view.Update() end
        if frame<120 or frame%90~=0 then return end
        local ok,err=pcall(function()
            if phase==0 then
                before=ctx.session.state.GetSnapshot()
                local fixture=F.New(Data,{targetSchema=3})
                local rows,names={},{}
                for _,npc in ipairs(Data.npcs) do names[npc.id]=npc.name end
                for _,definition in ipairs(Data.letters) do
                    if definition.kind=="order" and #rows<12 then
                        local index=#rows+1
                        rows[index]={letterInstanceId="drawer-preview-"..index,title=definition.title,
                            senderName=names[definition.senderId] or "寄信人",read=index>2,remainingCutCount=0}
                    end
                end
                -- Read-only projection: no ReceiveLetter calls or progression bypasses.
                fixture.session.queries.GetLetters=function() return U.Ok(rows) end
                local checks=require("ui.landscape.DevChecks") --[[@as table]]
                local previous=checks.nativeProbe;checks.nativeProbe=false
                view=require("ui.landscape.AppView").New(fixture.session,Data)
                checks.nativeProbe=previous
                ctx.root:SetVisible(false);ctx.root.parent:AddChild(view.root)
                view.Open("letters");view.Update()
                view.root:AddChild(require("urhox-libs/UI").Label {position="absolute",left=12,bottom=8,
                    text="本地排版预览 · 示例来信 · 不写玩家存档",fontSize=13,
                    fontColor={255,239,209,255},pointerEvents="none",zIndex=100})
                phase=1;return
            end
            local scroll=assert(view.root:FindById("letterDrawerCards"))
            local bounds=scroll:GetAbsoluteLayout()
            local panel=assert(view.root:FindById("activePanel")):GetAbsoluteLayout()
            capture("letter_drawer_layout_inspect.png")
            -- Yoga rounds these separate edges to whole UI pixels.
            assert(bounds.y+bounds.h<=panel.y+panel.h*.66+1,"scroll reaches decoration band "..cjson.encode({scroll=bounds,panel=panel}))
            assert(math.abs(panel.w-panel.h)<1,"drawer is stretched")
            for _,id in ipairs({"letterDrawerScrolls","letterDrawerFlowersTop","letterDrawerFlowersBottom"}) do
                assert(view.root:FindById(id).props.pointerEvents=="none","decoration blocks input")
            end
            local hit=assert(UI.FindWidgetAt(bounds.x+bounds.w*.5,bounds.y+bounds.h*.85))
            local ancestor=hit
            while ancestor and ancestor~=scroll do ancestor=ancestor.parent end
            assert(ancestor==scroll,"scroll hit blocked by decoration")
            assert(U.Equal(before,ctx.session.state.GetSnapshot()),"preview changed player state")
            if phase==1 then
                capture("letter_drawer_layout_top.png")
                scroll:SetScroll(0,100000)
                phase=2
            elseif phase==2 then
                local _,y=scroll:GetScroll()
                assert(y>0,"fixture must overflow")
                assert(math.abs(y-(scroll.contentHeight_-scroll:GetLayout().h))<1,"last row cannot be reached")
                local thumb=assert(view.root:FindById("letterDrawerThumb")):GetAbsoluteLayout()
                assert(thumb.y+thumb.h<=bounds.y+bounds.h+1,"thumb leaves rail")
                capture("letter_drawer_layout_bottom.png")
                scroll:SetScroll(0,0);phase=3
            else
                capture("letter_drawer_layout_final.png")
                print("[LetterDrawerNativeProbe] PASS designer images, native scroll top/bottom, decoration input passthrough, unchanged player save; fixture only, NOT phone evidence")
                done=true
            end
        end)
        if not ok then done=true;print("[LetterDrawerNativeProbe] FAIL "..tostring(err)) end
    end
end
return N
