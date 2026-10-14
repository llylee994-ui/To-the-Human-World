-- Current main pages with the existing native 3D home/navigation adapter.
local A={}
function A.New(session,content,enabled,options)
    assert(options and options.model and options.homeFactory and options.bind,"3D host dependencies required")
    local adapter={model=options.model,homeFactory=options.homeFactory,nativeScene=true,
        panels=require "v035.lab35.Panels"}
    function adapter.bind(ctx)
        function ctx.LabSetNavigationBlocked(value)
            ctx.zoom.active=value;ctx.home.SetBlocked(value)
            assert(ctx.root:FindById("homeZoomBlocker")):SetVisible(value)
        end
        options.bind(ctx)
    end
    return require("ui.landscape.AppView").New(session,content,enabled,adapter)
end
return A
