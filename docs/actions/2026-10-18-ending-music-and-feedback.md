# 结局音乐与熬制、报酬、封瓶音效

## Status and situation

Completed（本地接入、自动验证、本地提交与原生启动）；游戏内人工试听待用户确认。用户已试听接受 2026-10-18 指定的两首海浪伤感版完整混音，以及 brew_simmer、reward_coins_crisp_v2、wish_seal。以用户最后一句为执行边界：接入、验证后本地提交并运行游戏，不推送。

当前开发工作区为 `D:\taptap\To-the-Human-World-bgm`、`feat/brewing-bgm`，起点 `aaa2108` 与已核对的 GitHub main 一致。此前音量相关四份改动及同步 main 的未提交记录共五份，保存哈希并保护。共享 SceneMusicTest 只更新旅人音乐的旧预期，原有默认音量修改完整保留并不纳入本次提交；其余四份原样不动。本地旧 main 工作区不参与本轮实现。

起点情况：AudioCatalog 已统一管理预加载及音频路径；旅人和愿望结局共用 DepartureView 的演出淡出，原先仍复用海边曲。熬制演出以 BrewInteraction.active 为真实边界；报酬反馈已在 FeedbackMotion.Reward 按 transactionId 去重；愿望确认入口是 WishView 的 confirmWish。

## Implementation measures

1. 将五份指定 WAV 原样导入正式资源目录，校验 SHA256，保留署名与许可证；不导入分轨、预览或旧版。
2. 扩展 AudioCatalog / 结局预加载分组和单声源 SceneMusic 路由，愿望编辑、预览、寄出和回看用同一曲，保留已有演出音量控制及其他场景路由。
3. ObjectSounds 增加可独立停止的播放句柄及约 50ms 淡出更新；保持现有 Play 行为。熬制实际开始/结束触发生命周期回调；离页和销毁清理。
4. 正数报酬动画被接受时单次播放金币 v2；成功确认愿望并启动封瓶时播放 wish_seal，拦截重复成功回调。保持其他动作音效及游戏规则。
5. 运行隔离音频与真实业务/视图回归、资源哈希、保护范围及差异检查；明确区别自动检查、原生启动与人工听感。

## Affected file tree

- `assets/audio/bgm/*-ending-sea-melancholy-v2-loop.wav`：两首结局完整混音。
- `assets/audio/sfx/objects/{brew_simmer,reward_coins_crisp_v2,wish_seal}.wav`：三项单次物件声。
- `assets/audio/ending-feedback-manifest.json`、`ending-feedback-CREDITS.md`、`sources/2026-10-18-ending-music-and-feedback/`：版本、哈希及素材来源。
- `scripts/ui/landscape/{AudioCatalog,PreloadManifest,SceneMusic,AppView}.lua`：统一资源与结局场景音乐。
- `scripts/ui/landscape/{ObjectSounds,BrewInteraction,BrewView,BrewFeedback,WishView}.lua`：可取消熬制声与成功反馈触发。
- `scripts/ui/landscape/tests/`：专项及与新增资源有关的回归检查，保护已有未提交的 SceneMusicTest。
- 本行动记录：实际改动与分层验收。

实际测试文件为 `EndingAudioTest.lua`、`run_ending_audio.py`（新增），`ObjectSoundsTest.lua`（新增素材时长适配）、`PreloadTest.lua`（新音乐所在分组）、`SceneMusicTest.lua`（旅人曲预期）。所有五份 WAV 均附 `.wav.meta`。

来源目录保留原包的 `CREDITS.txt`、`source/inputs.json`、`source/ending-v2-sources.json`，以及 `source/licenses/` 中 Salamander 原始署名、existing-piano-credits、Kenney 两份 License、水声来源 JSON、海浪来源网页六份材料。没有导入旧曲、preview、reference、音乐/海浪分轨或原始下载包。

| 操作 | 正式运行资源路径 | 实际触发位置 |
|---|---|---|
| 旅人结局/留念回看 | `audio/bgm/traveler-ending-sea-melancholy-v2-loop.wav` | AppView 从 GetEndingView / reviewEnding 取得 kind；SceneMusic.Sync 路由 departure；DepartureView 继续提供原有淡出 |
| 愿望拼信、预览、成功寄出、留念 | `audio/bgm/wish-ending-sea-melancholy-v2-loop.wav` | SceneMusic.Sync 将 wish / wishPreview / wish ending 统一到同一路径，同曲不重播 |
| 熬制演出 | `audio/sfx/objects/brew_simmer.wav` | BrewInteraction.Start 成功进入 active → BrewView 的 Started；Skip / Cancel / Leave / Destroy 对应 Stopped，只停止持有的声源 |
| 正数报酬到账 | `audio/sfx/objects/reward_coins_crisp_v2.wav` | BrewFeedback 的 model.Resolve 成功后，FeedbackMotion.Reward 接受正数且未见过的 transactionId 时 |
| 愿望封瓶 | `audio/sfx/objects/wish_seal.wav` | WishView.confirmWish 成功 ConfirmEnding 后、设置 endingEntrance 时；committed 防重复 |

专项发现原有自动打开熬制结果页会额外播放 ui_click_01。仅为这条自动完成路径传入 Open 的 quiet 标记；手动查看待确认结果及其他按钮声音保持原有行为。没有延长动画或改变业务事务。

