-- Presentation only. A complete veil precedes mounting the saved story underneath it.
---@class BrewSmokePresentation
---@field coverAt number
---@field brewDuration number
---@field revealDuration number
---@field Cover fun(elapsed:number):number
---@field Render fun(vg:any,viewport:table,origin:table,elapsed:number,opacity:number?)
---@type BrewSmokePresentation
local S={coverAt=.7,brewDuration=1.65,revealDuration=.65}
local function clamp(t) return math.max(0,math.min(1,t)) end
local function ease(t) t=clamp(t);return t*t*(3-2*t) end
function S.Cover(elapsed)
    if elapsed>=S.coverAt then return 1 end
    return ease((elapsed-.2)/.5)
end
function S.Render(vg,viewport,origin,elapsed,opacity)
    local alpha=clamp(opacity or 1);if alpha<=0 then return end
    local w,h=viewport.w,viewport.h
    local fill=S.Cover(elapsed)
    -- The quiet solid core guarantees no uncovered corner, even on ultrawide windows.
    nvgBeginPath(vg);nvgRect(vg,0,0,w,h)
    nvgFillColor(vg,nvgRGBA(237,230,209,math.floor(255*fill*alpha)));nvgFill(vg)
    local spread=ease(elapsed/.8)
    local diagonal=math.sqrt(w*w+h*h)
    for i=1,18 do
        local a=i*2.39996
        local reach=(.15+(i%5)*.17)*spread
        local x=origin.x+math.cos(a)*w*reach+math.sin(elapsed*1.3+i)*14
        local y=origin.y+math.sin(a)*h*reach-h*.16*spread
        local radius=(36+diagonal*.19*spread)*(0.7+(i%4)*.13)
        local opacityHere=math.floor((155+(i%3)*25)*alpha*math.min(1,elapsed*8))
        nvgBeginPath(vg);nvgCircle(vg,x,y,radius)
        nvgFillPaint(vg,nvgRadialGradient(vg,x,y,radius*.38,radius,
            nvgRGBA(207,196,211,math.floor(opacityHere*.6)),nvgRGBA(216,207,215,0)))
        nvgFill(vg)
        nvgBeginPath(vg);nvgCircle(vg,x-radius*.08,y-radius*.12,radius*.85)
        nvgFillPaint(vg,nvgRadialGradient(vg,x-radius*.08,y-radius*.12,radius*.12,radius*.85,
            nvgRGBA(254,249,234,opacityHere),nvgRGBA(244,238,224,0)))
        nvgFill(vg)
    end
    -- A few gold sparks keep the full-screen cloud alive during the short hold.
    for i=1,26 do
        local p=(elapsed*.24+i*.137)%1
        local x=((i*.618)%1)*w;local y=h*(1-p)
        local glow=math.sin(p*math.pi)*alpha*spread
        nvgBeginPath(vg);nvgCircle(vg,x,y,1.3+(i%3)*.5)
        nvgFillColor(vg,nvgRGBA(178,133,54,math.floor(150*glow)));nvgFill(vg)
        if i%4==0 then
            nvgBeginPath(vg);nvgMoveTo(vg,x-4,y);nvgLineTo(vg,x+4,y);nvgMoveTo(vg,x,y-4);nvgLineTo(vg,x,y+4)
            nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(191,148,64,math.floor(135*glow)));nvgStroke(vg)
        end
    end
end
return S
