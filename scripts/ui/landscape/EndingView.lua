local F=require "ui.landscape.ReleaseFrame"
local V={}
---@return ReleasePage
function V.New(ctx)
    local view=F.New(ctx,"旅程已结束")
    local result=ctx.session.queries.GetEndingView()
    if not result.ok then ctx.model.Notify(result);return view end
    local saved=result.value
    if not saved.ending then return view end
    F.Text(view.body,saved.ending.title,"releaseEndingTitle",25)
    F.Text(view.body,saved.ending.text,"releaseEndingText",19)
    if ctx.newPlaythroughConfirm then
        F.Text(view.body,"开始新周目会覆盖当前首发存档，包括这次结局及结束前进度。旧试用存档会保留。是否继续？","newPlaythroughWarning",17)
        F.Button(view.footer,"cancelNewPlaythrough","保留这次旅程",function() ctx.newPlaythroughConfirm=false;ctx.model.dirty=true end)
        F.Button(view.footer,"confirmNewPlaythrough","确认开始新周目",function()
            if ctx.model.StartNewPlaythrough(true).ok then ctx.newPlaythroughConfirm=false end
        end,saved.canStartNew)
    else
        F.Button(view.footer,"restoreBeforeEnding","返回结束前",function() ctx.model.RestoreEndingCheckpoint() end,saved.canRestore)
        F.Button(view.footer,"startNewPlaythrough","开始新周目",function() ctx.newPlaythroughConfirm=true;ctx.model.dirty=true end,saved.canStartNew)
    end
    return view
end
return V
