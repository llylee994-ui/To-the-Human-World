local T={}
function T.Run()
    local session=GetGameSession()
    ---@type table
    local state=assert(session.state)
    local UI=require "urhox-libs/UI"
    ---@type table
    local root=assert(UI.GetRoot(),"UI test adapter root required")
    assert(state.GetStatus().schema==3 and state.GetSnapshot().journal)
    for _,id in ipairs({"debugPanel","debugToggleButton","b2CheckButton","debugNextDayButton"}) do assert(not root:FindById(id),id) end
    assert(root:FindById("saveStatusLabel"):GetProps().visible==false)
    local save=require "core.SaveSystem"
    assert(save.Save("landscape_entry_bad",{unexpected=true},3))
    local loaded=state.Load("landscape_entry_bad"); assert(not loaded and not state.CanMutate())
    RefreshHeader()
    assert(root:FindById("playerSaveError"):GetProps().visible)
    root:FindById("playerSaveErrorClose"):GetProps().onClick()
    assert(not root:FindById("playerSaveError"):GetProps().visible and not state.CanMutate())
    assert(root:FindById("playerSaveRetry"):GetProps().visible)
    root:FindById("playerSaveRetry"):GetProps().onClick()
    assert(not state.CanMutate() and state.GetStatus().status=="corrupt","retry must reread the same damaged slot")
    print("[LandscapeEntry] PASS schema3, hidden debug tools, touch-close retains write lock; File/UI adapters only")
    return true
end
return T
