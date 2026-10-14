# 正式海边场景与自动捕捞 Implementation Plan

> **For agentic workers:** 使用已确认方案连续实施，按任务进行代码与规格审查；项目 Maker 工作流优先，不创建分支、提交或推送。

**Goal:** 将海边功能页替换为已确认构图的分层场景，点击捕捞后展示下网、收瓶、展开真实来信。

**Architecture:** SeasideView 持有稳定 UI/绘制树，SalvageController 仅保存演出状态；AppView 协调既有查询与 model.Receive/Read。背景、船、瓶、网分层，绘制和命中共用 LayoutGeometry.Fit。

**Tech Stack:** UrhoX Lua 5.4、urhox-libs/UI、Maker 图片工具、现有 Python/Lupa 隔离测试。

## Global Constraints

- 1920×1080，安全区内等比 contain；不修改已确认主页或业务与数据文件。
- 所有真实收信只通过 model.Receive；成功保存后演出。查询、动画、导航不保存或发奖励。
- 不自动开启停止的预览；不远端构建、提交或推送。保留工作区其他改动。
- 生成素材在 assets/image；保留 Maker 原文件与映射，稳定运行副本放 seaside-r1。

## Task 1: 素材与来源

Files: assets/image/seaside-r1/{background,bottle,net,merchant-ship}.png, source-manifest.json。

- [x] Maker edit_image 从确认稿移除船/瓶/网，另生成透明瓶和网。
- [x] 查看三张结果，验证透明通道、尺寸与非空边界；复制运行副本，记录 SHA-256、原路径和用途。
- [x] 每批查询 preview status，仅存活时刷新与读取证据。

## Task 2: 演出控制器

Files: scripts/ui/landscape/SalvageController.lua, tests/SalvageControllerTest.lua, tests/run_salvage_controller.py。

Interfaces: New() 返回 active, elapsed, letterInstanceId；Begin(id,fit,now)；Update(dt,fit,focused,now) 返回 complete/interrupted；Skip()；Cancel(reason)；Acknowledge(id)；Pose()。

- [x] 先写行为测试：重复 Begin 不覆盖收信、正常完成一次、中断保留收到的 ID、错误 ID 不确认；通过现有 content_test_runtime.run 运行，记录预期失败。
- [x] 实现纯前端状态和分段平滑位姿。任何方法都不读写业务状态。
- [x] 重跑测试检查成功，并审查收到的 ID 在中断路径仍可访问。

## Task 3: 正式海边与集成

Files: scripts/ui/landscape/SeasideView.lua, SeasideManifest.lua, AppView.lua, tests/SeasideFlowTest.lua, tests/run_seaside_flow.py；更新 HomeEntryTest 的显式动画等待。

- [x] 行为测试先运行：点捕捞后真实次数 +1，尚未打开 Reader；重复点击与 HUD 不产生业务；等待后才 Reader；失败无动画/瓶子奖励；读信失败保留重试；空海、返回、商店与中断路径。
- [x] New(ctx) 构造稳定绘制层和底部操作区，Update(view,clock) 在 model.dirty 前推进；Refresh(view) 只更新状态文本、按钮和可见性。
- [x] AppView.StartSalvage 查询真实门禁，执行一次 Receive 成功后 Begin；OpenCapturedLetter 成功后 Acknowledge，失败保留 ID。演出中拒绝 Open/Read/Navigate 的用户重入，内部完成读信先释放阻挡。
- [x] 用 Render(vg) 绘制底图、轻微浮动的船瓶、网兜与矢量波纹水滴，使用同一 contain fit。船热区只开商店；HUD 不随图片动。
- [x] 状态中断移到 received，允许阅读或返回；销毁清理引用且之后 Update 无效果。

## Task 4: 验证与交付

- [x] 运行专项控制器、海边流程、主页 303 项检查、门洞推进 383 项检查。
- [x] 运行可用 Lua LSP，处理本次生产文件 Error；运行 git diff --check。
- [x] 导出有 OFFLINE 标记的场景和演出关键帧，实际查看素材/图层/按钮区域。
- [x] 检查真实 preview status；只刷新活会话并获取 logs/check，停止则记录原生与手机未验收。
- [x] 独立代码审查关注一次收信、中断、输入穿透、真实读信及安全区；修复重要问题。
- [x] 写行动记录及人工验收步骤，不提交推送。

