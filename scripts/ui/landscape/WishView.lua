local UI=require "urhox-libs/UI"
local U=require "core.StateUtil"
local F=require "ui.landscape.ReleaseFrame"
local V={}
---@return ReleasePage
function V.New(ctx)
    local preview=ctx.panel=="wishPreview"
    local view=F.New(ctx,preview and "寄出这句话？" or "你的愿望是什么？")
    local result=ctx.session.queries.GetWishView()
    if not result.ok then ctx.model.Notify(result);return view end
    local w=result.value
    local data=ctx.model.Refresh();local shownRevision=data.revision
    F.Text(view.body,w.draftText,"wishDraftText",22)
    if preview then
        F.Text(view.body,"纸上的话将原样放进瓶子。确认寄出后，本次旅程结束。","wishPreviewHint")
        F.Button(view.footer,"cancelWishPreview","返回编辑",function() ctx.Open("wish") end)
        F.Button(view.footer,"confirmWish","封瓶寄出",function() ctx.model.ConfirmEnding("wish",shownRevision) end,w.canConfirm)
        return view
    end
    F.Text(view.body,"点选词语加入愿望，调整前后顺序，或移除重选。用过的词也可以写进这封信。","wishEditHint",15)
    local selected,byId={},{}
    for _,sample in ipairs(w.samples) do byId[sample.sourceTokenId]=sample end
    for index,id in ipairs(w.draftSourceIds) do
        selected[id]=true
        local row=UI.Panel {width="100%",flexShrink=0,gap=6,pointerEvents="box-none"}
        view.body:AddChild(row);F.Text(row,index..". "..byId[id].text,nil,18)
        local actions=UI.Panel {width="100%",flexDirection="row",gap=6,pointerEvents="box-none"};row:AddChild(actions)
        local function move(delta)
            local ids=U.Copy(w.draftSourceIds);ids[index],ids[index+delta]=ids[index+delta],ids[index]
            ctx.model.UpdateWishDraft(ids,shownRevision)
        end
        F.Button(actions,"wish_previous_"..index,"往前移",function() move(-1) end,index>1)
        F.Button(actions,"wish_next_"..index,"往后移",function() move(1) end,index<#w.draftSourceIds)
        F.Button(actions,"wish_remove_"..index,"移除",function()
            local ids=U.Copy(w.draftSourceIds);table.remove(ids,index);ctx.model.UpdateWishDraft(ids,shownRevision)
        end)
    end
    F.Text(view.body,"留下的词",nil,19)
    for _,sample in ipairs(w.samples) do
        local instance=data.live.letters.byId[sample.sourceLetterInstanceId]
        local letter=instance and ctx.content.GetLetter(instance.letterId)
        F.Text(view.body,sample.text.." · 来自《"..(letter and letter.title or "已收来信").."》"..(sample.available and "" or " · 曾用于炼药"),"wishSource_"..sample.sourceTokenId,15)
        F.Button(view.body,"wish_add_"..sample.sourceTokenId,selected[sample.sourceTokenId] and "已加入" or "加入「"..sample.text.."」",function()
            local ids=U.Copy(w.draftSourceIds);ids[#ids+1]=sample.sourceTokenId;ctx.model.UpdateWishDraft(ids,shownRevision)
        end,not selected[sample.sourceTokenId])
    end
    F.Button(view.footer,"backToClosing","返回选择",function() ctx.Open("closing") end)
    F.Button(view.footer,"previewWish","预览并寄出",function() ctx.Open("wishPreview") end,w.canConfirm)
    return view
end
return V
