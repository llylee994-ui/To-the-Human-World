-- All pixel inputs use the UI's base coordinate system; SDK menu is normalized.
local M = {}
local function finite(n)
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function validMenu(rect)
    if type(rect)~="table" then return false end
    for _,key in ipairs({"left","top","right","bottom"}) do if not finite(rect[key]) then return false end end
    return rect.left>=0 and rect.top>=0 and rect.right<=1 and rect.bottom<=1
        and rect.left<rect.right and rect.top<rect.bottom
end
-- Host properties may be exposed via tolua's _G.__index. Normal global access
-- is essential here; rawget(_G,"sdk") can silently discard the host bridge.
function M.ReadHost(ui,bounds)
    local w,h=bounds.w,bounds.h
    if ui.GetViewportSize then w,h=ui.GetViewportSize() end
    local safe={left=0,top=0,right=0,bottom=0}
    local reported=ui.GetSafeAreaInsets and ui.GetSafeAreaInsets()
    for key in pairs(safe) do
        local n=reported and reported[key]
        if finite(n) then safe[key]=math.max(0,n) end
    end
    local hostSdk=sdk --[[@as {GetNativeExitMenuRect?: fun(self:table):table|nil}?]]
    local menu=hostSdk and hostSdk.GetNativeExitMenuRect and hostSdk:GetNativeExitMenuRect() or nil
    local platform=GetPlatform and GetPlatform() or ""
    local mobile=platform=="Android" or platform=="iOS" or platform=="HarmonyOS"
    -- Embedded Web on a phone may not have delivered its menu message yet.
    if platform=="Web" then
        local dpr=graphics and graphics.GetDPR and graphics:GetDPR() or 1
        ---@type number
        local ph=graphics and graphics.height or h
        mobile=safe.left>0 or safe.right>0 or ph/math.max(1,dpr)<600
    end
    if not validMenu(menu) then
        menu=nil
        if mobile and w>0 and h>0 then
            local right=math.max(0,w-safe.right)
            menu={left=math.max(0,right-144)/w,right=right/w,
                top=math.min(h-1,safe.top+8)/h,bottom=math.min(h,safe.top+80)/h}
        end
    end
    return {w=w,h=h},safe,menu
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
    if right<=bounds.x or left>=bounds.x+bounds.w or bottom<=bounds.y or top>=bounds.y+bounds.h then return result end
    result.right=math.max(12,bounds.x+bounds.w-left+12)
    requiredWidth=finite(requiredWidth) and math.max(0,requiredWidth) or 0
    if bounds.w-result.right<requiredWidth then
        result.right=12
        result.top=math.max(0,bottom-bounds.y+8)
    end
    return result
end
function M.SidePanelTop(viewport,safe,menu)
    local top=safe.top+12
    if validMenu(menu) then top=math.max(top,menu.bottom*viewport.h+12) end
    return top
end
return M
