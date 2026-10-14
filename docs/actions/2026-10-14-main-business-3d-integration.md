# 3D 接入当前 main 业务与界面

## Status and situation
Completed — 功能接入、隔离回归及 Windows 初始画面检查完成；真实鼠标业务验收由用户继续。用户发现已启动的 3D 没有 main 的新功能，要求尝试合并 main 到当前分支。远端再次 fetch 后仍为 41cdaf3，已是当前 e3c9589 的祖先；历史无待合并提交，实际差距来自 3D 调用 scripts/v035 的旧业务副本。

唯一工作目录为当前克隆，分支 integration/3d-main-20261014。修改前工作区干净；关键文件已备份到忽略目录 .windows-runs/main-business-backup-*。不操作其他项目、真实玩家存档、远端 main/3d 或根目录 v035 历史测试。代理未关闭用户原试玩窗口。后续启动新版 PID 32548；只恢复其最小化状态并截图，不代替用户进行鼠标业务验收。

权威功能边界见 [前端接口手册](../../scripts/前端接入接口手册.md)。main 当前实现 ordinary-release-v2、schema 4、家具报价购买、新信纸裁词与辅料药效预览。船票启程、三结局及案件运行映射以 main 实际实现为限，不在本轮虚构补齐。

## Implementation measures
1. 使 3D Bootstrap 直接使用 scripts/core、data、systems、ui.PlayModel，保留独立 MemoryStorage，采用 main 当前 schema 4。
2. 在共享 ui/landscape/AppView 增加可选 3D 宿主适配，默认 2D 行为保留；3D 复用当前商店、阅读、词条、故事、海边与炼药界面，不再维护整份旧 AppView 副本。
3. 3D 保留透明房间、八个对象入口、原生镜头导航、炉旁界面和跨天单次确认；接入 main 字体与信纸演出生命周期。
4. 更新资源/依赖检查，加入实际 3D 装配下的业务与界面回归；同步当前运行说明。
5. 执行隔离 Lua 检查、main 原有相关测试、资源完整性检查和 Windows 预检。启动新版窗口作初始画面确认，交互验收仍由用户完成；代理不关闭用户原试玩窗口。

## Affected file tree
- scripts/v035/lab35/{Bootstrap,AppView,Panels,Controller,HomeView,FullSceneHost}.lua：3D 业务装配、宿主适配和字体注册。
- scripts/ui/landscape/AppView.lua：共享页面宿主可选依赖，默认 2D 路径不改变。
- tools/audit_v035_resources.py：检查当前共享业务依赖和原 3D 资源。
- tools/check_3d_main_integration.py、scripts/v035/lab35/tests/MainIntegration.lua：隔离业务与页面回归。
- README.md、docs/WINDOWS-RUN.md、docs/RUNBOOK.md、LAB_STATUS.md、deliverables/CURRENT.md：当前生效路径和验证边界。
- docs/evidence/main-business-3d-20261014/：本轮代码检查证据；.windows-runs/：本机启动与备份，不提交。

## Self-verification method
使用真实 Lua 业务模块及显式 UI/时钟替身，禁止磁盘存档 API。测试 schema 4 新开局、实例存档隔离、八个入口路由、捕捞阅读、裁词生命周期、商店选择与扣款、家具报价/重复购买、药效预览、导航和跨天幂等。运行 main 的相关现有业务/界面测试。保持 164 项 3D 资源哈希不变，检查完整 require 闭包、字体与共享界面资源。代码/替身测试与 Windows 画面、用户鼠标验收分开记录。

## Self-verification results
- `git fetch origin main` 后远端仍为 41cdaf3；`git merge --ff-only origin/main` 实际返回 `Already up to date.`。此次新增提交是功能装配适配，不伪造一个新的 Git 合并提交。
- `python -X utf8 tools/check_3d_main_integration.py`：通过 344 项断言，使用实际 3D Bootstrap、Controller、共享页面和真实 Lua 业务；UI/时钟/镜头为明确替身。覆盖八入口回调、独立内存槽、schema 4、捕捞后阅读、纸条裁取/取消演出、原料扣款、家具报价及重复购买、药效预览、返回主页与跨天单次确认。无 OS 鼠标操作。
- 共享默认 2D 路径的 8 套现有测试全部通过：ReleasePurchaseTest、ReleaseSaveTest、ReleaseFlowTest、ShopViewTest、LetterPresentationTest、SeasideFlowTest、HomeEntryTest、TravelTicketTest。命令统一为 `python -X utf8 tools/check_3d_main_integration.py --module <模块名>`；[逐套结果](../evidence/main-business-3d-20261014/upstream-tests.json)。旧 run_b1.py 会调用当前原生入口，故本轮直接使用独立 Lua 宿主运行测试模块，避免错误启动 3D 引擎。
- 本机没有可用 Lupa，已仅在当前仓库忽略目录 `.tmp/b1-python` 安装项目测试约定的 Lupa 2.6（1.7 MB wheel）；未修改系统 Python、游戏运行器或其他项目。
- 164 项 3D 资源 SHA256 通过，181 个入口可达 Lua 文件语法通过，35 项共享界面图片/字体直接引用均存在。旧 LayoutManifest 的平面图片字段只作为历史数据保留，Ids.lua 仅使用其 id/target/label；扩展图片扫描最初把这些未渲染字段当成加载资源，随后按实际消费字段分开记录，没有补回旧样片资源。
- `python -X utf8 tools/run_windows_game.py --check` 通过。官方 Windows Runtime 20260923-1717-bf3316f 实际启动新版 PID 32548，日志确认 shared main / ordinary-release-v2 / schema 4；场景加载 62.607 秒，100 模型、3,208,608 三角形。截图时窗口曾被最小化，核对 PID、路径后恢复同一窗口，已目视见 3D 房间及 main 样式炼药面板、中文字体、日期/金币和返回主页。
- 本机截图：`.windows-runs/20261014-153549-243742/main-business-home.png`（实际画面已在炼药页，文件名不表示首页验收）。本轮代理无游戏点击，截图不是八入口鼠标验收。采样报告工作集峰值约 1.78 GiB；后段约 20.05 秒 Update TimeStep 采样约 40.01 FPS，未控制前台/用户交互，不能当作 GPU 性能基准。[原生窗口记录](../evidence/main-business-3d-20261014/windows-window-check.json)。
- 仍有既有环境警告：Cube/Day/DaySpecularHDR.dds、Cube/Dusk/DuskSpecularHDR.xml、themis_x64.dll；本轮未改安全组件或美术。
- 现行操作文档已更新。scripts/main.lua、assets、urhox-libs、根目录 v035、其他项目与真实玩家存档未修改；没有复制大资源/运行器。main 未提供的船票启程、完整三结局和案件映射仍不声称已实现。
- 本轮作为本地独立功能提交保存；不推送远端。用户继续试玩当前“寄往人间 · 3D · main 接入测试”窗口，视觉与鼠标流程尚待用户验收。
