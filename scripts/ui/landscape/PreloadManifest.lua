-- 启动资源分组清单。只列正式运行引用；复用路径在组内去重，跨组共享由加载器统一去重。
local U=require "core.StateUtil"
local Layout=require "ui.landscape.LayoutManifest"
local Panels=require "ui.landscape.PanelLayoutManifest"
local Drawer=require "ui.landscape.LetterDrawerLayout"
local Seaside=require "ui.landscape.SeasideManifest"
local Sea=require "ui.landscape.SeaArt"
local Audio=require "ui.landscape.AudioCatalog"
local Decorations=require "data.wish_decorations"

local M={}
local order={"bootstrap","core","seaside","brew","endings"}
local groups={}
local function group(name)
    groups[name]=groups[name] or {seen={},entries={}}
    return groups[name]
end
local function add(name,path,typeName,loop)
    if type(path)~="string" or path=="" then return end
    local g=group(name)
    if g.seen[path] then return end
    g.seen[path]=true
    g.entries[#g.entries+1]={path=path,type=typeName or "Image",loop=loop}
end
local function addImage(name,path) add(name,path,"Image",nil) end
local function addFont(name,path) add(name,path,"Font",nil) end
local function addBgm(name,id) add(name,Audio.BgmPath(id),"Sound",true) end
local function addEffect(name,id) add(name,Audio.EffectPath(id),"Sound",false) end
local function addManifestLayers(name,manifest)
    for _,layer in ipairs(manifest.layers or {}) do addImage(name,layer.path) end
end
local function addPanelPages(name,manifest)
    for _,page in pairs(manifest.pages or {}) do
        for _,layer in ipairs(page.layers or {}) do addImage(name,layer.path) end
    end
end
local function addDrawer(name,manifest)
    for _,layer in pairs(manifest.layers or {}) do addImage(name,layer.path) end
end

-- bootstrap：加载页本身可见所需，engine 启动预下载。
addImage("bootstrap","image/loading-r1/harbor-small-v01.jpg")
addFont("bootstrap","fonts/HarborHand-Regular.ttf")
addFont("bootstrap","fonts/HarborHand-Medium.ttf")

-- core：标题、药铺、通用纸面与全部交互音效。
addFont("core","fonts/HarborHand-Regular.ttf")
addFont("core","fonts/HarborHand-Medium.ttf")
addImage("core",Sea.background)
addImage("core",Sea.homeForeground)
addManifestLayers("core",Layout)
addPanelPages("core",Panels)
addDrawer("core",Drawer)
addImage("core","image/letter-drawer-v01/界面_来信抽屉_信纸_已读_透明_v01.png")
addImage("core","image/letter-drawer-v01/界面_来信抽屉_信纸_未读_透明_v01.png")
addImage("core","image/letter-drawer-v01/界面_来信抽屉_滚动条_轨道_透明_v01.png")
addImage("core","image/letter-drawer-v01/界面_来信抽屉_滚动条_滑块_透明_v01.png")
addImage("core","image/letter-drawer-v01/界面_来信抽屉_装饰_绳捆包裹_透明_v01.png")
addImage("core","image/title-screen-r1/shop-doorway-soft.png")
addImage("core","image/calendar-r1/blank.png")
addImage("core","image/story-result/button-skins-v01.png")
addImage("core","image/letter-scissors.png")
addImage("core","image/ui-controls/embroidered-arrow-left-v01.png")
addImage("core","image/界面_深木牌_透明_v01_20261013070534.png")
addImage("core","image/界面_柔边纸面_透明_v01_20261013070534.png")
addBgm("core","hearth")
for _,entry in ipairs(Audio.EffectEntries()) do addEffect("core",entry.id) end

-- seaside：海边、商店与海边音乐。
addImage("seaside",Sea.background)
addImage("seaside",Sea.dockForeground)
addImage("seaside",Seaside.bottle.path)
addImage("seaside",Seaside.net.path)
addImage("seaside",Seaside.ship.path)
addImage("seaside","image/商队木柜台_背景_v01_20261013032602.png")
addImage("seaside","image/原料_海盐_透明_v01_20261013032602.png")
addImage("seaside","image/原料_夜露_透明_v01_20261013032602.png")
addImage("seaside","image/原料_灰烬草_透明_v01_20261013032602.png")
addImage("seaside","image/原料_干花瓣_透明_v01_20261013032602.png")
addImage("seaside","image/shop-art-r2/tablecloth-chair-lamp.png")
addImage("seaside","image/家具_书架_透明_v01_20261013070534.png")
addImage("seaside","image/商品_人间单程船票_透明_v01_20261013040555.png")
addBgm("seaside","seaside")

-- brew：药炉、投料与炼药音乐。
addImage("brew","image/brew-topdown/cauldron-v01.png")
addImage("brew","image/brew-topdown/four-cell-tray-v01.png")
addImage("brew","image/原料_海盐_透明_v01_20261013032602.png")
addImage("brew","image/原料_夜露_透明_v01_20261013032602.png")
addImage("brew","image/原料_灰烬草_透明_v01_20261013032602.png")
addImage("brew","image/原料_干花瓣_透明_v01_20261013032602.png")
addBgm("brew","brewing")

-- endings：出走背景、愿望纸面与拼贴装饰；海边瓶子和海面复用 core/seaside。
addImage("endings",Sea.background)
addImage("endings","image/departure-ending-r1/background.png")
addImage("endings","image/wish-collage-r1/table-background.png")
addImage("endings","image/wish-collage-r1/soft-scrollwork-letter-paper.png")
addImage("endings",Seaside.bottle.path)
for _,row in ipairs(Decorations.list) do addImage("endings",row.path) end
addBgm("endings","seaside")
addBgm("endings","traveler")
addBgm("endings","wish")

function M.Groups() return U.Copy(order) end
function M.Group(name)
    local g=groups[name]
    return g and U.Copy(g.entries) or {}
end
function M.CountPath(name,path)
    local count=0
    for _,entry in ipairs(groups[name] and groups[name].entries or {}) do if entry.path==path then count=count+1 end end
    return count
end
function M.HasPath(name,path) return M.CountPath(name,path)>0 end
function M.AllEntries()
    local rows,seen={},{}
    for _,name in ipairs(order) do
        for _,entry in ipairs(groups[name] and groups[name].entries or {}) do
            if not seen[entry.path] then seen[entry.path]=true;rows[#rows+1]=U.Copy(entry) end
        end
    end
    return rows
end
return M
