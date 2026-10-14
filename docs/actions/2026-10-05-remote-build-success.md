# 2026-10-05 远端构建首次成功与预览核对

> 状态：Completed（提交与远端构建成功；正文版本差异如实记录，未修改任何内容文件）
> 起因：用户要求走完整流程——同步最新 main、检查 Lua、使用 Maker 官方流程提交构建、留下提交号与回执、打开预览核对新正文。

## 一、实施措施与证据

1. **同步 main**：`git fetch github` 与 `git fetch origin`。本地 main 与 `github/main` 一致；`origin/main` 落后 1 个提交（本地 10-05 日志）。检查全部远端分支：`github/fengyycon` 与 `origin/main` 相对本地 main 均为领先 0 个提交，无未合并工作；本地工作区干净。
2. **检查 Lua**：依次执行 `scripts/debug/run_b1.py`～`run_b6.py`。
   - B1 130、B2 212、B3 387、B4 339、B5 373、B6 104 + 170 按钮适配，**合计 1715 项、0 失败**
   - `run_story_content.py`：1265 项、0 失败（reachable 16/16、future-pure 9/9、matrix 9/9）
   - `logs/lua_diagnostics.log`：Errors 0 / Warnings 1（`WordToken.lua` 的表索引推断误报，该处 `U.Keys` 确实可能返回失败，防御性检查必要，未改）
3. **提交构建**：调用 Maker 官方入口 `maker_build_current_directory`，未使用通用 git 提交或推送流程。
4. **预览**：`taptap-maker preview start`，竖屏 1080×1920。

## 二、构建回执

| 项 | 值 |
|---|---|
| 提交号 | `207f5c6` |
| 提交状态 | `status=pushed`，`committed=no`（工作区干净，未新建提交） |
| 分支 | `main` |
| 构建参数 | `entry=main.lua`、`scriptsPath=scripts` |
| 远端构建 | **成功**，`remote_build` 进度至 100%，`elapsed 19s`，15 条进度事件 |
| 预览刷新 | `preview_refresh` 返回 200 |
| Maker 地址 | https://maker.taptap.cn/app/76909fb8-3dc3-4adc-8c49-fe56bab4393e |
| 本地 watcher | 已启动（pid 26608）；`state.json` 连续失败 0、无错误 |

> 此前两次失败原因本次均未复现：`branch_not_allowed`（当时交付走分支，本次在 main）、
> `local_build_context`（本地构建上下文无法解析 user_id）均未出现。绑定与账号配置未改动。

## 三、预览核对的运行证据

预览会话日志显示：

- `=== 寄往人间 启动完成（第 1 天）===`，阶段 0 自检 12 项通过
- 竖屏布局尺寸 575 × 1022（窗口 1080 × 1920，`defaulted=false`）
- 内容校验通过，`contentVersion = story-v0.4-r1`
- 引擎既有资源错误（`Cube/Day/DaySpecularHDR.dds`、`themis_x64.dll`）仍在，与脚本无关
- 玩法界面 `ui/PlayView` 已在 `CreateUI` 中挂载

## 四、正文版本差异（重要，本轮未处理）

`scripts/debug/check_elias_copy.py` 失败 3 项。定位结果：**运行配置落后定稿文档一版**。

- `scripts/data/letters.lua` 最后修改 **10-05 13:51**（`968cc9a`）
- 定稿文档 `docs/文案/开场与首封来信_定稿_v01.md` 在 **10-05 14:51 / 14:59** 更新
  （`6323e83`、`1e75e92`，含「首信落款补门牌号」与第八篇组合并入）
- 具体差异：定稿地址为「灰港铁锚巷12号 二楼」，运行配置仍为「灰港铁锚巷」；
  定稿的核心句在运行配置中不存在

**该切换并非遗漏**：`scripts/新稿阅读与收取变体_程序交接契约.md` 明确新稿需要新增
`signature` 与 `emphasis` 字段，属待内容侧确认后实施的接口扩展（该契约自述「旧运行版不伪装成已接新稿」）。
因此**本次构建包含的是 13:51 版正文，不是最新定稿**，`check_elias_copy.py` 的失败正是这一缺口的守卫。

## 五、边界

- 不宣称 A1～A19 通过。本轮只做同步、回归、提交构建与预览启动，未做人机走查。
- 手机、官方环境、强制关闭与断电等场景未测。
- 构建成功不等于玩法验收通过；正文版本差异按第四节如实记录，未修改任何内容或运行配置。
- 本轮未改动账号配置、未重跑初始化、未切换或重置任何分支。
