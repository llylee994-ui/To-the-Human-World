-- Deterministic, runtime-generated texture pixels. No borrowed reference pixels.
-- PBRDiff requires an actual diffuse texture; Image/Texture2D use documented API.
local T={}
local function noise(x,y) return (math.sin(x*127.1+y*311.7)*43758.5453)%1 end
function T.New()
    local textures={}
    for _,kind in ipairs({'wood','copper','plaster','linen'}) do
        local size=128; local img=Image(); img:SetSize(size,size,4)
        for y=0,size-1 do for x=0,size-1 do
            local u,v=x/size,y/size; local n=noise(x,y)-0.5; local r,g,b
            if kind=='wood' then
                local warp=u+0.013*math.sin(v*9)+0.009*math.sin(v*21+u*17)
                local grain=math.sin(warp*250+math.sin(v*9)*0.6)*0.035+math.sin(warp*720)*0.019
                local knot=math.sin(math.sqrt((u-0.34)^2*350+(v-0.60)^2*35)*15)*0.024*math.exp(-((u-0.34)^2*50+(v-0.60)^2*18))
                r=0.60+grain+knot+n*0.028; g=0.36+grain*0.75+knot+n*0.02; b=0.18+grain*0.45+knot*0.5+n*0.018
            elseif kind=='copper' then
                local cx,cy=u*23,v*23; local hammer=math.sin(cx*6.28+math.floor(cy)*1.9)*math.sin(cy*6.28)*0.045
                local tarnish=math.sin(u*19+math.sin(v*13))*math.sin(v*17)*0.04
                r=0.61+hammer+tarnish+n*0.04; g=0.32+hammer*0.6+tarnish+n*0.025; b=0.16+hammer*0.5+tarnish*0.6+n*0.02
            elseif kind=='plaster' then
                local age=math.sin(u*21)*math.sin(v*16)*0.019+n*0.025
                r=0.78+age; g=0.70+age; b=0.57+age
            else
                local weave=((x%3==0) and -0.025 or 0.01)+((y%3==0) and -0.025 or 0.01)+n*0.018
                r=0.85+weave; g=0.79+weave; b=0.65+weave
            end
            img:SetPixel(x,y,Color(r,g,b,1))
        end end
        local tex=Texture2D(); tex:SetSRGB(true); assert(tex:SetData(img,false),'Could not upload '..kind..' texture')
        textures[kind]=tex
    end
    return textures
end
return T
