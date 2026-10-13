-- Host seam, not an auto-starting entry. Requires actual imported scene data.
local I={}
function I.New(options)
    assert(options and options.scene and options.sceneData and options.camera and options.cameraNode,
        "actual scene data and native scene/camera required; no old-scene fallback")
    assert(options.navigation and options.occluded and options.hintOccluded,"navigation and occlusion drivers required")
    local native=require "lab35.NativeGeometry"
    local imported=options.imported or require("lab35.MeshLoader").Load(options.sceneData,native.New(options.scene,options.resourcePrefix,options))
    local bundle=require("lab35.Bootstrap").New()
    local controller=require("lab35.Controller").New(bundle,options.navigation)
    controller.SetAnchors(imported.prepared.anchors)
    local picker=require("lab35.Picking").New(imported.prepared,options.occluded)
    local view=require("lab35.AppView").New(bundle.session,bundle.content,nil,{
        model=bundle.model,bind=controller.Bind,
        homeFactory=function()
            return require("lab35.HomeView").New(controller,{
                picker=picker,hintOccluded=options.hintOccluded,
                ray=function(x,y)
                    local ray=options.camera:GetScreenRay(x,y)
                    return {ray.origin.x,ray.origin.y,ray.origin.z},{ray.direction.x,ray.direction.y,ray.direction.z}
                end,
                project=function(point,rect) return native.Project(options.camera,options.cameraNode,point,rect) end})
        end})
    return {bundle=bundle,controller=controller,view=view,imported=imported,picker=picker}
end
return I
