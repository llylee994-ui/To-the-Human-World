# 信纸与剪词演出 Implementation Plan

> 本轮由当前会话直接执行，用户明确要求不使用子代理。按已确认方案增量修改现有工作区，不提交或远端构建，不覆盖其他窗口的修改。

**Goal:** 手写正文内点词剪裁，保留原排版剪口，纸条飞入可见收集区，展开信纸并保留安全内边界。

**Architecture:** `LetterLayout` 负责可测量的 UTF-8 排版及背景矩形减去剪口；`LetterPaper` 是新 UI 系统的自定义纸面控件；`LetterPresentation` 负责显示时序与飞行纸条。`Panels` 仍使用真实 GetView/Cut，`AppView` 在业务 dirty 判断前推进显示动画。全部剪词数据使用现有 spanId/tokenId，不改业务或存档。

**Tech Stack:** Lua 5.4、urhox-libs/UI、已有手写 TTF/纸图/黄铜剪刀 PNG；自定义控件使用框架传入的 NanoVG 上下文，不另起帧或上下文。

## Global Constraints

- 阅读面板 32 基准像素内边距和 32 像素纸图切分保持；正文 18pt，测量和绘制都使用 story 字体。
- 关闭/缩放/失焦取消显示动画；成功保存已剪状态不能因动画中断回滚或重复领取。
- 原始纸图与剪刀原字节复用；正文动态渲染，不生成带字图片。无视频生成。
- 停止的预览不自动启动；每批改动检查 status，存活才刷新并读取日志。

### Task 1: 排版与剪口

Create `scripts/ui/landscape/LetterLayout.lua` and `tests/LetterPresentationTest.lua`.

- [x] 使用独立测量夹具验证中文/英文/换行/窄屏、同字不同 span、剪前后坐标相同、长词分片；先运行失败测试。
- [x] 实现 `Layout(segments,width,lineHeight,measure)` 返回 `{runs,height}`，每段 `{text,spanId,x,y,w,h,cut}`；已剪文字保留原测量宽度。
- [x] 实现 `VisibleRegions(frame,holes)`：返回不覆盖任何剪口的矩形集合，裁剪屏外剪口，纸面区域覆盖且不重叠。
- [x] 验证后直接审查边界，不派代理，不提交。

### Task 2: 纸面和时序

Create `LetterPaper.lua`, `LetterPresentation.lua`; modify `Panels.lua`, `AppView.lua`.

- [x] 写真实业务集成测试：失败剪词无剪口/飞行，成功单卡，滚动不重建，关闭/重开状态保留，时钟推进不写档。
- [x] 纸面渲染测量字体一致，热区使用滚动后的屏幕坐标，正文纸条与底部可触控替代入口共用同一命令。
- [x] 保存成功后剪刀沿边演出、纸条抬起并飞入右下角可见收集标记；每次只能一个飞行，滚动/关闭可中断。
- [x] 背景减去已剪位置，绘制内阴影/纸边；正文不出现占位括号。托盘使用同纹理的纸条式词卡。
- [x] `ctx.Update` 在 dirty guard 之前更新信纸开场/剪词显示；不把动画状态写入存档。

### Task 3: 验证和交付

- [x] 运行新增测试、ReaderBoundsTest、HomeEntryTest、MobileSafeAreaTest 和 LSP。
- [x] 取实际绘制调用生成明确标记的离线排版/演出过程证据，读图检查，不能当成真机证据。
- [x] 检查预览状态和差异；记录未完成原生/手机验收，不提交远端构建。

