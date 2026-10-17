# 将已验收的炼药音频分支合入 GitHub main

## Status and situation

Completed（合并与本地验证）。2026-10-17 用户确认合并后的游戏测试无误，授权将 `feat/brewing-bgm` 合入 `main` 并推送 GitHub，同时保留工作区其他未提交改动。本记录随合并提交交付；提交后的 GitHub 远端核对结果保存在主线工作区 `.tmp/merge-brewing-main-delivery.json`，不把提交前检查当作已经推送。

音频分支及 GitHub 分支均为 `6763c29090cd7c75629735b9d49730c2a142de8a`；最新 GitHub main 为 `b972242a931ad028cf2296d45d07c08761e3036a`，已是音频分支的祖先。主线工作区 `D:\taptap\To-the-Human-World-endings` 干净，本地 main 为 `20feb459d1c34ced8dc2a9dd3b45f53130312ccd`，可快进到 GitHub main。

`D:\taptap\To-the-Human-World-bgm` 保持在音频分支。其默认音乐音量调整相关的四份未提交文件不纳入本次合并或推送，已保存 SHA256 快照。只交付 GitHub，不提交 Maker；不修改音频、游戏逻辑或用户存档。

## Implementation measures

1. 核对远端、分支、祖先关系和两工作区状态；用 `merge-tree` 预检。
2. 在干净的主线工作区快进到最新 GitHub main，再以合并提交接收 `feat/brewing-bgm`。本行动记录是唯一额外文件。
3. 检查合并后的音频资源和相关回归；确认游戏文件树与已验收分支一致，四份未提交文件哈希不变。
4. 推送 GitHub main，核对远端 SHA 和音频分支引用。

## Affected file tree

- `assets/audio/`：接收分支中已提交、已验收的炼药 BGM、入口与炼药操作音效及其来源说明。
- `scripts/ui/landscape/`：接收已提交的音频映射、动作触发和对应回归检查。
- `docs/actions/2026-10-16-brewing-entry-audio.md`、`2026-10-16-merge-main-into-brewing-bgm.md`、`2026-10-17-brewing-action-sounds.md`、`2026-10-17-paper-water-sounds.md`：接收分支已有执行记录。
- 本文档：新增本次主线合并与推送记录。
- 音频工作区中的 `docs/actions/2026-10-15-music-settings.md`、`scripts/core/MusicSettings.lua`、`scripts/ui/landscape/tests/SceneMusicTest.lua`、`docs/actions/2026-10-16-lower-default-bgm-volume.md`：保留未提交状态和原始字节。

## Self-verification method

- 比较 Git 引用、祖先关系、合并前后树差异，确认只有本记录超出已验收分支树。
- 运行炼药音效、物件音效、场景音乐与信件表现的现有隔离回归。
- 比较音频工作区四份未提交文件 SHA256 和 Git 状态；核对指定源音频哈希。
- 推送后 `git ls-remote github` 核对 main；不将自动回归或用户此前验收扩张为本轮人工试听。
- 主线预览起始为 stopped，不因 Git 合并自动启动游戏。

## Self-verification results

### 合并、资源与未提交改动

- `git merge-tree --write-tree github/main feat/brewing-bgm` 成功，返回树 `d22bd83c5a1b6682269284a6598b44836c8af5c1`。本地主线已快进至 `b972242`，然后无冲突合入 `6763c29`；没有人工解决冲突或更改实现。
- 在暂存本记录之前，`git diff --cached --exit-code feat/brewing-bgm --` 通过，证明全部受 Git 管理的游戏文件与已验收音频分支一致。最终仅额外新增本行动记录。
- 四项最新剪词、原料投入/取出及上一版选词音效的项目文件、指定源文件及素材清单 SHA256 全部相符。
- 音频工作区四份未提交文件 SHA256 与执行前快照一致，原分支和工作区保持不变。默认 BGM 音量 60% 的未提交调整没有进入 main。
- `git diff --cached --check -- scripts docs/actions` 通过；原样导入的第三方许可证不改写空白。

### 自动回归

主线工作区最初没有 Lupa 和 urhox-libs 测试依赖，首次执行分别报告模块缺失。通过仅对测试进程设置 `PYTHONPATH=D:\taptap\To-the-Human-World-bgm\.tmp\b1-python` 与 `LUA_PATH=D:/taptap/To-the-Human-World-bgm/?.lua;;`，复用已安装依赖；游戏脚本和测试均仍从主线工作区加载，没有安装包或修改项目代码。

- `run_brew_action_sounds.py`：BrewActionSoundsTest **634** 断言通过。
- `run_brewing_audio.py`：BrewingAudioTest **589** 断言通过。
- `run_object_sounds.py`：ObjectSoundsTest **804** 断言通过。
- `run_scene_music.py`：SceneMusicTest **149** 断言通过。
- 用 `content_test_runtime.run` 分别执行 LetterPresentationTest、LetterReaderTest、LetterRenderTest：**8080 / 14 / 129** 断言通过。
- 完整 `run_letter_presentation.py` 中额外的 PaperConsistencyTest **未通过**：第 58 行访问不存在的 `activePanel`。在未改动的 `feat/brewing-bgm` 上单独执行相同测试，复现同一失败；不是本次合并产生的差异。本轮不修正该通用布局测试，也不声称整套纸面回归通过。

### 运行与交付边界

用户本轮反馈“测试没问题”是合并前已验收分支的游戏内验证依据。主线预览合并前后均为 stopped，本轮未启动游戏、操作实际存档或进行人工试听。推送对象仅为 GitHub `refs/heads/main`；合并提交及远端最终 SHA 以交付回执和实际远端为准。
