-- Use pinned main's user-facing labels and route targets verbatim.
local ids={}
for _,object in ipairs(require("v035.ui.landscape.LayoutManifest").objects) do
    assert(not ids[object.id],"duplicate Home semantic id")
    ids[object.id]={target=object.target,label=object.label}
end
return ids
