local B={mainSha="1cd0cdbec06487a5c60f109d5fd477198cfc8846"}
function B.New()
    local content=require "v035.data.content"
    local ok,errors=content.Load();assert(ok,table.concat(errors or {},"\n"))
    ok,errors=content.ValidateStage1();assert(ok,table.concat(errors or {},"\n"))
    local Memory=require "v035.lab35.MemoryStorage"
    local storage=Memory.New()
    local save=require("v035.core.SaveSystem").New(storage)
    local session=require("v035.core.GameSession").New(content,{saveSystem=save,targetSchema=3})
    assert(session.ready,"pinned main content/session not ready")
    local data,status=session.state.Load(Memory.slot)
    assert(data,status.error and status.error.message or "memory load failed")
    local model=require("v035.ui.PlayModel").New(session,content)
    model.ReturnHome()
    return {session=session,model=model,content=content,storage=storage,mainSha=B.mainSha}
end
return B
