-- Text is clipped before the separate fixed button even while fonts load.
local UI=require "urhox-libs/UI"
local H=require "ui.landscape.HarborStyle"
local Emphasis=require "ui.landscape.LetterEmphasis"
local B={}
function B.Render(ctx,parent,summary,l)
    local r=l.wish
    local paper=H.Paper {id="brewWish",position="absolute",left=r.x,top=r.y,width=r.w,height=r.h,compact=true,padding=0}
    parent:AddChild(paper)
    local tr=l.wishText;local br=l.wishButton
    local area=UI.Panel {id="brewWishInfo",position="absolute",left=tr.x-r.x,top=tr.y-r.y,width=tr.w,height=tr.h,
        overflow="hidden",pointerEvents="none"};paper:AddChild(area)
    local def=summary.sourceLetterId and ctx.content.GetLetter(summary.sourceLetterId)
    local sender=def and ctx.content.GetNpc(def.senderId)
    local phrase=summary.sourceLetterId and (Emphasis.Phrases[summary.sourceLetterId] or summary.requirementDesc) or "先阅读来信，接下想回应的心愿。"
    local limit=math.max(3,math.floor(tr.w/18))
    if utf8.len(phrase)>limit then phrase=phrase:sub(1,utf8.offset(phrase,limit)-1).."…" end
    area:AddChild(UI.Label {id="brewWishText",text=summary.orderId and (sender and sender.name or "当前委托") or "尚未接下委托",
        position="absolute",left=0,top=0,width=tr.w,height=22,fontFamily=H.fontFamily,fontSize=13,
        fontColor={65,47,32,255},whiteSpace="nowrap",pointerEvents="none"})
    area:AddChild(UI.Label {id="brewWishSummary",text=phrase,position="absolute",left=0,top=22,width=tr.w,height=22,
        fontFamily=H.fontFamily,fontSize=12,fontColor={92,66,43,255},whiteSpace="nowrap",pointerEvents="none"})
    paper:AddChild(H.Button {id="brewLetters",text="查看来信",position="absolute",left=br.x-r.x,top=br.y-r.y,
        width=br.w,height=br.h,minHeight=44,fontSize=13,onClick=function()
            local data=ctx.model.Refresh();local order=data and data.currentOrder
            if order then ctx.Read(order.letterInstanceId) else ctx.Open("letters") end
        end})
end
return B
