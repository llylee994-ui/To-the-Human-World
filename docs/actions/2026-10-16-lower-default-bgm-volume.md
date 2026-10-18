# 降低全场景 BGM 默认音量

## Status and situation

Completed（默认值调整及自动检查完成；实际听感待游戏内试听）。用户要求把主页、海边、炼药等 BGM 的默认声音调小。当前工作区为 `D:\taptap\To-the-Human-World-bgm`，分支 `feat/brewing-bgm`，HEAD `b0ddcd2d375e1be1f815c8d0eadc04fbad9f0159`，开始时干净。

所有场景通过 `core/MusicSettings.lua` 共用一个音乐音量，AppView 在首次选曲前应用该设置。当前默认 100%，本轮统一改为 60%。保留有效的已存音量与静音选择，不迁移或覆盖玩家偏好；音量范围仍为 0–100%。音效设置、三份 BGM WAV、循环和场景选曲保持现有行为。本轮不提交、不推送、不合并 main。

## Implementation measures

1. 在 MusicSettings 中统一定义 60% 默认值，初始化和非数值/缺失音量的回退都使用该值。
2. 沿用现有设置面板与场景音乐接口，保留已存值、开关、上限和持久化行为。
3. 更新既有 SceneMusicTest 的默认值预期；执行现有音乐及炼药音频回归和必要 Lua 诊断。
4. 更新原音乐设置行动记录的当前默认值说明，保留历史验证事实。

## Affected file tree

- `scripts/core/MusicSettings.lua`：设备本地音乐偏好的默认值与异常回退。
- `scripts/ui/landscape/tests/SceneMusicTest.lua`：既有新用户/损坏偏好/实际初始声源增益预期跟随新默认值。
- `docs/actions/2026-10-15-music-settings.md`：注明默认值后续变更。
- 本行动记录：范围、验证及试听限制。

## Self-verification method

- `run_scene_music.py`：新用户默认、有效设置恢复、损坏设置回退、面板调节、静音、场景切换和退出释放。
- `run_brewing_audio.py`：首页/海边/炼药与商店覆盖、音效独立控制等已有回归。
- 对两个修改的 Lua 文件运行 EmmyLua，检查无 Error；`git diff --check`。
- 比较三首 BGM SHA256 与修改前值，以及音频资源、SceneMusic、ObjectSounds、SoundSettings、AppView 无差异。
- 预览当前已停止，不自动启动；不将适配器测试当作游戏内试听。

## Self-verification results

- `python scripts/ui/landscape/tests/run_scene_music.py`：149 项通过；新用户初始增益为 0.6，缺失/损坏/读取失败回退 60%，既有静音及音量恢复、滑杆即时调节、100% 上限、换曲/刷新和退出释放通过原有回归。证据 `.tmp/bgm-default-scene_music.log`。
- `python scripts/ui/landscape/tests/run_brewing_audio.py`：569 项通过，覆盖主页入口、海边捞瓶、炼药停留和商店恢复，以及音乐/音效独立设置。证据 `.tmp/bgm-default-brewing_audio.log`。这是隔离音频与存档适配器运行，不是引擎实际试听。
- `.tmp/check_bgm_default_lsp.py`：两个修改的 Lua 文件，0 Error、2 Warning；证据 `.tmp/bgm-default-lsp/diagnostics.json`。
- `git diff --check` 通过。所有音频资源、SceneMusic、ObjectSounds、SoundSettings 与 AppView 无差异；三首 BGM SHA256 与调整前一致。没有修改音频混音、音效响度或用户本地偏好文件。
- 修改前后官方预览状态均为 stopped；本轮未启动游戏、未实际试听。当前仅四个相关文件有改动，未提交、未推送。
