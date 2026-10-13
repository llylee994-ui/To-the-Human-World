-- All pixel inputs use the UI's base coordinate system; SDK menu is normalized.
local M = {}
local function finite(n)
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
function M.Compute(bounds, viewport, menuRect, requiredWidth)
    local result={top=0,right=12}
    if type(bounds)~="table" or type(viewport)~="table" or type(menuRect)~="table" then return result end
    for _, key in ipairs({"x","y","w","h"}) do if not finite(bounds[key]) then return result end end
    if not finite(viewport.w) or not finite(viewport.h) or viewport.w<=0 or viewport.h<=0
        or bounds.w<=0 or bounds.h<=0 then return result end
    for _, key in ipairs({"left","top","right","bottom"}) do
        if not finite(menuRect[key]) then return result end
    end
    if menuRect.left<0 or menuRect.top<0 or menuRect.right>1 or menuRect.bottom>1
        or menuRect.left>=menuRect.right or menuRect.top>=menuRect.bottom then return result end
    local left, right=menuRect.left*viewport.w,menuRect.right*viewport.w
    local top, bottom=menuRect.top*viewport.h,menuRect.bottom*viewport.h
    if right<=bounds.x or left>=bounds.x+bounds.w or bottom<=bounds.y or top>=bounds.y+48 then return result end
    result.right=math.max(12,bounds.x+bounds.w-left+12)
    requiredWidth=finite(requiredWidth) and math.max(0,requiredWidth) or 0
    if bounds.w-result.right<requiredWidth then
        result.right=12
        result.top=math.max(0,bottom-bounds.y+8)
    end
    return result
end
return M
