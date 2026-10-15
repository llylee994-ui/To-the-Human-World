# 托盘与记录书参考布局接入

用户确认以自己编辑的两张预览为视觉参考，效果达到即可，并要求看游戏内效果。沿用已授权的本地 Maker 窗口流程，不提交、不远端构建、不使用子代理。

参考：排版编辑器项目 revision 292（托盘 160、记录书 132），读取后冻结，接入不回写编辑器。运行时保存独立 Lua 素材清单，保持 PNG 原图及旋转、缩放和层级；520×1040 画布等比适配侧栏。托盘左侧、厚书右侧有意超出画布。布面、花草不接收输入。

托盘：右缘分类签，真实词卡按两列排布并可滚动，下缘花束保留留白；无词卡时显示说明。记录书：左缘索引、右上薰衣草、右下大花与干草；标题和正文避开花草，详情继续读取已保存的分支原文。沿用深褐文楷，正文 16 / 1.6 行距。

计划：
- [x] 更新裁切、比例、文字区域与真实内容回归断言；红阶段在缺少 bookCloth 时失败。
- [x] 导出静态素材清单，接入两侧面板及索引/分类交互。
- [x] 运行相关 Lua 回归与 LSP，检查本地预览。
- [ ] 游戏内图像、点击与正文滚动验收：受 Maker 冷启动预载阻塞，尚未执行到项目脚本。
- [x] 关闭开发检查，保留正常本地预览窗口；没有完成画面验收，不交付伪造截图。

业务状态、剧情、存档与编辑器布局不改；验收用内存夹具与玩家存档隔离。

## 验证记录

WordTrayTest 64、JournalBookTest 69、HomeHudTest 52 通过；编辑器存储/HTTP 测试 17 通过。主要面板、几何、素材清单及新增原生验收脚本的 LSP Error 为 0。旧 NativeProbe.lua 仍报告 wordTrayProbe 字段的缓存诊断（本轮 DevChecks 已显式声明 false），不宣称全工作区零错误。git diff --check 通过。

扩大回归时 HomeEntryTest 的业务导航、历史查询、重置与发货部分通过，几何部分报既有主场景热点重叠 74 点；用 HEAD 中未改动的 LayoutGeometry / LayoutManifest 复现相同结果。没有为通过检查而改动主场景热点。

新增 PanelReferenceNativeProbe：只在显式开发开关打开时，使用内存 SaveSystem 产生真实词卡和真实 schema-3 分支记录，计划验收分类/词卡触摸、目录/保存正文、滚动、返回、关闭与玩家快照不变。本轮未成功运行到该脚本，不将它作为已通过证据；所有开发开关已恢复 false。

本地预览最初被 scripts/layout-editor/.local/panel-materials/.server.lock 的 Windows 字节锁阻止复制。修复编辑器互斥锁的位置，改到系统临时目录，锁名由数据目录散列得到；保留单实例互斥，并新增“持锁时可复制项目”的回归。重启已核对归属的编辑器进程后，revision 292 / 页面 160、132 未变。浏览器应急备份与数据库页面逐项相同，编辑器已恢复连接。

Maker session 0330f2fb-efaf-4151-93d4-027c4c7fc52f：reload 0、1 均长时间停在启动资源加载页。reload 1 引擎资源包耗时 263256ms，随后停在 LoadPreloadResources（221 文件 / 31.7MB），截至 12:56 还没有项目启动日志。实际窗口 loading-window.png / current-window-r1.png 已读取，仅是 Maker 加载页。新厚书的本地资产 URL 返回 HTTP 200、2471891 bytes、0.031 秒。最终 reload 2 为普通入口，PID 20060，process_alive=true；check 仍为 FAIL，包含既有 Cube/Day/DaySpecularHDR.dds 缺失和 themis_x64.dll 错误；尚在冷启动下载，无法判断接入后的视觉效果。

现场证据保存在 .tmp/panel-layout-reference；未提交、未推送、未远端构建，未修改用户排版、剧情或存档。

## 后续本地预览

用户再次要求“本地预览”后，检查发现 reload 2 / PID 20060 仍在运行，且已于 13:06:06 输出 Game started successfully 与项目启动完成日志。复用现有窗口，未再次重启冷加载。实际窗口截图 .tmp/panel-layout-reference/local-preview-current.png 已读取，确认主场景进入游戏。PostMessage 两次只读导航尝试未使记录书打开，不把它当成点击或记录书画面通过的证据。记录书/托盘实际界面与正文滚动仍待验收；check 仍包含原有两条引擎错误，未宣称整体检查全绿。
