-- Shared main business; only the storage and native presentation belong to the 3D host.
local B={mainSha="7f1f6d44b6d9d56166ced231afedac17d217eb3f"}
function B.New()
    local content=require "data.content"
    local ok,errors=content.Load();assert(ok,table.concat(errors or {},"\n"))
    ok,errors=content.ValidateStage1();assert(ok,table.concat(errors or {},"\n"))
    local Memory=require "v035.lab35.MemoryStorage"
    local storage=Memory.New()
    local save=require("core.SaveSystem").New(storage)
    local session=require("core.GameSession").New(content,{saveSystem=save,targetSchema=content.release and 4 or 3})
    assert(session.ready,"shared main content/session not ready")
    local data,status=session.state.Load(Memory.slot)
    assert(data,status.error and status.error.message or "memory load failed")
    local model=require("ui.PlayModel").New(session,content)
    model.ReturnHome()
    return {session=session,model=model,content=content,storage=storage,mainSha=B.mainSha}
end
return B
