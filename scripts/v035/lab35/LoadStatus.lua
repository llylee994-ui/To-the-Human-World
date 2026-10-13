-- Visible before scene parsing; no retry/start controls and no business commands.
local M={}
local phases={read="读取场景文件",decode="解析场景",validateVertices="检查顶点",validateIndices="检查索引",
    validateTriangles="检查三角形",validateMaterials="检查材质",validateMeshes="检查模型",materials="载入材质",geometry="建立模型",
    readMesh="读取模型批次",decodeMesh="解析模型批次",meshComplete="模型批次已载入"}
function M.New(UI,onCancel)
    local title=UI.Label {id="fullLoadTitle",text="正在载入完整场景",fontSize=24,fontColor={252,235,209,255}}
    local detail=UI.Label {id="fullLoadDetail",text="准备中",fontSize=16,fontColor={239,220,192,255},whiteSpace="normal"}
    local cancel=UI.Button {id="fullLoadCancel",text="取消载入",width=140,height=44,onClick=function() if onCancel then onCancel() end end}
    local root=UI.Panel {id="fullLoadStatus",position="absolute",left=0,top=0,width="100%",height="100%",zIndex=4000,
        backgroundColor={49,39,32,250},alignItems="center",justifyContent="center",pointerEvents="box-only",onClick=function() end,
        children={UI.Panel {width="80%",maxWidth=760,padding=28,gap=18,children={title,detail,cancel}}}}
    local api={root=root}
    function api.Update(s)
        root:SetVisible(s.status~="complete")
        cancel:SetVisible(s.status~="failed" and s.status~="cancelled" and s.status~="warning")
        if s.status=="failed" then
            title:SetText("场景载入失败")
            detail:SetText((phases[s.phase] or s.phase or "准备").." · "..tostring(s.currentId or "").."\n"..tostring(s.error):sub(1,600))
        elseif s.status=="cancelled" then title:SetText("已取消载入");detail:SetText("没有启动游戏会话，也没有改动玩家存档。")
        elseif s.status=="warning" then
            title:SetText("场景已载入，校准尚未通过")
            detail:SetText(s.error or "本轮暂停交互，请查看投影校准记录。")
            root:SetStyle({backgroundColor={49,39,32,140}})
        else
            title:SetText("正在载入完整场景")
            detail:SetText((phases[s.phase] or s.phase or "准备").." "..tostring(s.done or 0).." / "..tostring(s.total or 0).."\n"..tostring(s.currentId or ""))
        end
    end
    return api
end
return M
