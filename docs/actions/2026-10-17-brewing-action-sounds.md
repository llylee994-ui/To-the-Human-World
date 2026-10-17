# 炼药选料与投料音效接入

## Status and situation

Completed。七项音效接入及自动检查完成，2026-10-17 用户在重新启动本分支游戏后反馈“测试没问题”，并授权将本组改动本地提交到 `feat/brewing-bgm`，不推送、不合并 main。工作区为 `D:\taptap\To-the-Human-World-bgm`，起点 b0ddcd2。已有未提交的 MusicSettings 默认 60%、SceneMusicTest、两份相关行动文档保持原样，不纳入本组音效提交。

实际入口：BrewView 原料选择；点击及拖拽投料共用 BrewInteraction.Commit / Update 飞行完成；BrewRecipe 药槽详情移除；WordTrayDrawer 的工作台托盘通过模型适配入口取出词卡。旧 Panels.Brew 保留无动画入口。复用 ObjectSounds 的独立 Effect 声源池和现有音效偏好，不能叠加通用点击声或操作 BGM。

## Implementation measures

1. 记录已有脏文件及既有音频 SHA256；七份 WAV 原样复制到 `assets/audio/sfx/objects/`，生成独立清单，保存指定 CREDITS、sources.json 及对应许可证，保留外部原始试听包，不导入 reference/preview.wav。
2. 以 UI 层专用音效适配器调用现有 Drop / TakeOut / Edit；核对成功及前后实际变化。托盘 word_remove 与药槽 word_withdraw 在入口区分；清空只发单次汇总声音。
3. 有动画的投料将一次性回调绑定到现有飞行对象，实际抵达后调用；飞行取消、失效、换页及销毁直接丢弃。无动画路径在成功后立即发声。不改动画时长、曲线或业务规则。
4. 原料只在用户实际选中时发声；重复点击收起、刷新、拖拽后的合成点击静默。
5. 新增必要的交互专项及已有音频/工作台回归，核对文件一致性和 Lua 诊断。分开记录自动检查、实际运行与人工听感。

## Affected file tree

- `scripts/ui/landscape/ObjectSounds.lua`：七项资源映射。
- `scripts/ui/landscape/BrewActionSounds.lua`：成功/实际变化判断及一次性投料反馈。
- `scripts/ui/landscape/BrewInteraction.lua`：现有飞行抵达事件调用反馈，无定时补播。
- `scripts/ui/landscape/BrewView.lua`、`BrewRecipe.lua`、`Panels.lua`：原料选择、投放、两个词卡取出入口、清空及无动画入口装配。
- `scripts/ui/landscape/tests/ObjectSoundsTest.lua`：旧物件音效资源名单适配。
- `scripts/ui/landscape/tests/BrewActionSoundsTest.lua`、`scripts/ui/landscape/tests/run_brew_action_sounds.py`：新增七音效交互专项及运行入口。
- `assets/audio/sfx/objects/`：七份 WAV（见下表）、`brewing-actions-manifest.json`、`brewing-actions-CREDITS.md`。
- `assets/audio/sfx/objects/sources/2026-10-16-brewing-actions/`：原始 `CREDITS.txt`、`source/sources.json`、`source/licenses/kenney_impact-sounds-LICENSE.txt`、`source/licenses/kenney_rpg-audio-LICENSE.txt`、`source/licenses/small-splash.html`。
- 本行动文档：范围、证据与限制。

## Self-verification method

- 逐文件 SHA256 与源文件一致；所有既有音频与预存哈希一致，四个已有脏文件保持字节一致。
- 真实 Lua UI/业务回调与隔离存档/音频适配器验证七项声音、点击与拖拽、落锅时机、失败/重复/空操作、取消/换页/销毁、静音/音量及 BGM 连续性。
- 运行既有工作台、物件声音、场景音乐与入口音频回归；EmmyLua 检查本次改动无 Error。
- 预览状态初始 stopped。遵守项目规则，不仅因代码修改自动启动；如未实际原生运行或人工试听，交付中明确列出。

## Self-verification results

### 2026-10-17 自动检查

