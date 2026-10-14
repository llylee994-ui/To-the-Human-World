# 商船倒影色调调整

用户指出倒影不匹配雾港海水。原主页/海边商船 PNG 哈希相同，倒影与船身烘焙为一张图。使用 image_gen 编辑独立新版本 merchant-ship-muted.png：降低金黄反光、亮度和饱和度，灰蓝色调中保留少量暖色，弱化外围与下缘。船身/帆仍保留夕阳暖光，布局、命中坐标和起伏不变，原素材保留。

输出来自 exec-5b56161a-f171-48c0-bcf9-5efab3d685cd.png；1319×1192 RGBA，alpha 0～255，与原图画布相同。SHA256 13220a898ea397b9381194d39573bc61f49e9b72929e01f6e20b56b4fba0d493。主页和海边 manifest 引用同一新版本。不用子代理、不提交或远端构建。

预览初始存活 session 649d3881-f4a7-41f3-a5b8-b608278f9494 / reload 3；按项目规则刷新存活会话、取原生截图检查，并在结束时恢复所有验收开关 false。

SceneProjection 73 项与 SeasideFlow 89 项通过，Lua LSP 0 Error。reload 4 原生 probe PASS：八个入口中心、动态商船命中、全区域背景、20:9 UI 区域与玩家进度未改变。已读取主页和海边实际 PNG，倒影金黄饱和与对比降低，保留少量浅暖色，海面衔接较原版柔和。截图及原始日志见 docs/验证/evidence/ship-reflection-r1；20:9 仍是 UI 区域，不是手机/OS 视口。

验收后关闭 DevChecks，刷新正常入口。官方 check 仍包含原来的环境贴图和 themis_x64.dll 错误，不声称整个运行环境通过。
