# 音频分支与 main 整合

## Status and situation

Completed（内容整合与提交前专项检查完成；下文明确保留未完成的整套结局流程回归和实机验收边界）。用户于 2026-10-16 授权先尝试 main → feat/scene-bgm，成功后将该分支合入 main；延续当前 GitHub 交付上下文，同步两个 GitHub 分支，不触发 Maker 远程构建。本记录随合并提交保存；提交之后的分支交付结果以 Git 引用及独立远端回执核对。

- 工作目录 `D:\taptap\To-the-Human-World-bgm`，开始时工作区干净。功能分支及 GitHub 对应分支均为 `08cafcd31dd1b31136708b9b4b2feec3310a685a`。
- 已 fetch 最新 GitHub main `6bbeefc7c190a76db4b46fec08f92b8763e4016e`；本地 main 为 `81baa45d6c754cee5ba2ef03d2fd0ec9928622f9`，未在其他工作树签出。
- 共同祖先为 `e3da8e223d70071f180e31b4414f0a58d748cc91`。main 新增两个提交，涉及结局文案、资源元数据与项目版本，共六个路径。
- `git merge-tree --write-tree HEAD origin/main` 无冲突，候选树 `26e7704a1277faf3dac0c9b0e21e2598fb697d58`。音频代码未与 main 新改动重叠。
- 不改写已接受的音频设计或 main 文案，不操作其他工作树与玩家存档。实际听感与手机验收保持原有边界。

## Implementation measures

1. 在功能分支执行保留双方历史的 main 合并，检查暂存树、冲突与保护路径。
2. 对合并内容执行音效/BGM/船票/结局保存专项回归；核对当前预览状态，仅在运行时刷新并读取启动证据。整套结局流程回归的中止原因单独记录，不计为通过。
3. 记录真实结果，提交合并；确认 main 是结果祖先后，将 main 快进到已验证的合并结果。
4. 使用非强制的明确分支推送同步 GitHub feat/scene-bgm 与 main，并独立读取远端 SHA 验证。

## Affected file tree

- `.project/project.json`：接纳 main 的项目版本。
- `assets/fonts/HarborHand-Medium-source.json.meta`、`assets/fonts/HarborHand-Medium.ttf.meta`、`scripts/ui/landscape/LetterEmphasis.lua.meta`：接纳 main 的资源元数据。
- `docs/文案/结局/普通剧情首发_三结局正文_v01.md`、`scripts/data/release_endings.lua`：接纳 main 已提交的结局内容，不人工改写。
- `docs/actions/2026-10-16-scene-bgm-main-integration.md`：新增本次整合记录。
- 音频资源、播放模块、音量设置与 UI 触发点：沿用已提交功能分支内容，不新增业务改动。

## Self-verification method

- `git merge-tree`、冲突文件列表、暂存树、差异检查、双方祖先关系及远端 SHA。
- 已有 `run_ui_action_sounds.py`、`run_object_sounds.py`、`run_scene_music.py`、`run_travel_ticket.py` 与结局相关隔离回归；按实际执行记录结果。
- 可用 Lua 静态检查与预览状态核对；不把自动检查或启动证据等同于用户听感验收。

## Self-verification results

- `git merge --no-ff --no-commit origin/main` 成功，无冲突；正式合并暂存树与预检 `26e7704a1277faf3dac0c9b0e21e2598fb697d58` 一致。冲突列表为空，`git diff --cached --check` 通过；无人工代码合并或文案调整。
- 受保护的音频目录、入口、播放/设置与交互模块逐项对比功能分支原头，无差异；六个 main 引入路径逐项对比 `origin/main`，无差异。
- 首轮六组隔离回归受到沙箱 `.tmp/b1-files-*` 访问拒绝影响：初始化存档自检、音乐持久化和临时目录清理报错，不能视为通过。已核对测试 File 适配器只使用项目临时目录，随后在正常本机权限下重跑同一批脚本，不修改测试或游戏逻辑。
- 正常权限下重跑已完成：按钮音效 386 项、物件音效 584 项、BGM 144 项、船票 47 项，均退出 0，日志在 `.tmp/audio-main-integration-checks/`。其保存失败、余额不足等主动注入日志保留；不将这些预期失败分支视为用例失败。
- `python -X utf8 -B scripts/debug/run_release.py --suite ending-saves` 在正常权限下独立执行，24 组通过、0 失败、退出 0；初始化存档自检 11 项通过、0 失败。使用隔离临时目录，不写玩家存档。
- `--suite endings` 首轮受沙箱影响的进程和随后正常权限长跑均主动停止，未取得整组最终结果，不能报告通过。核对 `ReleaseEndingFixtures.New` 后确认它会替换正式结局文案；长耗时为 7/8/11 三星订单路线的完整模拟。本次实际 main 差异只有正式文案/元数据/版本，未改订单或结局状态逻辑，因此将必要验证收束为已通过的专项、正式文案与 main 的逐文件一致性以及 Lua 检查；未修改测试来跳过断言。
- EmmyLua 检查结局配置及七个既有音频相关文件：8 个文件、0 Error、143 Warning。证据 `.tmp/audio-main-integration-lsp/diagnostics.json`；未声称警告清零。
- `taptap-maker preview status --target-dir D:\taptap\To-the-Human-World-bgm --json` 返回 stopped、process_alive=false；因此未刷新或重新启动游戏。没有本轮原生交互、听感或手机实机结果。
- 本地 main 已确认是最新远端 main 的祖先，功能分支合并树包含双方提交。交付采用 main 快进到已检查的结果，保持功能分支签出及其他工作树不变；GitHub 使用明确的两个分支引用、非强制原子推送，完成后再读取远端 SHA。
