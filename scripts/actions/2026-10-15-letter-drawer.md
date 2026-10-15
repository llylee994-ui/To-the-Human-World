# 来信抽屉：下滑式独立界面

用户确认：抽屉是**独立界面**（不贴在主页桌面上），点击后整块从屏幕上沿滑下来，像把抽屉拉出来；×、左下 ←、点抽屉外部都走同一段收回动画，收完才真正关面板。不用轻微回弹（末端不过冲）；空抽屉用一句提示；旧的一列文字列表可以删。

- 新增 `scripts/ui/landscape/LetterDrawer.lua`：照 WordTrayDrawer 的约定，开合状态挂在 ctx（`open/target/settled/closing`），`.34s` smoothstep 垂直滑动；收完才调 `ctx.Close()`，切场景/换面板/销毁走 `Reset` 立即归位。
- 新增 `scripts/ui/landscape/LetterDrawerArt.lua`：抽屉版式与素材路径。**当前是占位素材**（木牌抽屉体、柔边纸面内腔、信纸卡），分层图产出后只改 `A.Images` 与这里的数字，其它模块不动。
- `AppView.lua`：`renderPanel` 增加 `letters` 分支；`Update` 增加 `LetterDrawer.Update`；六个 Reset 点同步；居中面板的 `modalBlocker` 在 letters 下改成"点外部走收回动画"。
- `Panels.lua`：删除旧的 `P.Letters` 与 `P.Renderers.letters`（被新抽屉取代）。
- 卡片：两列信纸卡，内容是 标题 + 寄信人 + 状态标签（未读 / 可剪 N 处 / 已读），纵向滚动、右侧滚动条位置已留出；空抽屉给捞信提示；从药锅进来（`choosingLetter`）显示"请选择要放到桌面阅读的信件。"；读信仍走 `ctx.Read` 业务动作。
- 打开时抽屉顶到 `safe.top`、宽度铺满安全区（左右各留 12），高度约可用高度的 78%，底部露出房间。
- 还没滑出来就点 × 时没有可收的动作，直接关面板（否则会卡在半开），这是相对侧栏约定的一处有意差异。

## 待出图素材（占位替换用）

| 用途 | 建议形态 | 建议比例/尺寸 | 透明 |
|---|---|---|---|
| 抽屉体（打开、空腔） | 正面看进抽屉内部：外框 + 内腔 + 两侧滑轨 + 底部前板 | 约 12:5（如 1500×620） | 需要 |
| 信纸卡 已读 / 未读 | 一张横放的信纸（未读可做成封缄/蜡印） | 约 3:1（如 660×220），两张 | 需要 |
| 标题铜牌 | 铜框长牌（标题字由代码渲染） | 约 8:1（如 480×60） | 需要 |
| 关闭按钮 | 铜框方板 + × | 1:1（如 96×96） | 需要 |
| 返回按钮 | 铜框方板 + ← | 约 4:3（如 112×84） | 需要 |
| 抽屉拉手 | 半圆铜拉手（纯装饰） | 约 4:1（如 280×70） | 需要 |
| 滚动条 | 竖向铜轨 + 滑块（可拆两张） | 约 1:8（如 24×190） | 需要 |
| 可选装饰 | 卷轴一束、绳捆包裹 | 放在内腔两侧留白处 | 需要 |

出图后放进 `scripts/素材/`（或 `assets/image/`）即可，按现有抠图/验收流程接入；`.meta` 由 Maker 构建或预览先生成，不用手写。

## 验证记录

- 新增 `tests/LetterDrawerTest.lua` + `tests/run_letter_drawer.py`：85 项断言通过，覆盖 关着不挂树 / 下滑到 safe.top 落定 / 卡片内容与三态标签 / 点卡片读信 / × ·← ·点外部三条收回路径 / 收回中途重开 / 切场景归位 / 空抽屉 / 计划提示 / 四组画布尺寸下的版式不含越界。
- 相关回归：`SeasideFlowTest` 89、`WordTrayTest` 64、`JournalBookTest` 69、`LetterPresentationTest` 8022、`LetterReaderTest` 14、`LetterRenderTest` 23、`ReaderBoundsTest` 45、`ui_contracts legacy`（B6 checks=104 / 172，failures=0）通过；`HomeEntryTest` 业务段通过，只余既有几何失败。
- `PaperConsistencyTest` 的"共用纸面框架"清单按惯例移出来信抽屉（与词条栏、记录书当初的处理一致）。
- 既有失败，与本次无关（已在原始 HEAD 上复现）：`HomeEntryTest` 主场景热点重叠 74 点；`ui_contracts mobile` 的 `MobileFrontendTest.lua:96`。
- 本地预览按规范 refresh（重启丢内存态），但 Maker 冷启动仍卡在 engine-startup 预载，日志未执行到项目脚本；**本轮没有原生或真机证据，也没有出截图**。
- LSP：本地 `maker-lua-lsp --mode check` 缺 `emmylua_check` 组件，跑不起来；改动过的 Lua 只做了括号平衡与逐段人工核对，不声明零诊断。
