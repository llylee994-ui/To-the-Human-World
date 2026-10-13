local B={}
-- Literal asset paths intentionally allow the official preparation scanner to resolve them.
local paths={
 wood={'Textures/LabArt/wood.png','Textures/LabArt/wood-normal.png'},
 copper={'Textures/LabArt/copper.png','Textures/LabArt/copper-normal.png'},
 plaster={'Textures/LabArt/plaster.png','Textures/LabArt/plaster-normal.png'},
 linen={'Textures/LabArt/linen.png','Textures/LabArt/linen-normal.png'},
 paper={'Textures/LabArt/paper.png','Textures/LabArt/paper-normal.png'},
 book={'Textures/LabArt/book.png','Textures/LabArt/book-normal.png'},
 leaf={'Textures/LabArt/leaf.png','Textures/LabArt/leaf-normal.png'},
 sea={'Textures/LabArt/sea.png','Textures/LabArt/sea-normal.png'},
 ceramic={'Textures/LabArt/ceramic.png','Textures/LabArt/ceramic-normal.png'},
 rug={'Textures/LabArt/rug.png','Textures/LabArt/rug-normal.png'},
 botany={'Textures/LabArt/botany.png','Textures/LabArt/paper-normal.png'},
}
function B.New()
 local result={}
 for name,p in pairs(paths) do
  local diffuse=assert(cache:GetResource('Texture2D',p[1]),p[1]);diffuse:SetSRGB(true)
  local normal=assert(cache:GetResource('Texture2D',p[2]),p[2]);normal:SetSRGB(false)
  result[name]={diffuse=diffuse,normal=normal}
 end
 return result
end
return B
