-- UI base pixels; side drawer visibility never changes center geometry.
local L={}
---@class BrewDropRect
---@field x number
---@field y number
---@field w number
---@field h number
---@field kind string
---@field available boolean
function L.Compute(w,h,safe,auxCount,ingredientCount)
    safe=safe or {left=0,right=0,top=0,bottom=0}
    local usable=w-safe.left-safe.right
    local side=math.floor(usable*.26)
    local x=side+8
    local width=math.max(0,w-safe.right-side-8-x)
    local compact=h-safe.top-safe.bottom<620
    local top=safe.top+(compact and 56 or 64)
    local wishH=compact and 48 or 64
    local shelfH=compact and 88 or 136
    local recipeH=compact and 88 or 116
    local controlsY=h-safe.bottom-56
    local shelfY=controlsY-6-shelfH
    local summaryY=shelfY-6-recipeH
    local potTop=top+wishH+4
    local potH=math.min(width*.85/(1255/1017),math.max(44,summaryY-potTop-4))
    local potW=potH*(1255/1017)
    local pot={x=x+(width-potW)/2,y=potTop,w=potW,h=potH}
    -- Invisible generous mouth bounds; never overlap the letter, slots or drawers.
    local drop={x=pot.x+pot.w*.12,y=pot.y+pot.h*.04,w=pot.w*.76,h=pot.h*.70,
        landingX=pot.x+pot.w*.50,landingY=pot.y+pot.h*.40}
    ---@type BrewDropRect[]
    local slots={}
    local n=1+(auxCount or 2)+(ingredientCount or 2)
    local gap=6;local slotW=math.max(0,(width-24-(n-1)*gap)/n)
    for i=1,n do
        slots[i]={x=x+12+(i-1)*(slotW+gap),y=summaryY+25,w=slotW,h=recipeH-49,
            kind=i<=1+(auxCount or 2) and "word" or "ingredient",available=true}
    end
    return {center={x=x,y=top,w=width,h=controlsY+44-top},
        wish={x=x,y=top,w=width,h=wishH},pot=pot,drop=drop,slots=slots,
        wishText={x=x+16,y=top+(compact and 2 or 8),w=math.max(0,width-164),h=wishH-(compact and 4 or 16)},
        wishButton={x=x+width-132,y=top+(wishH-44)/2,w=116,h=44},
        summary={x=x,y=summaryY,w=width,h=recipeH},shelf={x=x,y=shelfY,w=width,h=shelfH},
        controls={x=x,y=controlsY,w=width,h=48},compact=compact}
end
function L.Contains(r,x,y) return r and x>=r.x and y>=r.y and x<=r.x+r.w and y<=r.y+r.h end
function L.Target(layout,item,x,y)
    if L.Contains(layout.drop,x,y) then return layout.drop end
    for _,r in ipairs(layout.slots) do
        if r.available and r.kind==item.kind and L.Contains(r,x,y) then return r end
    end
    return false
end
return L
