# 剪词、原料水声与炼药词卡选择音效

## Status and situation

Completed（接入、自动检查及用户游戏内验收）。用户已确认三个 water-and-scissors-v2 文件与上一版 word_select。工作区 `D:\taptap\To-the-Human-World-bgm`，分支 `feat/brewing-bgm`，实现起点 `7a85fa0`。2026-10-17 用户在重启游戏后反馈“测试没问题”，授权将本组改动本地提交、推送 GitHub，并尝试将最新 main 合入此分支；不合并回 main。

保留已有默认 BGM 音量 60% 的四份未提交文件。既有原料投料已通过 BrewActionSounds 判定实际成功，再由 BrewInteraction 飞行完成回调播放；取出亦已有前后数量检查，本轮不另加播放点。剪词入口为 LetterPresentation.Cut；炼药托盘由 BrewView 装配 WordTrayDrawer。所有声音复用 ObjectSounds，保持音乐声源与用户音效设置。

## Implementation measures

1. 保存既有音频、代码保护范围与未提交文件哈希。三份新版素材导入 objects/water-and-scissors-v2 子目录，word_select 从指定上一版导入 objects 根目录；替换原料资源映射，保留旧 WAV 及历史清单。四份复制 SHA256 必须一致，不改混音、电平、采样率或速度。
2. 在剪词成功、changed=true 且现有动画实际开始后单次播放 word_cut。沿用原有动画时长，不按音频长度阻塞。无效、失败、重复及被拦截操作静默。
3. 在炼药托盘的实际选中回调按 tokenId 判断切换，复用已有拖拽抑制；其他页面的托盘不播放 word_select，不改变投入、取出、撤回音效。
4. 保存来源、处理与许可证说明；不导入试听页面、preview.wav 或 reference。
5. 执行真实 Lua 交互与业务模块的隔离音频回归、LSP、资源哈希和差异检查。分开报告自动检查、原生运行及人工听感。

## Affected file tree

- `scripts/ui/landscape/ObjectSounds.lua`：新增剪词/选词映射，原料映射切换新版资源。
- `scripts/ui/landscape/LetterPresentation.lua`：实际剪词成功与动画开始边界。
- `scripts/ui/landscape/BrewView.lua`：仅在工作台装配的词卡点击回调上增加反馈，按 tokenId 比较实际选中前后状态；共享 `WordTrayDrawer.lua` 未修改。
- `scripts/ui/landscape/tests/BrewActionSoundsTest.lua`：扩展既有专项，增加剪词及按实例选卡、版本路径、静音/音量和边界检查。
- `scripts/ui/landscape/tests/ObjectSoundsTest.lua`：按新版时长和资源子目录更新音频设备适配器，补充测试类型注解。
- `assets/audio/sfx/objects/water-and-scissors-v2/`：三份新版 WAV。
- `assets/audio/sfx/objects/word_select.wav`：指定上一版 WAV。
- `assets/audio/sfx/objects/paper-water-manifest.json`、`paper-water-CREDITS.md`：明确四项当前资源映射、来源、SHA256、格式与原有混音处理记录。
- `assets/audio/sfx/objects/sources/2026-10-17-water-and-scissors-v2/`：原样保存 `CREDITS.txt`、`source/sources.json`、`source/retrieval.json`、`source/licenses/scissors-cutting-paper-4-routenote.html`、`source/licenses/small-splash.html`。
- `assets/audio/sfx/objects/sources/2026-10-17-paper-cut-and-soft-brewing/`：原样保存 `CREDITS.txt`、`source/sources.json`、`source/licenses/kenney_rpg-audio-LICENSE.txt`。
- 本行动文档：执行及分层验证记录。

## Self-verification method

- 四份 WAV 源/目标 SHA256、44.1 kHz/单声道/PCM16 与时长；保护清单中的 BGM、其他音频、既有未提交文件均字节一致。
- 自动回归覆盖模型成功/失败/无变化、动画开始与到达、重复剪词、按 tokenId 选卡、拖拽合成点击、初始化/恢复/刷新、音效静音和音量、BGM 不被停止或重启。
- Lua LSP 无 Error，差异中无玩法、存档、音乐或其他音效触发修改。
- 初始本地预览 stopped。若交付时仍停止，不仅因改代码而复活；若正在运行，按项目规则刷新并读取日志。未运行和未试听如实说明。

## Self-verification results

### 资源与保护范围

`.tmp/import_paper_water.py` 复制后校验通过；`.tmp/verify_paper_water.py` 复核通过。四份成品均与指定外部源文件字节一致，44.1 kHz、单声道、PCM16，时长分别为 1.04 / 0.68 / 0.72 / 0.18 秒。word_select 确认来自指定上一版目录。八份来源记录/许可证原样复制，没有导入试听页、preview.wav 或 reference 音频。

97 个保护清单路径字节一致，包括全部原有音频、BrewActionSounds/BrewInteraction/LetterMotion/SceneMusic/SoundSettings 等未修改逻辑，以及四份既有未提交文件。两个旧原料 WAV 与原历史来源清单继续保留，本轮通过 ObjectSounds 映射选取新版，不覆盖旧素材。

