-- Deliberately no disk API or fallback. Independent per New() instance.
local S={slot="d3_lab_v035"}
function S.New()
    local files,audit={},{}
    local allowed={}
    for _,suffix in ipairs({".json","_a.json","_b.json","_a.commit","_b.commit"}) do allowed["save_"..S.slot..suffix]=true end
    local function check(operation,path)
        assert(allowed[path],"v035 storage rejects non-lab path "..tostring(path))
        audit[#audit+1]={operation=operation,path=path}
    end
    local s={}
    function s.exists(path) check("exists",path);return files[path]~=nil end
    function s.read(path) check("read",path);return files[path] end
    function s.write(path,raw) check("write",path);assert(type(raw)=="string");files[path]=raw;return true end
    function s.delete(path) check("delete",path);files[path]=nil;return true end
    function s.Audit() return require("core.StateUtil").Copy(audit) end
    function s.WriteCount() local n=0;for _,a in ipairs(audit) do if a.operation=="write" then n=n+1 end end;return n end
    return s
end
return S
