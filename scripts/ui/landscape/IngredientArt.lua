-- Frontend-only mapping. Shop, ingredient tray and later drop sprites share these PNGs.
local Merchandise=require "ui.landscape.MerchandiseArt"
local A={Background="image/商队木柜台_背景_v01_20261013032602.png"}
local paths={
    ing_sea_salt="image/原料_海盐_透明_v01_20261013032602.png",
    ing_night_dew="image/原料_夜露_透明_v01_20261013032602.png",
    ing_ashen_herb="image/原料_灰烬草_透明_v01_20261013032602.png",
    ing_dried_petal="image/原料_干花瓣_透明_v01_20261013032602.png",
}
function A.Get(ingredientId) return paths[ingredientId] end
function A.Panel(ingredientId,props)
    return Merchandise.Panel(ingredientId,props)
end
return A
