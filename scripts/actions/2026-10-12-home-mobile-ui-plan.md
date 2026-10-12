# Home Mobile UI Implementation Plan

> For agentic workers: use subagent-driven-development for pure presentation/layout modules and scoped reviews. Preserve current main workspace and all unrelated changes; no commit/push/build.

**Goal:** 实现用户已确认的轻量手绘 HUD，清理技术文案，避让平台胶囊，提供可收起物件提示。

**Architecture:** AppView 保持真实业务路由，新增纯 MessagePresenter/HudLayout 与复用 HarborStyle。绘制和命中复用现有 contain/Geometry；背景不因胶囊额外缩小。HomeView 引导由 UI.Label 组成并标为 pointerEvents=none。

**Tech Stack:** Lua 5.4、urhox-libs/UI、Maker 生成 PNG、现有 Python/Lua/headless 与原生只读探针。

## Global Constraints

- 用户已确认横屏纸签状态栏与木牌按钮；1920×1080 主图层排版保留。
- 不改 core、systems、data、默认槽、引擎库，不清档、不恢复捕捞次数。
- 平台圆点/绿色测试叠层保留宿主限制，不承诺 Lua 可移除。
- 最小触摸 44×44 UI 基准像素；正常提示 5 秒消退，阻塞错误持续。
- Maker 使用明确 target_dir；每批代码/资源后 preview status，alive 刷新并取 logs/check，不重启已停止会话。

## Task 1: 纯展示策略与避让计算

Files: 新增 MessagePresenter.lua、HudLayout.lua、tests/HomePresentationTest.lua、run_home_presentation.py。

Interfaces: MessagePresenter.New(migrationNotice) 返回 Observe(raw, now, important)、Current(now)；HudLayout.Compute(bounds, viewport, menuRect, requiredWidth) 返回 top/right 两个局部避让值，坐标均为 UI 基准像素。menuRect 是 SDK 归一化矩形。

- [x] 测试先验证 migrationNotice 转为玩家短文且原输入不变，普通提示到期、空消息隐藏、important 错误不过期。
- [x] 用手算 fixture 验证 1000×500 viewport 胶囊 left=.86/bottom=.12 时 HUD 有足够宽度则 right=152；可用宽度不足则 top=68；nil 及不相交胶囊不挤压。
- [x] 实现纯模块并运行 Python runner；不编辑业务/运行入口。

## Task 2: 手绘 HUD 与玩家消息接入

Files: 新增 HarborStyle.lua；修改 AppView.lua、SeasideView.lua、Panels.lua；新增 assets/image/harbor-ui-r1 素材来源记录。

- [x] 已尝试 Maker batch_generate_images 两张透明纹理；300 秒超时且无本地交付。保存请求/失败，改用原生纸木配色，无失效资源引用。
- [x] UI.Button 显式纸木配色与层次、文字/按下/hover/disabled 色覆盖默认蓝色，UI.Panel/Label 使用纸签式组件。真实纹理尚未交付。
- [x] 顶部 h48 透明布局换纸签状态块；HUD 本地 right/top offset 来自 HudLayout，场景尺寸不受胶囊影响。宽度不足采用纵向避让。
- [x] 隐藏/显示通知容器时不得改变 stage 的高度；模型 Notify 只在 View 装配中包裹以标注重要错误，保留 model.message 原诊断。
- [x] 每帧推进消息超时；模态内阻塞问题保持显示。进入极窄/竖向视口时显示横屏引导并阻止场景点击。
- [x] 运行现有 home/zoom/seaside 回归，不修改原业务断言；真实视觉变化通过窗口截图验收。

## Task 3: 物件提示与输入

Files: 修改 HomeView.lua，扩展 headless 输入和只读原生探针。

- [x] 所有 8 个真实交互物件由 manifest.label 生成 UI 标签，复用 ToScreen 锚点与 contain；装饰不增加热点。
- [x] ShowHints(value)、HintsVisible()、Update(dt)、SetFeedback(id)；首次 5 秒后消退，HUD 提示按钮可重新打开或收起。
- [x] 标签不吞输入；演出/推进阻挡期间不可见；小屏锚点在画布内并保持可读，按下反馈通过短标签表现。
- [x] 新测试先验证 timeout/再开/无装饰标记、提示开关不会写玩家状态；保留所有原点击/推进测试。

## Task 4: 验收与交付

- [x] Lua LSP diagnostic severity=1，四个既有专项 runner + 新 presentation runner，git diff --check。
- [x] 显式开启只读探针，查看实际 Yoga 位置和输入穿透；截普通主页、提示主页、海边，复制截图后关闭探针，再刷新普通入口。
- [x] 保存 preview status/logs/check 与图片，记录手机实机、绿色宿主叠层及既有 DDS/DLL 两条错误边界。
- [x] 独立审查只审本批 frontend diff；记录结果并更新动作记录。保持本地预览运行；不提交或远端构建。

实际交付与验证边界见 2026-10-12-home-mobile-ui-r1.md。图片背景/颜色规范任务使用组件方案完成，真实手绘纹理仍未交付；手机与宿主叠层保持未验证。
