# 合并最新 main 到炼药音频分支

## Status and situation

Completed（本地合并及必要回归；原有验证缺口见下）。用户要求将最新 main 合并到当前 `feat/brewing-bgm`。工作区 `D:\taptap\To-the-Human-World-bgm` 初始干净，分支起点 `f8bbc772eceb3f7900d61d7e1fea0bb1ff62f0da`；本地 main 为 `20feb459d1c34ced8dc2a9dd3b45f53130312ccd`。本轮仅在当前分支做本地合并，不推送，不合并回 main，不更新其他工作树。

已核对 github 指向目标 GitHub 仓库、origin 为 Maker。普通沙箱获取 GitHub 时本地代理连接失败，提升网络权限后 `git fetch --no-tags github main` 成功；目标为 `f8c2390128f1aac8f33c20d8094ff8134c290e79`。分支与 main 共同祖先为 `20feb459d1c34ced8dc2a9dd3b45f53130312ccd`，两侧新增提交数为 1 / 4。`git merge-tree --write-tree HEAD github/main` 预检无冲突。

## Implementation measures

1. 固定已获取的 GitHub main 提交，使用 `git merge --no-ff --no-commit` 合入当前分支。
2. 保留上游剧情数值、需求提示、信件表现及素材/历史文档；保留当前分支入口音效、炼药 BGM 与音效增大调整。音频模块与上游没有重叠修改。
3. 对合并结果运行必要的音频、入口和界面回归；检查修改的 Lua 诊断，核对音频文件与合并前一致。
   音频专项的成功配方仍按旧版本只投词条；最新 main 的首单见证配方新增夜露原料。专项需根据真实配方采购缺少的原料并逐份投料，保持生产配方和业务流程原样。纸面套件的旧面板假设失败另做基线复现，不据此更改游戏 UI。
4. 更新本记录后创建本地合并提交，核对两个父提交、分支、工作区和 main 引用。预览检查显示当前已停止，不因本次合并自动启动游戏。

## Affected file tree

- `scripts/data/numeric_v02.lua`、`release.lua`：导入 main 的剧情数值和平衡配置，不另行编辑内容。
- `scripts/systems/Order.lua`、`PlayQueries.lua`：导入 main 的普通剧情判定和需求查询变更。
- `scripts/ui/landscape/LetterPaper.lua`、`PotionNotes.lua`、`PotionNotesView.lua`：导入 main 的信件表现和炼药需求提示。
- `scripts/debug/`、`scripts/ui/landscape/tests/LetterRenderTest.lua`：导入 main 的测试与夹具更新。
- `scripts/layout-editor/`、`scripts/主页排版工程文件/`、`scripts/素材/`、README 和相关 docs/scripts 文档：完整合入 main 现有版本，不作额外改写。
- 当前音频分支的 `AppView.lua`、`ObjectSounds.lua`、`SceneMusic.lua` 和全部音频资源：保持 f8bbc77 的内容；其余音频专项保持原样。
- `scripts/ui/landscape/tests/BrewingAudioTest.lua`：跟随新主线的配方原料构造真实投料，继续覆盖保存失败和炼药成功时音乐不重启。
- 本行动文档：本轮唯一额外新增文件，记录合并范围和实际验证；另有上述音频测试的兼容性调整。

## Self-verification method

- 合并后无未解决冲突；git diff 对比 f8bbc77 的音频模块、音频资源和设置为空。
- 音频三份资源清单及旧主页/海边 WAV 的 SHA256 与合并前一致。
- 运行入口炼药音频、SceneMusic、ObjectSounds、UiActionSounds、HomeZoom 及受影响界面专项。
- Lua LSP 诊断无 Error；保留 Warning 和未运行检查说明。
- 合并提交父节点为 f8bbc77 和已获取的 main；main 引用保持原值；提交后工作区干净。

## Self-verification results

- `git merge --no-ff --no-commit f8c2390128f1aac8f33c20d8094ff8134c290e79` 成功，无未解决冲突。合并结果与预检树 `462f4e29c5d62003e653cca6337ad626e3649bb4` 对比，额外改动仅为本记录及 BrewingAudioTest 配方适配。
- 全部 audio 资源、三个生产音频模块、入口 main.lua、音乐/音效设置与 f8bbc77 无差异。三份新资源 SHA256 与清单一致；旧主页/海边 SHA256 仍分别为 `29814323594388cbb660e34c4a02c26f719cf5daf1788459ff9559ebf51614d9`、`5ef34eb8badaf937d546fd8ba893acf499e062517ca23bd8ec561c94a83536b6`。
- `run_brewing_audio.py` 首次在旧测试投料下失败；根据新版配方补齐真实采购/投料，并明确断言保存错误码后，569 项通过。证据 `.tmp/merge-brewing_audio.log`、`.tmp/merge-brewing_audio-fixed.log`。只修改专项测试，没有改生产配方或交互流程。
- `run_scene_music.py` 149、`run_object_sounds.py` 624、`run_ui_action_sounds.py` 421、`run_home_zoom.py` 383、`run_brew_workbench.py` 188 项通过；日志为 `.tmp/merge-<suite>.log`。主动注入保存失败和余额不足的日志不等同于测试失败。
- `run_letter_presentation.py` 在原有 PaperConsistencyTest 第 58 行失败：旧检查假设每个入口均存在 activePanel，而实际该节点为空。使用 `.tmp/check_merge_ui.py baseline-paper` 将全部发生变化的旧 Lua 模块通过 package.preload 恢复为 f8bbc77 快照后，复现同一位置/错误，证明此失败在合并前已存在；证据 `.tmp/merge-paper-baseline.log`。本次未改该测试或相关游戏 UI。
- 被纸面套件提前中断的三个专项分别运行：LetterPresentationTest 8080、LetterReaderTest 14、LetterRenderTest 129 项通过；证据 `.tmp/merge-letter-components.log`。这些是隔离适配器检查，不能代替实际画面验收。
- `.tmp/check_brewing_merge_lsp.py` 对合并涉及的 Lua 及音频模块/专项共 23 文件检查，23 文件均收到诊断；最终 0 Error、133 Warning。证据 `.tmp/brewing-merge-lsp/diagnostics.json`。生产修改及本轮额外测试/记录的差异格式检查通过；上游历史素材、文档和许可证按既有内容合入，没有为格式检查改写历史证据。
- 当前游戏预览已停止，本轮未启动、未试听，没有进行手机或完整剧情验收。此前原生 BGM 循环属性检查未通过、长循环与完整人工试听验收尚未完成，详见 `2026-10-16-brewing-entry-audio.md`；本轮合并不将这些情况改记为通过。
- 结果以本地双亲合并提交保存，父提交为 f8bbc77 与 f8c2390；保留旧本地 main 引用，不执行推送或 Maker 构建。
