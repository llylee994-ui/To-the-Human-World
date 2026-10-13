-- Bounded resource reads. A failed size/read check must still close the handle.
local R={}
function R.Read(openFile,path,limit)
    assert(type(openFile)=="function" and type(limit)=="number" and limit>0,"bounded resource reader arguments required")
    local file=assert(openFile(path),"missing package file: "..path)
    local ok,value=pcall(function()
        assert(file:IsOpen(),"package resource is not open: "..path)
        local size=file:GetSize()
        assert(type(size)=="number" and size==size and size>=0 and size<=limit,"package file exceeds pre-read byte limit: "..path)
        local text=file:ReadString()
        assert(type(text)=="string" and #text==size,"package file read length differs from declared size: "..path)
        return text
    end)
    local closed,closeError=pcall(function() file:Close() end)
    if not ok then
        error(tostring(value)..(closed and "" or "; close also failed: "..tostring(closeError)),0)
    end
    assert(closed,"package file close failed: "..tostring(closeError))
    return value
end
return R