## Self-verification method

- 五份源/目标 SHA256、时长、采样格式一致；已有全部受管理音频文件哈希不变。五份未提交内容保留；共享测试按本轮独立替换规则反向校验原始哈希。
- 检查结局路径、循环、同曲不重播、原场景及商店恢复、静音/音量与销毁。
- 检查熬制真实开始、重复/失败/恢复静默，跳过/取消/离页的指定声源停止与淡出；报酬事务去重、零金额/失败静默；封瓶成功与失败/禁用/重复边界。
- 本轮启动前预览 stopped。完成后按用户明确指令启动当前工作区，并核对实际窗口与日志；不把启动或自动音频适配器当人工试听。

## Self-verification results

### 自动检查

全部在隔离存档、音频、时钟适配器下运行，不读取玩家存档。命令前缀为 `python -X utf8 -B scripts/ui/landscape/tests/`：

| 脚本 | 实际结果 |
|---|---|
| `run_ending_audio.py` | 839 断言通过：两首正确路由、循环标志、愿望连续播放、退出恢复、现有淡出；熬制正常/跳过/取消/离页/失焦/销毁；50ms 独立淡出；旧句柄不停止复用声源；金币正数、失败、零负数和事务重复；封瓶成功、失败、禁用、刷新、恢复、重复；独立音量/静音及清理 |
| `run_scene_music.py` | 201 断言通过：设置持久化、失败处理、单 BGM、各场景与商店恢复、main Stop、学徒保留原曲 |
| `run_object_sounds.py` | 864 断言通过：原八项物件触发与声音管理兼容 |
| `run_brewing_audio.py` | 最终版本 596 断言通过：捞网/药炉入口、捞瓶、三场景、商店覆盖与音量 |
| `run_brew_action_sounds.py` | 643 断言通过：原剪词、选词和七项投料音效 |
| `run_ui_action_sounds.py` | 493 断言通过：普通按钮、购买、结束一天及失败/重复边界 |
| `run_brew_workbench.py` | 191 断言通过：真实投料、熬制、结果及交互流程 |
| `run_departure.py` | 5 项通过 |
| `run_wish.py` | 9 项通过 |
| `run_apprentice.py` | 6 项通过，含完整十一封信路线 |
| `run_preload.py` | catalog / loader / entry / navigation 全部通过，五个正式音频及 meta 存在 |

补充检查：

- 五份 WAV SHA256 与源文件完全一致；44.1kHz PCM16，BGM 双声道、SFX 单声道；时长分别 90、85.7142857、1.65、0.64、0.82 秒。哈希记录在正式 manifest。
- 136 个原有受 Git 管理的 audio 文件（含元数据、来源）哈希全部一致。四份无本轮修改的脏文件哈希一致；SceneMusicTest 反向撤销本轮五个字符串变更后与原始哈希一致。
- `.tmp/check_ending_audio_commit.py` 用 HEAD 版 MusicSettings 和仅含本轮修改的 SceneMusicTest 做内存模块覆盖，SceneMusicTest 201 / EndingAudioTest 839 均通过，证明本轮提交不依赖默认音量草稿。
- `.tmp/check_ending_audio_lsp.py`：9 个生产 Lua 文件，0 errors、44 warnings。警告涉及动态类型推断、nil 和整数类型；本轮未做全工程警告清理，不称为零警告。
- 代码与本轮文档的 `git diff --cached --check` 通过（排除原样导入的 `source/licenses/`）。完整暂存检查提示上游许可证/网页原本带有行尾空格和空行；为保留来源文件，未改写这些材料。原始保护快照为 `.tmp/ending-audio-before.json`。

首轮 sandbox 执行受 `.tmp` 隔离目录写入权限影响，退出非零，不计成功；随后在获准的执行环境重跑全部通过。专项初版断言暴露自动结果页通用点击声，按上述窄范围修正后通过。测试中打印的 SAVE_WRITE_FAILED、缺失音频等为主动注入失败用例。

### 原生运行与人工试听

已在 feat/brewing-bgm 本地提交，随后执行 `taptap-maker preview start --target-dir D:\taptap\To-the-Human-World-bgm --json`。未推送、未合并。

本次会话 `667dac48-cf9d-4741-9af4-bf9b379e44d8`，原生 UrhoXRuntime PID 40892；运行日志显示 main.lua 及本次模块载入、数据校验通过和“寄往人间 启动完成（第 1 天）”。首次检查时窗口尚未出现，后续实际枚举确认可见 SDL_app“寄往人间”；窗口置前并截图检查，画面为炼药工作台、进程响应正常。截图保留在 `.tmp/ending-audio-window.png`。未点击、修改或重置当前玩家进度。

预览 CLI 的 ready 仍为 false、capabilities 为空，只作为进程状态使用；启动日志有 `Cube/Day/DaySpecularHDR.dds`、`themis_x64.dll` 两条引擎提示。当前日志没有 Lua 异常或 SceneMusic/ObjectSounds 音频加载报错，但这不等于五项操作已在原生游戏中逐项验收。

上述自动检查不等于真实引擎音频播放或人工试听；未在原生游戏中执行两种结局和三项反馈的完整试听。结局完整循环接缝、声音与视觉的主观同步、混音遮蔽程度仍需游戏内试听。没有使用网页试听替代游戏验收。
