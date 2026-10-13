-- Frontend-only mapping. Shop, ingredient tray and later drop sprites share these PNGs.
local UI=require "urhox-libs/UI"
local A={Background="image/商队木柜台_背景_v01_20261013032602.png"}
local paths={
    ing_sea_salt="image/原料_海盐_透明_v01_20261013032602.png",
    ing_night_dew="image/原料_夜露_透明_v01_20261013032602.png",
    ing_ashen_herb="image/原料_灰烬草_透明_v01_20261013032602.png",
    ing_dried_petal="image/原料_干花瓣_透明_v01_20261013032602.png",
}
function A.Get(ingredientId) return paths[ingredientId] end
function A.Panel(ingredientId,props)
    local options={backgroundImage=A.Get(ingredientId),backgroundFit="contain",pointerEvents="none",flexShrink=0}
    for key,value in pairs(props or {}) do options[key]=value end
    return UI.Panel(options)
end
return A
