-- Temporary explicit public-resource diagnostic. No business or file writes.
local P={}
function P.Run()
    for _,name in ipairs({"LightGroup/Dusk.xml","Cube/Day/DaySpecularHDR_QualityLow.xml","Cube/Dusk/DuskSpecularHDR_QualityLow.xml"}) do
        local xml=cache:GetResource("XMLFile",name,false)
        print("[D3-LAB resource-probe] "..cjson.encode({asset=name,loaded=xml~=nil}))
        if xml then
            for line in xml:ToString():gmatch("[^\r\n]+") do
                print("[D3-LAB resource-probe] "..cjson.encode({asset=name,xml_line=line}))
            end
        end
    end
    for _,name in ipairs({"Cube/Day/DaySpecularHDR_QualityLow.dds","Cube/Dusk/DuskSpecularHDR_QualityLow.dds"}) do
        local texture=cache:GetResource("TextureCube",name,false)
        print("[D3-LAB resource-probe] "..cjson.encode({asset=name,loaded=texture~=nil}))
    end
end
return P
