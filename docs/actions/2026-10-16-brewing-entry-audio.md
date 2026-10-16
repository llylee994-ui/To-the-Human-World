# 捞网、药炉入口音效与炼药 BGM

## Status and situation

In progress：实现与自动检查完成；用户正在游戏内试听，原生循环属性检查未通过，原因仍待确认。用户后续要求重启正常游戏，并反馈两个入口音效在 BGM 下不够明显，本轮追加提高这两项音效响度。工作区原为干净的 feat/scene-bgm；获取 GitHub 最新 main 后，在同一目录 `D:\taptap\To-the-Human-World-bgm` 从 main `20feb459d1c34ced8dc2a9dd3b45f53130312ccd` 新建 `feat/brewing-bgm`。2026-10-16 用户明确授权将本次音频接入及响度调整本地提交到该分支，要求不推送、不合并 main；按此范围保留代码、资源、来源说明和验证记录，其他工作树和 main 引用不变。本地提交不代表补齐尚未完成的原生循环或人工验收。

- 工程无 AGENTS.md，按用户协作规则及 `scripts/fyyAGENT.md` 执行；SDK 音频签名以现有 `.emmylua/SoundSource.d.lua`、`Sound.d.lua` 为据。当前检出不含 engine-docs/examples，沿用已验证的播放器接口。
- HomeView 物件点击经 AppView 回调进入 BeginHomeZoom；捞网默认海边、药炉传入 stove 使用独立过渡配置。声音放在入口回调中，只在 BeginHomeZoom 返回 true 后调用，不给程序导航或初始化加声。
- SceneMusic 已有单声源、同曲去重、音乐设置与退出销毁；现有 brew 回落主页曲，本轮增加 brew 分支，shop 覆盖优先级保留。
- 只导入 net-and-brewing 的 net_pick，以及 brewing-mystery-v2 的 stove_touch 和 brewing-mystery-loop；不导入旧版、试听对照或独立 ambience。

## Implementation measures

1. 三份 WAV 初次原样导入已有音频目录；记录源/目标 SHA256、格式、时长、来源与授权，保存原包说明和许可证。后续按用户明确要求，仅把项目内 net_pick/stove_touch 的样本振幅提高至原始文件的 1.6 倍（约 +4.08 dB）；保留外部原文件和全部 BGM，运行时增益、开关及音量接口不变。
2. ObjectSounds 注册两个入口资源；AppView 在入口导航成功返回后分别播放一次，保留专属捞瓶及普通按钮声。核对遮挡与过渡守卫。
3. SceneMusic 按 shop/海边 → seaside、brew → brewing、其余 → hearth 选曲；其他循环、增益、用户设置、释放逻辑不改。
4. 增加行为回归，覆盖实际入口、快速重复、拦截、刷新、工作台操作、商店覆盖、静音/音量及销毁。保留现有音效回归。
5. 运行 Lua 诊断、资源校验和独立的原生运行验证；把适配器检查、引擎检查与人工听感明确分开。

## Affected file tree

- `scripts/ui/landscape/AppView.lua`：入口成功回调和有效交互守卫。
- `scripts/ui/landscape/ObjectSounds.lua`：两项单次音效注册。
- `scripts/ui/landscape/SceneMusic.lua`：炼药场景曲分支。
- `assets/audio/sfx/objects/net_pick.wav`、`stove_touch.wav`：指定来源的入口音效，后续按用户要求提高振幅至 1.6 倍；`assets/audio/bgm/brewing-mystery-loop.wav`：逐字节原样资源。
- `assets/audio/brewing-manifest.json`、`brewing-CREDITS.md` 与 `sources/` 下对应来源说明/许可证；原物件目录 CREDITS 增加新资源清单指引。
- `scripts/ui/landscape/tests/`：新增入口/炼药音乐专项；既有 SceneMusicTest、ObjectSoundsTest 更新预期或资源名单。
- 本行动记录：实施和验证事实。

## Self-verification method

- 初次三份源/目标 WAV 哈希一致；后续音效增大后，逐样本核对两项振幅转换、格式/时长不变、无削波，以及原始文件和三首 BGM 未改。来源及当前资源哈希分别记录；旧主页/海边 WAV 与基线哈希、Git 内容一致。
- 新专项及既有音效/音乐/过渡检查，采用隔离存档与显式音频适配器；仅必要用例，不扩展长耗时全剧情回归。
- EmmyLua：修改的 Lua 无 Error；记录 Warning 数量。
- 原生 SoundSource 资源、次数、播放位置、循环、音量、单声源和释放；使用隔离数据，原生证据不代表主观听感或手机实机。

## Self-verification results

