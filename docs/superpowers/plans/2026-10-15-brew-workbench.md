# 炼药近景与投料 Implementation Plan

> **For agentic workers:** 使用 executing-plans，在当前会话按任务逐项执行。用户明确禁止子代理。项目 Maker 工作流优先，不创建分支/PR，不自动提交或远端构建。用户已确认设计并授权本计划及实施。

**Goal:** 在真实炼药事务上交付双栏近景、原料架、拖拽、配方摘要与烟雾后的固定星级阅读。

**Architecture:** BrewView 拥有近景及左右子上下文，复用 HomeView、WordTrayDrawer、JournalBook；BrewInteraction 管理临时拖动与保存后演出；BrewLayout 提供统一几何；ResultView 提供固定头尾的结果与历史阅读。AppView 负责生命周期和模态导航。

**Tech Stack:** UrhoX Lua 5.4、urhox-libs/UI、Yoga、UI 渲染上下文内 NanoVG、现有 PNG，Python+lupa 隔离验证。

## Global Constraints

- 不使用子代理，不改 core/systems/data/PlayModel、存档槽及引擎库，不生成新素材。
- 同一会话；所有写入只调用 PlayModel；拖动和演出不修改库存；以成功保存为结果显示依据。
- UI.Scale.DEFAULT；关闭热区至少 44 基准像素；左右默认展开且独立关闭；原料四种，容量来自实际设备。
- 必要条件不等于三星；无 pending 不显示成功星级；显示固定星级文字与图形，不仅靠颜色。
- 相关修改后查询实际预览，存活自动刷新+日志/check，停止不启动。

## Task 1：真实业务交互的失败测试

**Files:** Create scripts/ui/landscape/tests/BrewWorkbenchTest.lua、run_brew_workbench.py。

**Interfaces:** 复用 debug.fixtures.B5Fixtures.New(content,{targetSchema=3})、ZoomTestHost.New()；消费未来 ctx.brew、ctx.brew.Start/Skip/Cancel、BrewInteraction.New(model,onResult)。

- [x] 编写真实 session 的集成测试。最小入口断言：
```lua
view.Navigate("brew"); view.Update()
assert(view.root:FindById("brewWorkbench"),"brew scene is a workbench")
assert(view.root:FindById("brewWordsHost") and view.root:FindById("brewJournalHost"))
```
- [x] 执行 `python -X utf8 -B scripts/ui/landscape/tests/run_brew_workbench.py`，确认因近景缺失失败。
- [x] 控制器检查成功锅口才编辑一次、另一手指不能落料、纵向滚动取消、失败不反馈投入；演出成功保存后开始，重复/跳过/取消不重复试做。

## Task 2：拖放与演出控制器

**Files:** Create BrewInteraction.lua、BrewLayout.lua。

**Interfaces:** `BrewInteraction.New(model,onResult)` 返回 Begin/Move/Release/CancelDrag/ClickAllowed/Start/Update/Skip/Cancel；拖动包含 kind,id,文本/图片、pointerId，位置为全局基准像素。`BrewLayout.Compute(w,h,safe)` 返回 center/drop/shelf/wish/summary/controls。

- [x] 用真实 PlayModel 选入来源卡，检查松手锅口外不写入；锅口内成功单次保存；移出保留其它卡。
- [x] 实现控制器与几何。核心顺序：
```lua
local result=model.Preview()
if result.ok and result.value.phase=="pending" then state.active=true end
-- 演出完成只 onResult()，不能再次 Preview/Resolve。
```
- [x] 运行专项，确认控制器行为通过。

## Task 3：近景与双栏

**Files:** Create BrewView.lua；Modify WordTrayDrawer.lua、AppView.lua；复用 JournalBook.lua。

**Interfaces:** `BrewView.New(ctx)` 返回 root/Enter/Leave/Refresh/Update/Start/Skip/Cancel；托盘通过可选 ctx.brewDrag 绑定纸条，侧栏借助独立子上下文 Close 仅关闭自己。

- [x] 复用被屏蔽输入的 HomeView，并应用 StovePanZoom 的最终近景变换；同时渲染四原料一排、可滚动心愿与配方纸、锅口和固定熬制操作。
- [x] 两个子上下文共享父 model/session/content，分别持有 wordTray/journalBook，关闭后保留页签；当前委托默认 storyId，避免每次刷新覆盖用户选页。
- [x] 词卡绑定指针与纵向滚动仲裁，点击选卡后在托盘提供投入按钮；原料轻点显示 desc、投入一份按钮。药槽点取出。
- [x] AppView brew 分支不再重建旧功能页；帧更新在 dirty 判断之前推进动效；模态、导航、销毁、窗口变化取消拖动/演出。
- [x] 每批运行专项与 preview status；存活 refresh 后读 logs/check。

## Task 4：固定星级后续阅读

**Files:** Create ResultView.lua；Modify AppView.lua。

**Interfaces:** `ResultView.Render(ctx,overlay,history)` 查询 GetAttempt，pending 模式底部调用 Resolve，history 模式不出现结算命令。

- [x] 结果/历史阅读采用固定顶栏星级、正文 ScrollView、固定底部按钮。使用实际 record.rating.stars。
- [x] 检查关闭保留 pending，发货保存失败仍留原页，重置成功返回近景且永久历史仍可查询。

## Task 5：回归与交付

**Files:** Update 本计划、scripts/ui/landscape/炼药近景验收.md。

- [x] 运行专项、原 HomeEntry、HomeZoom、托盘/记录书、schema 流程及本次修改覆盖的接口检查；不改旧断言遮盖行为错误。
- [x] Lua LSP 检查生产与测试文件，修复新增 Error；`git diff --check`。
- [x] 检查当前存活窗口的新日志与 check，保留既有启动资源错误；不冒充手机验收。若无法取得实际窗口截图，明确记录未验证。
- [x] 交付文件、已执行证据、人工步骤与剩余限制。本轮不提交、不推送、不远端构建。

## 执行结果

已按确认方案交付前端首版。最终专项 45 项；托盘 64、记录书 69、主页推进 383 通过；生产 schema 4 的 58 配方及连续 11 单通过。原生内存测试已走通词卡及原料拖放、烟雾与固定星级。官方 check、两套旧检查及既有 LSP 错误的限制见 scripts/actions/2026-10-15-brew-workbench.md。手机验收未执行；测试开关恢复关闭，无提交/推送/远端构建。
