# 炼药中间区重排 Implementation Plan

> **For agentic workers:** 使用 executing-plans 在当前会话执行；用户禁止子代理。用户参考稿授权布局修改，不自动提交、推送或远端构建。

**Goal:** 按来信横幅、药锅、薄配方槽、原料托盘、熬制按钮五层重排，并将“词条栏”移入木托盘顶部。

**Architecture:** BrewLayout 统一固定层次与锅口/槽位命中；BrewView 复用现有锅 PNG 和木纸素材；BrewRecipe 独立呈现槽位与按需详情。锅和槽位只调用同一 PlayModel 草稿命令。

**Tech Stack:** UrhoX Lua 5.4、urhox-libs/UI、UI 内 NanoVG、自有素材、Python+lupa。

## Global Constraints

- 不改 core/systems/data/PlayModel，不改变原料可选规则；四种原料及实际设备容量保持。
- 双栏沿用默认展开和独立关闭；中间区不因开关移动。图中的第五原料、翻页和新装饰不纳入。
- 原料支持锅口/原料槽投放；词条槽按模型确定的下一角色接受，不能将原料投进词条槽。
- 不重做美术，不新增大面积白面板，说明只在主动点击时展开。
- 相关改动后检查预览，存活则刷新并取日志/check；保留真实证据与已知引擎错误。

## Task 1：布局与命中回归

**Files:** tests/BrewWorkbenchTest.lua（均在 scripts/ui/landscape 下）。

- [x] 加入五层有序、空槽存在、当前信重读、标题避让金币、同一草稿的槽位拖放断言。
- [x] 运行 `python -X utf8 -B scripts/ui/landscape/tests/run_brew_workbench.py` 确认新行为缺失而失败。

## Task 2：重排及按需说明

**Files:** BrewLayout.lua、BrewView.lua、BrewInteraction.lua、BrewRecipe.lua（新增）、HomeView.lua、WordTrayDrawer.lua、WordTrayArt.lua。

**Interfaces:** Compute 返回 wish/pot/drop/summary/shelf/controls/slots；Target(layout,item,x,y) 返回合法命中框。Interaction 支持单框或 resolver；所有成功落料仍为 model.Drop(kind,id)。BrewRecipe.Render(ctx,b,summary,data,editable) 创建空槽与说明浮层。

- [x] 自底向上预留固定动作/低木托盘/薄纸槽，中间可用高度放大同一锅；仅 brew 隐藏背景中的旧锅图层。
- [x] 来信横幅展示寄信人与省略摘要，按钮经 ctx.Read(currentOrder.letterInstanceId) 重读；未接单查看来信。
- [x] 五槽常显，空槽虚线边框，实槽点击查阅并提供撤回；容量来自设备，不添加额外必填条件。
- [x] 材料行图片/名称/数量，横向 ScrollView；手指纵向拖入锅，横向留给滚动。
- [x] 词条标题移到木托盘内上沿，同时下移内容避免标题压卡；保持独立关闭。
- [x] 专项与托盘/主页相机回归，通过后查预览并刷新。

## Task 3：原生视觉及交付

**Files:** tests/BrewNativeProbe.lua、docs/验证/evidence/brew-center-r2/、scripts/actions/2026-10-15-brew-center-reflow.md。

- [ ] 原生内存夹具验证空槽、重排、真实槽位投料、可熬制及结果，不写玩家存档。
- [ ] 阅读截图，对照五层及标题避让；验证窄/矮窗口几何、LSP 与 diff 检查。
- [ ] 恢复测试开关并刷新正常窗口，记录实际通过项及未验证/既有失败。
