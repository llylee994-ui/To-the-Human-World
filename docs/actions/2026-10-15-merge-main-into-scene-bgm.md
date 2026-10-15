# 合入 main 到音乐分支

## Status and situation

Completed（自动合并、相关专项回归、Lua 诊断与本地启动检查完成；实际交互和听感仍由用户验收）。用户授权尝试把 `main` 合入当前 `feat/scene-bgm`，方向为 main → 功能分支。本轮只做本地合并与验证，不更新或推送 main，也不推送功能分支、不触发 Maker 远程构建。

- 工作目录 `D:\taptap\To-the-Human-World-bgm`，开始时工作区干净、HEAD `3bd94aab5f773b4ff057cf346b655802e8fbf49f`。
- `origin` 是 GitHub `https://github.com/llylee994-ui/To-the-Human-World.git`；已获取最新 main `e3da8e223d70071f180e31b4414f0a58d748cc91`。
- 共同祖先 `7f1f6d44b6d9d56166ced231afedac17d217eb3f`；音乐分支独有 3 个提交，main 独有 5 个提交。main 内容为来信抽屉、美术排版、完整心愿句独立字重及项目版本 1.0.15。
- `git merge-tree --write-tree HEAD origin/main` 已通过，无冲突，候选 tree `2eb18a13e34c7440bdd625a7bbab3b82053d74a8`。首次部分克隆缺文件对象且受限网络下载失败，获准本机网络上下文补齐后预检成功，尚未因此修改工作区。

## Implementation measures

1. 在当前干净分支执行保留双方历史的合并，先不提交，以便检查实际内容与回归。
2. 检查共有 AppView/main 生命周期：音乐初始化、设置与销毁保留；来信抽屉的 Update/Reset/render 分支及心愿字重保留。开发探针保持关闭。
3. 运行音乐、来信抽屉、信纸呈现与相关 HUD/商店回归，检查可用 Lua 诊断与差异。
4. 更新本记录，形成本地合并提交。若本地预览仍存活，刷新一次并收集同轮日志；停止会话不自行重启。

## Affected file tree

- `scripts/main.lua`、`scripts/ui/landscape/AppView.lua`：自动合并共同入口、字体和页面生命周期。
- main 的来信相关代码与测试：`LetterDrawer*`、`LetterEmphasis`、`LetterLayout`、`LetterPaper`、`Panels`、`DevChecks`、相关 tests。
- `assets/image/letter-drawer-v01/`、`assets/fonts/HarborHand-Medium*`、字体 README：保留 main 原样资源。
- `.project/project.json`、`scripts/actions/2026-10-15-letter-*.md`：保留 main 的版本与已完成行动记录。
- `docs/actions/2026-10-15-merge-main-into-scene-bgm.md`：此次整合记录。
- main 共 59 个路径的变化；音乐专用模块与两首 WAV 不作业务修改。

## Self-verification method

- `git merge-tree`、合并父节点与目标祖先检查、`git diff --check`。
- `run_scene_music.py`、`run_letter_drawer.py`、`run_letter_presentation.py`、`run_home_hud.py`、`run_shop_view.py`；隔离测试存档，不自动操作真实业务。
- 本机 EmmyLua 检查本轮整合的 Lua 文件；原生 preview status/refresh/logs/check，与专项断言和用户试听分开报告。

## Self-verification results

- `git merge --no-ff --no-commit origin/main` 成功，无冲突；实际暂存树与预检 tree `2eb18a13e34c7440bdd625a7bbab3b82053d74a8` 一致（尚未加入本记录时）。未作人工代码调整。`git diff --name-only --diff-filter=U` 为空，`git diff --cached --check` 通过；没有额外未暂存的受跟踪文件修改。
- 逐项核对 main/AppView 自动合并结果：新增 story-strong 字体；保留音乐设置初始化、单声源场景同步、设置保存和 Stop/Destroy 释放；接入 LetterDrawer 的渲染、Update、Reset 与遮罩关闭。所有 DevChecks 开关保持 false。
- 本轮重新执行 `python -X utf8 -B scripts/ui/landscape/tests/run_scene_music.py`，144 项通过；`run_letter_drawer.py` 98 项通过；`run_letter_presentation.py` 中 PaperConsistency 23、LetterPresentation 8080、LetterReader 14、LetterRender 71 项均通过；`run_home_hud.py` 52 项、`run_shop_view.py` 51 项通过。测试均使用隔离适配器，未修改玩家存档或音乐偏好；这些是逻辑及渲染接口检查，不替代真实窗口交互或设备听感。日志位于忽略目录 `.tmp/main-merge-checks/`。
- 本机 EmmyLua 服务检查本轮 19 个 Lua 文件，结果 0 Error、102 Warning；未声称警告清零。诊断及被检查源码 SHA256 位于 `.tmp/main-merge-lsp/diagnostics.json`，客户端 `.tmp/check_main_merge_lsp.py`，摘要 `.tmp/main-merge-checks/lsp.log`。
- 实时 `preview status` 确认原会话仍运行后刷新一次；session `cb51635c-a02c-477d-9624-7b12ed593c58`、reload 1、PID 44940、项目资源版本 1.0.15。2026-10-15 20:07:21.828（Asia/Singapore）日志显示“寄往人间 启动完成”；LetterDrawer/LetterEmphasis、SceneMusic/MusicSettings/MusicSettingsView 均已加载，新增 Medium 字体已取得。读取该轮日志至 cursor 467 未发现新增脚本错误。Windows 进程检查确认对应本机运行器窗口有响应；未自动操作真实玩法或更改音乐设置。
- `preview check` 仍为 FAIL，原因与刷新前相同：`Cube/Day/DaySpecularHDR.dds` 和 `themis_x64.dll` 缺失。此结果与专项通过、游戏启动分别记录；未修改外部运行器或把进程存活当成完整玩法验收。
- 合并保留双方历史，本记录随本地合并提交一并保存。来源为 main `e3da8e223d70071f180e31b4414f0a58d748cc91`，功能分支原头为 `3bd94aab5f773b4ff057cf346b655802e8fbf49f`。本地 main 保持 `81baa45d6c754cee5ba2ef03d2fd0ec9928622f9`，未进行任何推送；其他工作树保持不动。未运行远程构建、手机验收或全量业务回归。
