-- Exactly one real GameSession + PlayModel in the preview process.
local B={}
function B.New()
    local content=require "data.content"
    local loaded,errors=content.Load()
    assert(loaded,table.concat(errors or {},"\n"))
    local valid,details=content.ValidateStage1()
    assert(valid,table.concat(details or {},"\n"))
    local storage=require("lab.MemoryStorage").New("d3_lab_r3")
    local save=require("core.SaveSystem").New(storage)
    local session=require("core.GameSession").New(content,{saveSystem=save,targetSchema=3})
    assert(session.ready,"Real content/session validation failed")
    local data,status=session.state.Load("d3_lab_r3")
    assert(data,status.error and status.error.message or "Lab load failed")
    local model=require("ui.PlayModel").New(session,content)
    model.ReturnHome()
    print("[D3-LAB] schema=3 storage=memory slot=d3_lab_r3 content="..content.contentVersion)
    return {content=content,storage=storage,session=session,model=model}
end
return B
