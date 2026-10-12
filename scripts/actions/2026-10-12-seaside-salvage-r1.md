# 海边场景与自动捕捞 r1

2026-10-12，用户确认海边构图稿与点击开始捕捞后自动下网收瓶，授权推进下一步。本批在原 main 工作区实施，保留既有未提交剧情、数据和工具修改；不提交、推送或远端构建。

## 结果

- 正式海边由分层图片绘制替换原功能文本页：纯海景背景、主页同一造型商船、漂流瓶、长柄网兜。固定 HUD 与底部操作区，继承入口 SafeAreaView，1920×1080 等比 contain。
- 网兜入口保留原 0.45 秒门洞推进。进入海边不收信；捕捞点击时重新查询门禁，Receive 成功保存后播放 2.4 秒下网、收瓶、近景展示，再打开真实阅读组件。
- 船与按钮均可开同一商店；关闭回到海边。无可收信/无次数不展示可捕捞瓶子，业务锁定与保存失败显示实际原因。
- 演出期间阻挡 HUD、船、重复捕捞与导航，只允许跳过。跳过不再次收信；读信保存失败保留阅读按钮。改变窗口、切后台、长帧停止演出，信已保存，可回主页抽屉阅读。从任何阅读入口成功读这封信都会清除前端待读状态。
- 动画控制器不调用业务；main、PlayModel、core、systems、data 和主页图层/热区未修改。本地其他修改仍保留。

## 素材与文件

Maker edit_image 拆背景、瓶和网，商船复用已有图片。原图、生成回执、远端 URL 与完整提示词保存在 assets/image/seaside-r1/generation-records.json，稳定运行副本与原来源 SHA-256 见 source-manifest.json。生成返回瓶/网为方形，运行使用实际比例，不按请求尺寸拉伸。未用程序修改素材像素。

- 新增 SeasideView.lua、SeasideManifest.lua、SalvageController.lua；AppView.lua 装配稳定页面和演出。
- tests/SalvageControllerTest.lua、SeasideFlowTest.lua：真实业务 + 显式 File/UI/时间/布局适配器。
- HomeEntryTest.lua 仅补真实收瓶演出等待，原业务断言保持；ZoomTestHost.lua 补海边控件的模拟坐标。
- SeasideEvidenceHost.lua、export_seaside_evidence.py 记录实际 Lua 绘制调用并离线重放，不是原生截图。UI 是简化示意；文件有 OFFLINE 标记。

## 验证

本轮测试先失败后实现：正式海边替换断言；输入树检查发现 ship layer 缺 visible；新增抽屉阅读中断收信断言发现未清除 receipt。定位后各自修正，未修改业务模块。

最终命令：

```powershell
python -X utf8 -B scripts/ui/landscape/tests/run_salvage_controller.py
python -X utf8 -B scripts/ui/landscape/tests/run_seaside_flow.py
python -X utf8 -B scripts/ui/landscape/tests/run_hit_feedback.py --home
python -X utf8 -B scripts/ui/landscape/tests/run_home_zoom.py
python -X utf8 -B scripts/ui/landscape/tests/prepare_seaside_manifest.py
python -X utf8 -B scripts/ui/landscape/tests/export_seaside_evidence.py
```

结果：控制器 2934、海边流程 89、主页 303、门洞推进 383 检查通过，合计 3709；故障日志为预期写失败注入。45 个离线关键帧覆盖 16:9、19.5:9、20:9、4:3 与 800×360，已查看演出总览和小屏画面。独立控制器与最终集成审查无明确待修问题。日志和画面见 docs/验证/evidence/seaside-r1。

Lua LSP 最终诊断：0 Error、27 Warning、8 Hint，另存证据。原生与离线验证范围分别记录如下，帧率、真实系统输入与手机没有由自动检查证明。

## 本地预览与待验

首次代码/素材批次后 preview status 显示 process_alive=false，保持停止。用户随后明确选择“启动本地预览”，已启动本地窗口并在各次修改后按规则刷新与读取日志。

真实引擎窗口的只读 SeasideNativeProbe 已验证海边 contain 布局、实际 Yoga 控件位置、引擎 UI 指针派发打开/关闭商店，以及前后玩家状态一致。未执行捕捞、购买或读信。原生截图保存为 docs/验证/evidence/seaside-r1/native-seaside-final.png（1450×815），已打开查看：构图完整，捕捞按钮从 186 加宽至 240 后文字完整。探针采用引擎 Graphics:TakeScreenShot 与相对 SavePNG；先复制临时截图再刷新。普通玩家入口的四个 DevChecks 开关均已恢复 false。

最终 session 3d560e43-6467-4174-8520-2556b0a3eb59 / reload 7 仍运行，日志显示 Game started successfully，无新 Lua 异常。CLI check 仍为 FAIL：Cube/Day/DaySpecularHDR.dds 缺失和 themis_x64.dll 加载失败两条既有引擎错误尚未解决，不宣称整体运行检查通过。preview-final-status/logs/check.json 保存了最后证据。完整捕捞演出的原生观感、系统鼠标与手机触控仍需人工试玩；状态和业务路径已通过 3709 项专项检查。

原生人工检查：点主页网兜进入正式海边；确认完整构图与关闭按钮；点船打开商店关闭回海边；开始捕捞下网收瓶后读信；另一天测试跳过、连续点击、切后台与返回抽屉；核对当天次数只扣一次，读信后还能剪词和接单。真实购买、捕捞与读信会保存玩家进度，请按自身试玩进度操作。手机刘海/Tap 胶囊、拇指触控、长文滚动仍需另验。

音效本轮未生成或接入，不影响已授权的图片与捕捞演出。完整游戏上线/主线案件/炼药正式近景不在本批范围。
