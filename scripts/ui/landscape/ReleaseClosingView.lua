local F=require "ui.landscape.ReleaseFrame"
local V={}
---@return ReleasePage
function V.New(ctx)
    local view=F.New(ctx,"这段旅程，接下来呢？")
    local progress=ctx.session.queries.GetReleaseProgress()
    local wish=ctx.session.queries.GetWishView()
    if not progress.ok or not wish.ok then
        ctx.model.Notify(not progress.ok and progress or wish);return view
    end
    local p,w=progress.value,wish.value
    local shownRevision=ctx.model.Refresh().revision
    F.Text(view.body,"已完成委托 "..p.completedCount.." / "..p.requiredCount.."　·　三星委托 "..p.threeStarCount.." / "..p.requiredThreeStarCount,"releaseProgress")
    local owned={};for _,id in ipairs(p.homeItemIds) do owned[id]=true end
    local missing={}
    for _,item in ipairs(ctx.content.release.homeItems) do
        F.Text(view.body,item.name..(owned[item.id] and " · 已拥有" or " · 尚未购入"),"releaseHome_"..item.id,15)
        if not owned[item.id] then missing[#missing+1]=item.name end
    end
    local reasons={}
    if p.completedCount<p.requiredCount then reasons[#reasons+1]="还差 "..(p.requiredCount-p.completedCount).." 份委托" end
    if p.threeStarCount<p.requiredThreeStarCount then reasons[#reasons+1]="还差 "..(p.requiredThreeStarCount-p.threeStarCount).." 份三星委托" end
    if #missing>0 then reasons[#reasons+1]="还缺："..table.concat(missing,"、") end
    F.Text(view.body,p.canApprentice and "可以留下，也可以寄出自己的愿望。" or "留下做学徒的条件尚未满足。"..table.concat(reasons,"；"),"apprenticeMissing",16)
    if w.phase=="closing_prepare" then
        F.Text(view.body,"先读一封来信，留下一个词，再写自己的愿望。","wishPrepareHint")
        F.Button(view.footer,"prepareWishLetter","打开来信",function()
            local prep=w.preparation;local id=prep.letterInstanceId
            if prep.needsReceive then
                local r=ctx.model.Receive(prep.letterId);if not r.ok then return end
                id=r.value.letterInstanceId
            end
            ctx.Read(id)
        end)
        F.Button(view.body,"chooseApprentice","留下做学徒",function() end,false)
    else
        F.Button(view.footer,"chooseApprentice","留下做学徒",function() ctx.model.ConfirmEnding("apprentice",shownRevision) end,p.canApprentice)
        F.Button(view.footer,"chooseWish","寄出自己的愿望",function()
            if ctx.model.BeginWish().ok then ctx.Open("wish") end
        end)
    end
    F.Button(view.body,"restoreBeforeClosing","返回收尾前",function() ctx.model.RestoreEndingCheckpoint() end)
    return view
end
return V
