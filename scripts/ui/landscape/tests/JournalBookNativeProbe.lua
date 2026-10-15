-- Opt-in real Yoga/image check. Opens a read-only book; never creates player records.
local UI=require "urhox-libs/UI/Core/UI"
local Cache=require "urhox-libs/UI/Core/ImageCache"
local Art=require "ui.landscape.JournalBookArt"
local U=require "core.StateUtil"
local N={}
function N.New()
    local frames,phase,done=0,0,false
    local before={}
    return function(ctx)
        if done then return end
        frames=frames+1
        if frames<120 or frames%90~=0 then return end
        local ok,err=pcall(function()
            if phase==0 then
                before=ctx.session.state.GetSnapshot()
                ctx.Open("journal")
                phase=1;return
            end
            local function bounds(id)
                local node=assert(ctx.root:FindById(id),id)
                local r=node:GetAbsoluteLayout()
                assert(r.w>0 and r.h>0,"zero layout: "..id)
                return node,r
            end
            local _,book=bounds("bookArtFrame")
            local _,page=bounds("bookPage")
            local flowers,f=bounds("bookDriedFlowers")
            local grass,g=bounds("bookDriedGrass")
            local close,c=bounds("closePanel")
            local _,panel=bounds("activePanel")
            local layout=Art.Fit(panel.w,panel.h)
            assert(math.abs(book.w/book.h-2/3)<.01,"book proportions changed")
            assert(book.x+book.w>panel.x+panel.w,"designer book must crop at the right edge")
            assert(page.x>=book.x+book.w*.14 and page.x+page.w<=panel.x+panel.w,"text crosses paper stack or screen edge")
            assert(page.y+page.h<=panel.y+layout.decorationTop+1,"flowers cover the reading viewport")
            assert(flowers.props.pointerEvents=="none" and grass.props.pointerEvents=="none","decorations intercept input")
            assert(UI.FindWidgetAt(c.x+c.w/2,c.y+c.h/2)==close,"close button is obstructed")
            for _,path in ipairs({Art.bookImage,Art.flowersImage,Art.grassImage,Art.tabImage}) do
                local w,h=Cache.GetSize(path)
                assert(w>0 and h>0,"image not loaded: "..path)
            end
            assert(U.Equal(before,ctx.session.state.GetSnapshot()),"reading book changed player state")
            local im=Image();assert(graphics:TakeScreenShot(im));assert(im:SavePNG("journal_book_art_native.png"))
            print("[JournalBookNative] PASS actual Yoga, four loaded images, reading/decor bounds, close hit, unchanged player; NOT phone evidence "..cjson.encode({book=book,page=page,flowers=f,grass=g,close=c}))
            done=true
        end)
        if not ok then done=true;print("[JournalBookNative] FAIL "..tostring(err)) end
    end
end
return N
