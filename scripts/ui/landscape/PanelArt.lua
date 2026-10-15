-- Frozen 520x1040 material-editor canvas, projected into UI base pixels.
-- Cropped objects stay cropped; UI owns frame and DPR transforms.
local UI=require "urhox-libs/UI"
local manifest=require "ui.landscape.PanelLayoutManifest"
local A={}
function A.Page(name) return manifest.pages["panel-"..name] end
function A.Layer(page,id)
    for _,layer in ipairs(page.layers) do if layer.id==id then return layer end end
    error("missing panel reference layer: "..id)
end
function A.Asset(page,id)
    for _,layer in ipairs(page.layers) do if layer.assetId==id then return layer end end
    error("missing panel reference asset: "..id)
end
function A.Fit(width,height)
    local s=math.min(width/520,height/1040)
    return {x=(width-520*s)/2,y=(height-1040*s)/2,scale=s}
end
function A.Rect(fit,x,y,w,h)
    return {x=fit.x+x*fit.scale,y=fit.y+y*fit.scale,w=w*fit.scale,h=h*fit.scale}
end
function A.Project(fit,layer)
    local r=A.Rect(fit,layer.x-layer.width/2,layer.y-layer.height/2,layer.width,layer.height)
    r.rotate=layer.rotation;r.path=layer.path
    return r
end
function A.Style(r)
    return {position="absolute",left=r.x,top=r.y,width=r.w,height=r.h,rotate=r.rotate or 0}
end
function A.Image(parent,id,r)
    local props=A.Style(r)
    props.id=id;props.backgroundImage=r.path;props.backgroundFit="fill";props.pointerEvents="none"
    local node=UI.Panel(props);parent:AddChild(node);return node
end
return A
