-- This adapter has no File/io/fileSystem fallback, including on errors.
local M={}
function M.New(slot)
    assert(slot=="d3_lab_r3", "Only the lab slot is permitted")
    local files, audit={},{}
    local allowed={}
    for _,suffix in ipairs({".json","_a.json","_b.json","_a.commit","_b.commit"}) do allowed["save_"..slot..suffix]=true end
    local function check(op,path)
        assert(allowed[path],"Storage path outside lab slot: "..tostring(path))
        audit[#audit+1]={operation=op,path=path}
    end
    local storage={}
    function storage.exists(path) check("exists",path); return files[path]~=nil end
    function storage.read(path) check("read",path); return files[path] end
    function storage.write(path,raw) check("write",path); assert(type(raw)=="string"); files[path]=raw; return true end
    function storage.delete(path) check("delete",path); files[path]=nil; return true end
    function storage.GetAudit() return require("core.StateUtil").Copy(audit) end
    function storage.GetWriteCount()
        local n=0; for _,entry in ipairs(audit) do if entry.operation=="write" then n=n+1 end end; return n
    end
    return storage
end
return M
