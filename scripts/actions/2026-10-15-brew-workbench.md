# 2026-10-15 炼药近景与投料

## 交付

用户确认讨论建议后授权编写计划并开工；未使用子代理。本轮完成前端首版，未提交、推送或远端构建。沿用同一房间的既有药锅推近与同一个 GameSession，未改玩法、剧情、数值、存档和素材源图。

- 近景默认同时打开词条托盘与记录书；分别关闭、页签重开；记录书默认当前订单。
- 木架同排四原料、名称、可用份数、实际作用说明；词卡和原料的锅口拖放、点击投入、槽内取出。
- 主/辅词、原料份数、心愿、必要条件、实际药效合为锅旁配方纸；槽位按设备读取，不预测后续星级。
- 成功保存试做后播放约 1.05 秒烟雾，可跳过；最终版本另有轻微锅口涟漪。失焦、尺寸变化、导航和销毁取消临时显示，不撤销或重算已保存结果。
- 结果纸页固定右上星级与关闭，正文独立滚动，底部固定重新调配/确认发货。关闭保留待处理结果；历史只读。
- 四瓶图片复用 IngredientArt；纸面、木纹、字体复用 HarborStyle；没有生成新图或修改美术原文件。

## 文件

新增 `BrewView.lua`、`BrewLayout.lua`、`BrewInteraction.lua`、`ResultView.lua`；AppView 仅装配和生命周期适配；WordTrayDrawer 增加可选拖放绑定和投入按钮，独立托盘入口保留。记录书通过独立子上下文直接复用，未修改 JournalBook.lua。

测试：`BrewWorkbenchTest.lua`、`run_brew_workbench.py`、关闭交付的 `BrewNativeProbe.lua`，以及 HomeEntryTest 对新界面入口/演出等待的适配；既有业务断言保留。

计划与设计见 `docs/superpowers/plans/2026-10-15-brew-workbench.md`、`docs/superpowers/specs/2026-10-15-brew-workbench-design.md`；人工步骤见 `scripts/ui/landscape/炼药近景验收.md`。

## 验证结果

- 初始专项在旧代码上因 `brew scene must mount a real workbench` 失败，随后实现；最终 45 项断言通过。真实 schema 3/4 的来源卡、取消、滚动仲裁、另一手指、保存失败、满槽、试做一次、跳过、失焦、双栏独立关闭、草稿、固定星级、重置历史、发货失败/重复确认均覆盖。
- 原托盘 64 项、记录书 69 项、主页推进 383 项通过。
- ReleaseFlowTest：生产 schema 4 的 58 份登记配方、真实连续 11 单流程通过。该检查未写玩家存档。
- ReleaseUITest 完整轮首轮 8 通过/1 失败：发现近景背景误挂隐藏的案件入口；已按正式版开关修复，再以原失败用例重跑 1 通过/0 失败。其余 8 项沿用同轮记录，不称为另一次全量 9 项重跑。
- HomeEntry 的新旧界面整单业务操作均通过，最终几何断言失败 `neighbor regions overlap at 1920: 74`；把 AppView/WordTray/HomeEntry 加载为 HEAD 原版本后，同一位置同一数值失败。
- 追加的旧 LandscapeFlowTest 在 `real reward once` 断言失败；加载 HEAD 版本界面后同样失败。运行配置和 PlayModel/core/systems 没有本轮差异；未改旧奖励断言遮盖问题。
- 最终 Lua LSP 工作区仍有 LetterDrawerTest.lua 的两条既有 ERROR（title、senderName），本轮新增与修改文件没有 ERROR。工作区仍有警告，不宣称全目录零诊断。
- `git diff --check` 通过；受保护的 core/systems/data/PlayModel/main/assets/image 无差异。

## 原生证据与限制

原生 Maker 使用已有存活会话，逐批官方刷新。探针创建内存保存的真实 GameSession，通过实际 Yoga 与 UI 触摸指针分派，验证来源词卡及海盐的一份拖入、单次试做、烟雾、固定星级/底部操作、关闭保留结果，最后检查玩家快照不变并恢复玩家界面。

- 探针初轮过早访问尚未挂载的 root.parent，检查方法修正为挂载后执行；另一次失焦期间拖动被取消。失败记录保留于 logs，不据此改动业务。
- reload 27、28、29 探针通过；29 补验海盐实际拖入，烟雾使用柔边渐变；`native-round29.json` 记录 `INGREDIENT_DROP` 和 `PASS`。
- `brew_native_*.png` 是原生引擎截图，已实际阅读。round27 保留早期画面；最终结果纸的固定评分有独立宽高，避免无尺寸文本消失。画面展示使用内存测试数据。
- 截图取自 reload 29；随后最终代码补了锅口涟漪并修复正式版隐藏案件对象，最后恢复所有探针关闭并刷新普通玩家窗口。截图不冒充这些后续补充的逐帧验证。
- 官方 check 仍因 `Cube/Day/DaySpecularHDR.dds` 缺失和 `themis_x64.dll` 加载失败为 FAIL；最新运行日志能看到项目启动完成，未发现新 Lua 运行错误。这不等于官方全绿。
- 未使用 OS 鼠标推进玩家订单；仅点击过主页药锅查看布局。手机拇指拖放、刘海/Tap 胶囊、不同真机尺寸及真机退出恢复未验收。

## 后续

请用户按人工清单体验排版、拖放手感和烟雾节奏，再做手机验收。既有主页几何、旧奖励断言及旧测试类型错误留给对应维护任务；本轮不改业务或引擎处理它们。