| 操作 | 运行时路径 | 实际触发位置 |
| --- | --- | --- |
| 剪取词语 | audio/sfx/objects/water-and-scissors-v2/word_cut.wav | LetterPresentation.Cut：模型返回 ok 且 changed，既有 motion.Start 成功后调用一次 PlayObjectSound；文件中的三剪不拆分为三次播放 |
| 投入原料 | audio/sfx/objects/water-and-scissors-v2/ingredient_add.wav | 原有 BrewActionSounds.Drop 成功/数量增加校验，BrewInteraction.Update 当前 flight 抵达回调；旧 Panels.Brew 无动画成功路径立即播放，均未增加第二处播放点 |
| 取出原料 | audio/sfx/objects/water-and-scissors-v2/ingredient_remove.wav | 原有 BrewActionSounds.TakeOut 成功且数量减少之后，调用和业务流程未改 |
| 选择词卡 | audio/sfx/objects/word_select.wav | BrewView 给工作台词卡安装的 onClick，在原选择回调实际改变 tokenId 后播放；沿用 ClickAllowed 与拖拽抑制，仅适用于炼药工作台 |

剪词动画仍为原来的 1.0 秒，音频 1.04 秒不会延长它或阻止下一次合法剪词。剪词拒绝禁用、遮挡、过渡忙碌、失效来源、失败保存、changed=false 和已销毁/关闭阅读页面。选词卡拒绝重复 tokenId、禁用、遮挡及拖拽合成点击；新的真实点击会重置拖拽抑制，包括已投入而不再绑定拖拽的词卡。初始化、刷新、恢复、取消选择和主页托盘浏览不触发选词声。

### 自动执行结果

| 检查 | 实际结果 |
| --- | --- |
| `python scripts/ui/landscape/tests/run_brew_action_sounds.py` | PASS，634 断言；覆盖剪词、选词及既有七项操作、点击/拖拽、实际落锅、失败/重复/取消、静音/音量、BGM 播放停止计数与销毁清理 |
| `python scripts/ui/landscape/tests/run_object_sounds.py` | PASS，804 断言；现有物件声及资源池、独立声道回归 |
| `python scripts/ui/landscape/tests/run_word_tray.py` | PASS，64 断言；共享托盘浏览、选中和状态不写存档 |
| `.tmp/run_paper_water_reader.py` | LetterPresentationTest 8080、LetterReaderTest 14、LetterRenderTest 129 断言全部 PASS；真实 Lua 纸面/动画/点击代码，隔离渲染适配器 |
| `python scripts/ui/landscape/tests/run_brew_workbench.py` | PASS，188 断言 |
| `python scripts/ui/landscape/tests/run_brewing_audio.py` | PASS，589 断言 |
| `python scripts/ui/landscape/tests/run_ui_action_sounds.py` | PASS，475 断言 |
| `python scripts/ui/landscape/tests/run_scene_music.py` | PASS，149 断言；包含保留的默认 60% 本地改动 |
| `.tmp/check_paper_water_lsp.py` | 本次五个 Lua 文件诊断完成，0 Error；诊断汇总含 50 条 Warning，不宣称全项目无 Warning。记录 `.tmp/paper-water-lsp/diagnostics.json` |
| `git diff --check` | PASS |

专项最初因新增多个隔离视图后，将早已销毁的音乐声源也纳入“当前静音”断言而失败；调整为检查仍在播放的音乐声源后完整通过。该问题来自测试范围，未改动音乐实现。随后仅补充测试类型注解并复核 LSP，未重复执行无行为变化的整组测试。

同词不同实例的选卡用例在真实查询结果副本中加入同词的第二个 tokenId，仅用于视图选择；未伪造玩家存档。其余投料、取出、剪词的成功/失败由真实业务模块与隔离存储执行。测试音频设备记录 Play/Stop、资源路径、增益与循环状态，不等于原生扬声器播放或人工听感验收。

### 原生运行及人工试听

实现阶段前后预览均为 stopped / process_alive=false，session `389698d4-017c-49c0-81a5-d120e89eb1a6`、reload_id=0，该阶段没有执行新版本的原生交互或人工试听。

随后按用户明确请求重启当前工作区，session `68d26256-9f8b-4e79-895c-7dda8444a7d3`。实际窗口截图显示主页，原生日志确认本次四份确切资源加载完成。用户随后反馈“测试没问题”，作为本组音效的游戏内人工验收依据；不推断未提供的逐项测试步骤或移动端结果，不以素材包或网页试听替代游戏内验收。

### 2026-10-17 提交、推送与合并授权

按明确路径提交本组代码、四份资源、来源说明、测试及本记录。此前降低默认 BGM 音量的四份未提交文件不纳入提交，保持原样；`.tmp` 截图、日志及辅助脚本不提交。提交前再次执行资源/保护清单核对，全部 PASS；沿用已通过的回归与用户验收，不重复无代码变化的整组测试。

本次仅向已核对的 GitHub remote `github` 推送 `feat/brewing-bgm`；不向 Maker 的 `origin` 推送或构建。已获取最新 GitHub main，接下来在保护未提交改动的前提下进行合并预检和必要回归。合并结果另行记录，不更新 main 分支。
