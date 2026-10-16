-- One stitched left-arrow pattern, mirrored for the other cloth edge.
local UI=require "urhox-libs/UI"
local A={}
function A.Points(direction)
    local sign=direction=="right" and -1 or 1
    local out={}
    for _,p in ipairs({{-23,0},{-6,-14},{-6,-6},{23,-6},{23,6},{-6,6},{-6,14}}) do
        out[#out+1]={x=p[1]*sign,y=p[2]}
    end
    return out
end
function A.New(props)
    local p={text="",width=68,height=48,minWidth=64,minHeight=44,padding=0,flexShrink=0,zIndex=20,
        backgroundColor={0,0,0,0},hoverBackgroundColor={0,0,0,0},pressedBackgroundColor={0,0,0,0},
        variantBackgroundGradient={},variantHoverBackgroundGradient={},variantPressedBackgroundGradient={},
        borderWidth=0,hoverBorderWidth=0,pressedBorderWidth=0,borderRadius=0,boxShadow=false,glowShadow={}}
    for key,v in pairs(props or {}) do p[key]=v end
    local b=UI.Button(p)
    local points=A.Points(p.arrowDirection)
    function b:RenderFullBackground(vg)
        local r=self:GetAbsoluteLayout()
        local x,y=r.x+r.w/2,r.y+r.h/2+(self.state and self.state.pressed and 1.5 or 0)
        local scale=math.min(r.w/64,r.h/44)
        local sign=self.props.arrowDirection=="right" and -1 or 1
        local function at(px,py) return x+px*scale,y+py*scale end
        local function path(dy)
            nvgBeginPath(vg)
            for i,q in ipairs(points) do
                local xx,yy=at(q.x,q.y+(dy or 0))
                if i==1 then nvgMoveTo(vg,xx,yy) else nvgLineTo(vg,xx,yy) end
            end
            nvgClosePath(vg)
        end
        path(1.7);nvgFillColor(vg,nvgRGBA(80,70,40,90));nvgFill(vg)
        path();nvgFillColor(vg,nvgRGBA(186,181,123,200));nvgFill(vg)
        -- Dense satin stitches follow the arrow's changing width. Batch each
        -- thread color into one path to keep this inexpensive on phones.
        for pass=1,2 do
            nvgBeginPath(vg)
            for px=-20,22,2.8 do
                local half=px<-6 and (px+23)*14/17 or 6
                local xx,yy=at((px-.5)*sign,-half+1+(pass==1 and 1 or 0))
                local tx,ty=at((px+.65)*sign,half-1+(pass==1 and 1 or 0))
                nvgMoveTo(vg,xx,yy);nvgLineTo(vg,tx,ty)
            end
            nvgStrokeWidth(vg,(pass==1 and 2.1 or .85)*scale)
            nvgStrokeColor(vg,pass==1 and nvgRGBA(110,120,73,240) or nvgRGBA(250,230,173,245));nvgStroke(vg)
        end
        -- Small running stitches form a raised cream border.
        for pass=1,2 do
            nvgBeginPath(vg)
            for i,a in ipairs(points) do
                local z=points[i%#points+1];local dx,dy=z.x-a.x,z.y-a.y
                local length=math.sqrt(dx*dx+dy*dy)
                for distance=0,length-1,4.8 do
                    local stop=math.min(distance+3.1,length)
                    local ax,ay=at(a.x+dx*distance/length,a.y+dy*distance/length+(pass==1 and 1 or 0))
                    local bx,by=at(a.x+dx*stop/length,a.y+dy*stop/length+(pass==1 and 1 or 0))
                    nvgMoveTo(vg,ax,ay);nvgLineTo(vg,bx,by)
                end
            end
            nvgStrokeWidth(vg,(pass==1 and 2.6 or 1.4)*scale)
            nvgStrokeColor(vg,pass==1 and nvgRGBA(112,92,52,170) or nvgRGBA(255,238,192,255));nvgStroke(vg)
        end
    end
    return b
end
return A
