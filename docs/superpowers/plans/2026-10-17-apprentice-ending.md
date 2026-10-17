# 学徒结局替换实施计划

**Goal:** 完成11封信且达到原学徒条件后，照常结束当天，渐暗转室内；捎信旁白、全屏信纸、收下信件、两屏旁白、熄灯落款与返回首页。

**Architecture:** 保留 ReleaseEpilogue 的 dawn/letter 和 ConfirmEnding 保存边界。新增 ApprenticeView 管理捎信与展开/收起，ApprenticeText 从正式或冻结正文提取来信与收尾；复用旅人展示组件的分页、输入保护和末尾落款，仅通过可选参数指定室内背景、学徒落款与音乐。老留念使用其冻结正文，不改玩家存档。

**Tech Stack:** UrhoX Lua 5.4、urhox-libs/UI、现有信纸、StoryStyle 金边花饰按钮与室内场景。

## 边界与约束

- 不生成图片，不改学徒资格、11封信完成判断、天数或存档结构，不提交推送、不远端构建。
- 信纸不出现“商人捎来的信”标题；正文为店主两段话，全三星追加评语在信内；右下角手绘墨线笑脸，不覆盖正文和按钮。
- 信件展开后整封可读，低高度滚动兜底；收下按钮使用 StoryStyle 深蓝金边款。落款按钮复用旅人结局细黄铜线样式。
- 淡入、失焦、拖动、次触点、销毁后回调均不得推进。收下仅在保存成功后收起；保存失败保留信件并显示恢复入口。
- 每批代码后查本地预览状态；仅刷新仍存活的会话，不启动已停止的会话。

## 实施步骤

- [x] 新增 ApprenticeViewTest 与启动器：真实11封信和原家居条件进入学徒，海边结束当天后回到室内；信件/全三星正确；收下只提交一次、失败不前进；读信和留念回放无额外存档写入；连点、失焦受保护，滚动取消沿用 Departure 专项覆盖。先运行，确认现有流程不能满足新界面。
- [x] 新增 ApprenticeText（`Read(text) -> {intro,letter,pages}`），新建 ApprenticeView（`New(ctx,options)`，options 为 step、ending、review）、ApprenticeLetter 和 EpiloguePointer。dawn 调 AdvanceEpilogue；letter 调 ConfirmEnding；保存成功后收起，交由 ending 路由播放后续旁白。回放只运行展示。
- [x] 给 DepartureView 增加可选展示参数：`pages`、`heading`、`subtitle`、`room`、`music`；默认旅人行为保持。AppView 增加室内结局音乐系数和室内演出遮罩；EndingView/ReleaseClosingView 分派学徒。CalendarView 学徒末日使用普通“结束今天”提示。
- [x] 调整现有学徒界面检查以真实等待和翻页，保留业务断言；运行 apprentice、departure、EndingPresentationUI、ReleaseUI、ending-saves、day-gate、SceneMusic，单文件 LSP 与 diff 空白检查。
- [x] 独立代码复核并修复实际问题；记录预览状态与实际窗口未验收边界。

基本行为断言：

```lua
assert(view.scene=="home" and view.panel=="closing")
assert(view.root:FindById("merchantLetterText"):GetText():find("店里那支笔",1,true))
assert(not view.root:FindById("merchantLetterTitle"))
assert(view.root:FindById("finishMerchantLetter").props.backgroundImage:find("story-result",1,true))
assert(saved.chapter.ending.kind=="apprentice")
assert(writesAfterReplay==writesBeforeReplay)
```