- 七份 WAV 与用户指定源文件 SHA256 全部一致；全部为 44.1 kHz、单声道、16-bit PCM，单文件增益 1.0，单次不循环。没有重新混音、归一化或变速。
- 源 CREDITS.txt、sources.json、三份对应许可证原样复制；外部试听包未修改，reference 和 preview.wav 未导入。资源明细与哈希见 `assets/audio/sfx/objects/brewing-actions-manifest.json`。
- `.tmp/verify_brew_actions_assets.py`：PASS。事前快照中的 75 个路径（全部既有音频目录文件与四份既有未提交文件）均保持字节一致，包含主页、海边、炼药三个 BGM 文件。
- `run_brew_action_sounds.py`：PASS，395 断言。执行真实 Lua UI 回调与业务命令，存档、时钟和音频设备使用隔离适配器；覆盖七种声音、点击/拖拽投料、两种词卡移除入口、混合多项清空、空操作、失败保存、禁用、重复操作、合成点击、实际抵达、变更飞行时长、取消/失焦/长帧/遮挡/失效/离页/尺寸变化/销毁、静音/音量及 BGM 播放与停止计数。
- 原有回归全部通过：BrewWorkbench 188、ObjectSounds 764、BrewingAudio 585、UiActionSounds 463、SceneMusic 149 断言。最终原料卡指针事件调整后复跑 BrewWorkbench，仍为 188 PASS。
- EmmyLua LSP 检查本次八个 Lua 文件：0 Error。诊断记录含 156 条 Warning，不作为全项目无 Warning 的证明；完整记录 `.tmp/brew-actions-lsp/diagnostics.json`。
- 实现阶段 `git diff --check` 通过，当时未暂存或提交；本地交付授权及范围见下文。

新增专项在调试测试驱动时曾因词卡类别页未选中、点击驱动遗漏 pointerDown 而失败；已改为使用真实分类切换和完整点击事件。原料卡也补齐无拖拽绑定情况下的新点击重置，避免旧拖拽抑制标记延续到下一次真实点击。以上结果为修正后的完整运行结果，不将测试驱动失败当作业务失败。

### 触发位置与清理

运行时路径均为 `audio/sfx/objects/<文件名>`；实体文件在项目 `assets/audio/sfx/objects/`，不读取外部素材绝对路径。

| 操作 | 文件名 | 实际触发位置 |
| --- | --- | --- |
| 选择原料 | ingredient_select.wav | BrewView 原料卡 onClick 实际切换为该原料时；收起详情不响，拖拽合成点击被抑制 |
| 投入原料 | ingredient_add.wav | BrewActionSounds.Drop 确认数量增加，BrewInteraction.Update 当前飞行实际完成时调用 arrived；Panels.Brew 无动画入口成功后立即播放 |
| 取出原料 | ingredient_remove.wav | BrewRecipe 原料详情取出一份、Panels.Brew 取出入口，经 BrewActionSounds.TakeOut 确认数量减少后 |
| 投入词卡 | word_add.wav | 工作台托盘点击投放、拖拽投放均进入同一 Drop/飞行完成路径；无动画调用成功后立即播放 |
| 取出词卡 | word_remove.wav | BrewView 给工作台 WordTrayDrawer 的模型适配入口，TakeOut origin="tray" 成功移除后 |
| 撤回词卡 | word_withdraw.wav | BrewRecipe 药槽详情的撤回入口，TakeOut origin="slot" 成功移除后；旧 Panels.Brew 药槽入口相同 |
| 清空投料 | draft_clear.wav | BrewView/旧 Panels.Brew 的清空入口，BrewActionSounds.Clear 确认从非空变为空后，仅一次汇总声音 |

投料反馈回调只挂在现有 flight 对象上，没有额外计时器。实际完成时先移除 flight 再调用一次性回调；回调核对可交互状态、同一订单、同一 revision 与同一投料快照。取消、离页、销毁等现有清理直接丢弃 flight；遮挡清理先于该帧飞行更新，防止遮挡同帧补响。原动画时间、曲线、业务规则与 BGM 代码未调整。

### 原生运行与人工听感

实现阶段修改前后 `taptap-maker preview status` 均为 stopped / process_alive=false，同一 session、reload_id=1，当时没有启动预览。自动回归执行了真实 Lua 模块，但音频声源使用测试适配器，因此该阶段自动检查不代表原生游戏声音已验收。

随后用户明确要求重启游戏。2026-10-17 已启动当前工作区本地预览，session 为 `389698d4-017c-49c0-81a5-d120e89eb1a6`。进程及“寄往人间”窗口存在，窗口截图确认开始界面正常显示；原生日志确认七份音效资源均下载完成。这些启动证据不等于七项实际交互均由助手验证。

用户随后明确反馈“测试没问题”，作为本组音效的人工游戏内验收依据。没有额外推断逐项测试过程或移动设备结果，也没有用网页试听或素材包试听替代游戏内验收。

### 本地提交范围

2026-10-17 用户授权仅本地提交七个炼药音效相关的代码、资源、来源说明、测试及本记录。使用明确路径暂存；不纳入先前降低默认 BGM 音量的四份未提交文件，不纳入 `.tmp` 运行截图和日志。沿用上文已通过的自动回归，本轮仅更新交付记录与执行提交核对，没有修改实现或重复运行整组测试。不推送，不合并 main。

提交前复核：资源校验脚本再次 PASS，75 个受保护路径字节一致；暂存路径与本组 24 文件清单完全一致。暂存代码及自写文档的 `git diff --cached --check` 通过，原样导入的许可证文本不做空白修整。提交前本地 main 为 `20feb459d1c34ced8dc2a9dd3b45f53130312ccd`。
