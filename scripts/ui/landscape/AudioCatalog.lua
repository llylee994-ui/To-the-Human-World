-- 公共音频清单：SceneMusic、ObjectSounds 与启动预加载共用同一份路径。
local U=require "core.StateUtil"
local A={}
local bgm={
    {id="hearth",path="audio/bgm/hearth-warmth-loop.wav",type="Sound",loop=true},
    {id="seaside",path="audio/bgm/seaside-path-loop.wav",type="Sound",loop=true},
    {id="brewing",path="audio/bgm/brewing-mystery-loop.wav",type="Sound",loop=true},
}
local effects={
    {id="word_cut",path="audio/sfx/objects/water-and-scissors-v2/word_cut.wav",type="Sound",loop=false},
    {id="word_select",path="audio/sfx/objects/word_select.wav",type="Sound",loop=false},
    {id="ingredient_select",path="audio/sfx/objects/ingredient_select.wav",type="Sound",loop=false},
    {id="ingredient_add",path="audio/sfx/objects/water-and-scissors-v2/ingredient_add.wav",type="Sound",loop=false},
    {id="ingredient_remove",path="audio/sfx/objects/water-and-scissors-v2/ingredient_remove.wav",type="Sound",loop=false},
    {id="word_add",path="audio/sfx/objects/word_add.wav",type="Sound",loop=false},
    {id="word_remove",path="audio/sfx/objects/word_remove.wav",type="Sound",loop=false},
    {id="word_withdraw",path="audio/sfx/objects/word_withdraw.wav",type="Sound",loop=false},
    {id="draft_clear",path="audio/sfx/objects/draft_clear.wav",type="Sound",loop=false},
    {id="net_pick",path="audio/sfx/objects/net_pick.wav",type="Sound",loop=false},
    {id="stove_touch",path="audio/sfx/objects/stove_touch.wav",type="Sound",loop=false},
    {id="bottle_lift",path="audio/sfx/objects/bottle_lift.wav",type="Sound",loop=false},
    {id="drawer_open",path="audio/sfx/objects/drawer_open.wav",type="Sound",loop=false},
    {id="drawer_close",path="audio/sfx/objects/drawer_close.wav",type="Sound",loop=false},
    {id="letter_pick",path="audio/sfx/objects/letter_pick.wav",type="Sound",loop=false},
    {id="tray_open",path="audio/sfx/objects/tray_open.wav",type="Sound",loop=false},
    {id="tray_close",path="audio/sfx/objects/tray_close.wav",type="Sound",loop=false},
    {id="recipe_book_open",path="audio/sfx/objects/recipe_book_open.wav",type="Sound",loop=false},
    {id="recipe_book_close",path="audio/sfx/objects/recipe_book_close.wav",type="Sound",loop=false},
    {id="ui_click_01",path="audio/sfx/ui/ui_click_01.wav",type="Sound",loop=false},
    {id="ui_confirm",path="audio/sfx/ui/ui_confirm.wav",type="Sound",loop=false},
}
local function find(list,id)
    for _,entry in ipairs(list) do if entry.id==id then return entry end end
end
function A.BgmEntries() return U.Copy(bgm) end
function A.EffectEntries() return U.Copy(effects) end
function A.BgmPath(id)
    local entry=find(bgm,id)
    return entry and entry.path or nil
end
function A.EffectPath(id)
    local entry=find(effects,id)
    return entry and entry.path or nil
end
function A.EffectPaths()
    local paths={}
    for _,entry in ipairs(effects) do paths[entry.id]=entry.path end
    return paths
end
function A.AllEntries()
    local all=U.Copy(bgm)
    for _,entry in ipairs(effects) do all[#all+1]=U.Copy(entry) end
    return all
end
return A
