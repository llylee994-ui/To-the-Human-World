-- C-HOME-ENTRY-20261010 r3: one session/model, lifecycle compatible with main.
local AppView=require "ui.landscape.AppView"
local View={}
function View.New(session,content,enabled,options)
    return AppView.New(session,content,enabled,options)
end
return View
