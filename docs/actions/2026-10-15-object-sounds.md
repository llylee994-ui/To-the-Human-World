# 八个物件单次音效接入

## Status and situation

Completed（接入完成；用户明确接管游戏内测试，助手已停止自动验证，听感及八项实际操作验收待用户确认）。用户要求把五个物件 v2 与三个最新柔和版 WAV 接入实际交互，保持两首 BGM、其设置与场景切换不变。后续用户已授权将此批物件音效本地提交到 `feat/scene-bgm`，随后增加独立音效设置；不推送、不合并 main。

- 分支 `feat/scene-bgm`，起点 `015099b925606fbbb6d7a1febbfd18546754a6ce`，开始时工作区干净。
- 当前工程、原工程及上级目录均不存在 `AGENTS.md`；已读取用户提供的协作规则和 `scripts/fyyAGENT.md`。使用本机 SDK 文档和类型声明核对音频，不生成或替换项目规则文件。
- 已有音频仅 `assets/audio/bgm/` 与 `SceneMusic.lua`；当前 UI 只有独立音乐偏好，没有独立音效设置。音效使用引擎 SOUND_EFFECT 通道现有音量，不改变音乐设置含义或添加新的设置 UI；文件增益 1.0。
- `SalvageController.Pose().phase` 为实际 lowering/lifting/reveal 阶段来源；不能在固定延时或 Receive 成功时播放捞瓶声。
- 来信抽屉、托盘和记录书的 Open 位于重建面板路径中，已区分用户操作与刷新/恢复。书本入口核实为 `LayoutManifest.home.journal → ctx.Open("journal") → JournalBook`；界面现名“记录书”/“故事记录”，未发现另一独立配方书入口，本次按用户所指物件接入，不改界面命名。

## Implementation measures

1. 按用户给出的路径复制八份 WAV 到 `assets/audio/sfx/objects/`；保留原始试听目录，附素材来源、授权文本与逐文件哈希，不重新处理音频。
2. 添加独立短音效播放器，非循环、增益 1.0、音效通道；隔离所有声源生命周期，不调用或修改 BGM。
3. 在实际生效的开合、点击进入阅读、lifting 状态边沿触发；避免初始化、重建、恢复、失败、跳过和重复点击误播。保持动画时长与业务流程。
4. 用真实交互入口专项测试验证事件次数、音频参数和 BGM 连续性。运行本机 Lua 诊断并检查导入哈希与 BGM 完整性。
5. 原计划使用隔离内存存档做原生验证；用户随后明确“我自己测试，不用你测试”，因此停止并移除本轮临时原生探针，恢复普通玩家入口。游戏内操作、音画时机和实际听感由用户确认。

## Affected file tree

- `assets/audio/sfx/objects/`：八份原样音效及来源、授权说明。
- `scripts/ui/landscape/ObjectSounds.lua`：单次物件音效播放器与资源映射。
- `scripts/ui/landscape/AppView.lua`：接入实际操作、读信与 lifting，管理短音效生命周期。
- `scripts/ui/landscape/LetterDrawer.lua`、`WordTrayDrawer.lua`、`JournalBook.lua`：实际开合状态边沿，保持动画。
- `scripts/ui/landscape/SeasideView.lua`、`ReleaseClosingView.lua`：标明用户主动进入阅读，与捕捞自动阅读区分。
- `scripts/ui/landscape/tests/ObjectSoundsTest.lua`、`run_object_sounds.py`：保留已经通过的专项回归；临时 ObjectSoundsNativeProbe 已移除，DevChecks/NativeProbe 恢复原样。
- `docs/actions/2026-10-15-object-sounds.md`：本行动记录。

## Self-verification method

- 比对源/导入 WAV 的 SHA256、格式和时长，保留来源清单和许可证；核对 BGM 两份 WAV、控制器和偏好模块无变化。
- 音效专项通过真实 AppView、真实 UI 控件回调及动画状态验证；适配音频设备和存储，覆盖失败、取消、跳过、刷新、重复及销毁。
- 相关音乐、来信、托盘、记录书回归与本机 EmmyLua；差异检查。
- 原生预览日志、独立短音效源的实际播放状态、BGM 播放位置连续性及游戏窗口操作。原生接口证据不等于用户听感或手机验收。

## Self-verification results