- 初次导入的三份源文件与目标 SHA256、PCM16/44100Hz、声道和时长全部一致，详见 brewing-manifest.json。只复制指定三份 WAV。后续提高入口音效响度：`.tmp/raise_entry_audio.py` 从外部原始文件计算，避免累积放大；捞网实际 RMS 增量 +4.0824 dB、峰值 -13.417 dBFS，药炉 +4.0824 dB、峰值 -12.918 dBFS，未削波。时长仍为 0.40/0.52 秒，运行时增益基准仍为 1.0。详见 `.tmp/entry-audio-gain-result.json` 与资源清单。
- 新入口专项首次缺少无头指针枚举适配器，补齐后发现 Panel 热点 disabled 不会自动阻止业务回调；在 BeginHomeZoom 添加对应入口 disabled 守卫，随后专项 568 项通过。并补齐设置/首页/日历/其他过渡遮挡守卫，正常动画与业务流程未改。
- `run_scene_music.py` 149、`run_object_sounds.py` 624、`run_ui_action_sounds.py` 421、`run_home_zoom.py` 383 项通过。测试使用隔离存档；主动注入保存失败、无有效配方或缺资源的日志不等同于用例失败。
- EmmyLua 六个修改的 Lua 文件：0 Error、29 Warning。证据 `.tmp/brewing-audio-lsp/diagnostics.json`。
- 原生验证采用 `.tmp/brewing_audio_native_main.lua`（全部存档/偏好为内存适配器）；开始预览时暂用该入口，随后完整恢复 scripts/main.lua 并检查哈希和 Git 差异。原入口备份在 `.tmp/brewing-audio-original-main.lua`。首次准备后提前恢复导致预览重新准备了正常入口；随后使用探针成功启动，session `70970500-8c0e-4805-9f08-b0bd4b3a3d8e`、reload 0，在首页启动检查处报告 `BGM loop flag` 断言失败，未完成后续场景操作及 84 秒循环验证。证据 `.tmp/brewing-isolated-log-117.json`，cursor 511。资源就绪时机、原生属性读法和实际播放设置的原因尚未确认，不能记为原生循环验证通过，也未据此擅自更改原有 BGM 循环逻辑。
- 用户要求重启后已恢复正常游戏入口，session `3b04d433-ec3b-4eb1-a960-ae4e608a3681`、reload 0；后续用户反馈能听到入口音效但在 BGM 下不明显，因此进行上述两项音效增大。此反馈不代替全部操作、循环或音量设置的人工验收。
- 增大后执行 `taptap-maker preview refresh --target-dir D:\taptap\To-the-Human-World-bgm --json`，同 session 的 reload 1、PID 27236 运行；预览副本中的两项入口 WAV、新炼药 BGM、正常 scripts/main.lua 哈希均与当前工作区一致。日志 cursor 470/488 为正常游戏“启动完成”，502/503 为两项入口资源下载完成，读取至 510 无新增脚本报错。证据 `.tmp/brewing-louder-player-refresh.json`、`.tmp/brewing-louder-player-log-0.json`、`.tmp/brewing-louder-player-log-500.json`。已有环境错误 `Cube/Day/DaySpecularHDR.dds` 缺失及 `themis_x64.dll` 加载失败仍存在；进程/启动日志不代替画面、交互及实际听感确认。
- 本次响度调整未改 Lua 播放逻辑，不重复运行已通过的行为专项；样本转换、格式、时长及无削波检查已运行，三首 BGM SHA256 均保持调整前原值。`git diff --check` 通过；scripts/main.lua、MusicSettings.lua、SoundSettings.lua 与原有两份 BGM 的 Git 差异为空。提高后的入口声音仍待用户游戏内试听确认。
- 本地提交前再次核对：分支为 feat/brewing-bgm，暂存区原为空；当前所有待提交文件均属于本行动范围。`git diff --check` 通过，资源清单的三份 SHA256 与当前资源一致，旧主页/海边 BGM 与下列基线一致，main.lua 和音乐/音效设置模块无改动。本轮只进行提交检查，沿用上述行为回归与运行记录，未重跑游戏或把既有原生检查失败改记为通过。
- 首次完整暂存检查发现新增的两份 Kenney Impact Sounds 许可证和一份 RPG Audio 许可证含原始行尾空白，`git diff --cached --check` 因而失败。三份许可证均已逐文件核对 SHA256 与外部来源一致，按来源存档要求原样保留；仅排除这三个确切许可证路径后，其余暂存改动的空白检查通过。暂存范围按明确文件清单核对，共 21 个相关文件，不含本地缓存、预览探针或其他工作树内容。

初始主页 SHA256：`29814323594388cbb660e34c4a02c26f719cf5daf1788459ff9559ebf51614d9`。

初始海边 SHA256：`5ef34eb8badaf937d546fd8ba893acf499e062517ca23bd8ec561c94a83536b6`。