- 八份 WAV 导入后与用户指定源文件、源包 manifest 中 SHA256 全部相同；格式均为 44100 Hz、单声道 PCM16。时长依次为瓶子 .94s、抽屉开 .62s/关 .49s、信件 .32s、托盘开 .22s/关 .20s、书开 .49s/关 .36s。源试听目录未修改；来源包的 CREDITS、manifest、素材来源清单及许可证随资源保存。
- `run_object_sounds.py` 首轮 544 项通过：真实 AppView、控件回调、成功/失败读信、实际 lifting 边沿、早跳过/晚跳过、焦点中断、帧间隔中断、快速重复、刷新/恢复、开合不写玩法、声源池上限/复用、销毁及缺失音频重试。测试中的保存失败和缺失音频为主动注入；该层使用音频/时钟/存储适配器，不是游戏内听感。
- 相关回归：`run_scene_music.py` 144、`run_letter_drawer.py` 98、`run_word_tray.py` 64、`run_journal_book.py` 69 项通过。BGM 两份 WAV、SceneMusic、MusicSettings、MusicSettingsView 和 SalvageController 与起点逐份 Git blob 相同；原动画数值未改。`git diff --check` 通过。
- 首轮本机 EmmyLua 检查 11 个 Lua 文件：0 Error、162 Warning。证据 `.tmp/object-sounds-lsp/diagnostics.json`；用户接管后不重跑诊断或测试。后续只增加过原生探针诊断打印，现已删除该临时探针及其入口，生产音效代码未再变化。
- 原生运行仅确认游戏启动并加载新模块。首轮探针在识别 BGM 声源时中止；后一次确认引擎只有一条 Music 声源、playing=true、gain=1，但播放位置连续性断言中止，未完成八个操作的实际验收，原因未最终确认。过程中一次公共资源索引下载失败，官方重试后成功启动。均不能据此宣称游戏内音效或 BGM 连续性验收通过。
- 用户明确停止助手测试后，已停止验证会话、删除临时原生探针并恢复普通入口；不再派发自动点击或执行测试。已有隔离回归结果保留，实际听感、快速点击、反复开合、BGM 同时播放表现与手机实机由用户检验。
- 本地提交范围限定为本记录列出的物件音效资源、来源授权、接入代码与已有回归文件；音效开关/音量设置作为下一批独立开发，不混入此基线提交。本次提交前不重新执行游戏或自动测试。
- 提交暂存检查：来源包的原始许可证 TXT / HTML 快照存在上游尾随空白，因此全量 `git diff --cached --check` 有提示；保留这些原始授权文件，不为格式清理改写。项目接入代码、资源清单及行动记录单独进行差异空白检查。

## 操作、资源与触发位置

所有运行资源路径均在 `audio/sfx/objects/` 下；播放器为 `scripts/ui/landscape/ObjectSounds.lua`，单次、非循环、gain=1.0，使用独立 SOUND_EFFECT 声源池（最多 8 个并行源，复用已结束声源），不改变任何总线音量，不调用 BGM 的播放/停止方法。

| 操作 | 资源文件 | 实际触发位置 |
|---|---|---|
| 捞起玻璃瓶 | `bottle_lift.wav`（v2） | `AppView.ctx.Update` 中 Salvage.Update 后，仍 active 且 Pose.phase 首次进入 lifting。失败/取消/跳过不会补播。 |
| 拉开来信抽屉 | `drawer_open.wav`（v2） | `LetterDrawer.Open(ctx,userInitiated)`，显式打开请求且 target 从关闭转为打开时。 |
| 收起来信抽屉 | `drawer_close.wav`（v2） | `LetterDrawer.RequestClose`，存在可收回进度且不是已关闭/已在关闭状态时。 |
| 点击信件进入阅读 | `letter_pick.wav`（柔和版） | `AppView.ctx.Read(id,true)`，业务读取成功、确实进入新的阅读状态后；抽屉卡片、桌面信纸、海边“继续阅读”、收尾“打开来信”标记主动点击。自动展开和演出跳过不播纸声。 |
| 展开词条托盘 | `tray_open.wav`（v2） | `WordTrayDrawer.Open(ctx,userInitiated)`，实际开始展开时。 |
| 收起词条托盘 | `tray_close.wav`（v2） | `WordTrayDrawer.RequestClose`，第一次开始收回时。 |
| 翻开配方书物件 | `recipe_book_open.wav`（柔和版） | `home.journal → ctx.Open("journal") → JournalBook.Open(ctx,userInitiated)`，当前 UI 名称为记录书。 |
| 合上配方书物件 | `recipe_book_close.wav`（柔和版） | `JournalBook.RequestClose`，第一次开始收回时。 |

界面重建和从阅读返回保存的抽屉面板不会携带显式打开标记，因此不额外播开声；强制导航/销毁时直接 Reset 沿用原流程，不补播未发生的关闭动画。原始 WAV 自带的信件轻、开书稍重、合书再稍重关系原样保留。
