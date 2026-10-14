# B1 内容接入提交前评审

## 状态与背景

原评审 Completed；R2 程序修复与隔离回归 Completed，实际窗口按键复验待补。原用户要求核对 [B1 内容接入记录](2026-10-02-b1-content-integration.md)，没问题则提交推送；后续用户要求修复 R2，本次仅修复与验证，不执行提交推送。

基线：`fengyycon@6789bb0eff2e5632338c83cdae58b8216e74b4b0`，相对本地 `origin/fengyycon` 领先 3 个提交；B1 程序及两份行动记录仍在未提交工作区，暂存区为空。实际 `origin` 是 GitHub。此次没有获取远端新状态，不能将本地引用当成实时远端核验结果。

完整 B1 尚未验收、正式 v2 等待真实模块恢复器、V13 受 Maker 预览清理临时存档影响，均是已声明的交付边界，本身不构成本次新增问题。原评审发现独立测试隔离缺陷 R2，故当时未提交；后续已按用户请求修复并补回归，证据见文末。本次没有据此执行提交推送。原 R1 评分契约问题已经关闭，不重复打开。

原评审应用 project-control-report、code-review-skill 和 action-document，只核对、复现与记录；以下保留原评审事实。后续程序修复范围、技能及验证见文末；未修改配置或设计规则，未启动预览、远端构建或发布。

## 实施措施

1. 对照 B0 v0.2、B1 P1～P6 与两份实现记录，检查实际入口、保存协议、整体恢复、最小账本及测试代码。
2. 重新运行现有 130 项回归及三种配置失败启动检查，区分运行权限问题与项目错误。
3. 对漏测的 F7/F8/保存按钮组合做独立复现；通过实际 `main.HandleKeyDown` 与按钮回调调用，File/UI 使用测试替身，默认槽仅存在于内存。
4. 记录可操作的修复及验收要求，给原接入记录增加本次评审入口；保留原历史结果。
5. 检查文档、原文件摘要、HEAD 和暂存区；有 R2 时不执行 commit/push。

## 影响文件树

```text
scripts/actions/
├─ 2026-10-02-b1-content-review.md       [新增] 本次问题、复现及提交结论
└─ 2026-10-02-b1-content-integration.md  [追加] 链接本次提交前评审
```

其余既有文件只读；不删除文件。GameState 仍是整体状态协调入口，DebugPanel 通过注入回调保存；本次问题恰好位于测试载入与保存槽绑定的衔接处。

## R2 · P1：F8 载入测试进度后，“保存”仍写默认玩家槽

**位置：** [main.lua](../main.lua) 的 `HandleKeyDown` F8 分支（当前 289～291 行），关联 [DebugPanel.lua](../debug/DebugPanel.lua) 的 `testSlot_`（32 行）、保存按钮（138 行）和 `SetTestSlot`（196 行）；测试读取入口为 [SaveSystemTest.lua](../debug/SaveSystemTest.lua) 的 `ReadRestartFixture`（277 行起）。

**触发与实际结果：** 普通 `B1RunRequest="off"` 启动，已有默认槽第 3 天。按 F7 写入隔离夹具，按 F8 读取，再点击调试面板“保存”。F8 通过正式 `LoadProgress` 安装第 5 天、`mainStoryStage="b1_fixture"`、`deliveredOrders=2`，但没有绑定 `b1_restart_flow` 槽。`testSlot_` 仍为 nil，因此保存回调实际写 `slot1`，覆盖玩家正常进度。面板标题也仍是普通“调试面板”，没有隔离槽提示。

**影响：** 测试夹具污染正式存档，还会带入无订单明细的非零发货计数，后续 v2 迁移会因此要求额外处理。这违反 B1 P1 的隔离槽约束。诊断配置开关为 off 并不会关闭这些快捷键；现有 130 项检查没有覆盖 F8 后点击保存的组合。

**独立复现：** 通过 `python -X utf8 -` 运行 Lua 5.4（工程现有 lupa），加载实际 main、GameFlow、SaveSystem、GameState、DebugPanel 与重启检查函数。只替换 File/cjson/UI/事件注册，不替换上述业务逻辑。File 为 Lua 内存 map，绝不访问真实玩家存档。

1. 用实际 SaveSystem 在内存默认槽预存 `{gameFlow={day=3,phase="day",canSalvage=true,mainStoryStage="prologue",deliveredOrders=0}}`。
2. `Start()`；依次调用 `HandleKeyDown` 的 F7 与 F8 分支，事件字段 `Key:GetInt()` 返回相应测试枚举。
3. 调用 UI 根节点 `debugSaveButton` 的真实 `onClick` 回调。
4. 用实际 `SaveSystem.Load(nil)` 读取内存默认槽，与步骤 1 比较。

实际输出：

```text
[review R2] after F8 day=5 stage=b1_fixture
[review R2] panel title=调试面板（Z 键开关）
[review R2] default slot before day=3 stage=prologue deliveredOrders=0
[review R2] default slot after day=5 stage=b1_fixture deliveredOrders=2
[review R2] default slot preserved=false expected=true
```

反例脚本成功捕获问题，退出码 0 表示复现完成，不表示缺陷通过验收。这是实际 Lua 调用链的测试替身证据，不是引擎键盘输入或真实文件验证。

### 修复与复验要求

将 F8 与配置 `write/read` 的测试载入收敛到统一隔离入口：**在任何夹具状态可能安装之前**，绑定并显示 `b1_restart_flow`，让随后保存、读取和跨天均停留在明确的测试上下文。读取或夹具断言失败也必须保留隔离，不能回落为 nil/default 槽。

增加经过实际快捷键和按钮回调的回归：

- 默认槽已有正常存档：F7 → F8 → 保存，默认槽内容不变，面板明确显示测试槽，保存仅落在测试槽。
- 默认槽不存在：同样操作不能创建默认槽。
- 测试重启档缺失或 v2 夹具损坏：失败后不能将已加载的测试流程写进默认槽；诊断可读。
- 现有 130 项与三种配置门禁仍通过；修改 Lua 后按项目规则补 LSP，实际预览/输入验证单独记证据。

原评审未代为修复。该修复属于程序入口和调试隔离，不需要文案重新定数值或补剧情；后续修复记录见文末。

## 自验方法与结果

| 检查 | 本轮结果 |
|---|---|
| `python -X utf8 scripts/debug/run_b1.py` | 授权在沙箱外重跑成功：专项 130/130，阶段 0 逻辑自检 11/11，退出 0。File/UI 为既有测试替身。 |
| `--config-failure load` / `c1` / `stage1` | 三个独立进程均通过，每次原逻辑自检 11/11，错误诊断、存取和跨天门禁断言通过，退出 0。 |
| 最初沙箱内尝试 | 四个进程均遇到 `.tmp/b1-files-*` 的访问拒绝和清理失败，不能作为项目断言失败或成功证据。未改 ACL 或测试实现；相同脚本在沙箱外重跑得到上两项结果。 |
| R2 独立复现 | 已复现正式默认槽被测试进度覆盖；全程内存存储，未访问真实槽。 |
| 代码静态核对 | v1 保留、v2 恢复器门禁、账本纯计算及内容错误检查与已声明边界相符；本次新增阻止提交的问题为 R2。 |
| 真引擎 / LSP / V13 | 本轮未重新运行，未启动游戏。原接入记录中的真实 File 130 项、LSP 0/0 均为历史证据；V13 仍未通过。 |
| 文档、摘要、Git 范围 | 两份记录的 10 处本地链接存在，UTF-8、围栏配对及行尾空白检查通过，`git diff --check` 通过。56 份原文件中仅接入记录追加本次链接，其余 55 份摘要相同；只新增本评审记录。HEAD 仍为 6789bb0，暂存区为空，未提交推送。 |

## 原评审下一步（修复前记录）

先修复 R2 并按上面的入口组合补回归，复核通过后再提交推送本批 B1 基础代码。之后推进 B2 的 Letter/WordToken（收信、已读、剪裁位置、词条实例与来源、恢复接口）；B3 纯计算可按既定分工并行。B2～B4 补齐真实模块恢复器后启用完整 v2，V13 在保留 savedata 的真实运行环境补验收。内容同学继续配合 C2/C3 联合验证，本问题不要求修改配置。

## R2 修复行动（2026-10-02，后续请求）

### 状态、范围与依据

Completed（程序修复与隔离回归；真实窗口输入仍待复验）。继续使用 project-control-report、action-document，并应用 diagnosing-bugs 的先复现再回归流程。既有评审已经定位槽绑定遗漏，先复跑精确反例，再针对该调用链修复；未额外展开无证据的广泛假设排查。

修改前记录了 57 个非忽略文件的 SHA-256，现有 B1 未提交实现、内容配置和主页图片全部保留。Lua 指南与示例 14/15/17 已在本会话完整读过；此次读取当前 main、调试入口、恢复协调器、专项检查与 runner，并对照 B1 P1/P2/P6。没有 CONTEXT/相关 ADR。所有程序改动限于 scripts，data/docs 只读。

### 实施措施与实际影响文件树

1. 在既有 Lua 5.4 runner 增加真实快捷键/按钮组合的隔离回归入口，先观察默认槽被覆盖的失败；测试默认槽仅存在于 runner 的独立临时目录，不访问真实 savedata。
2. 将 F8 与配置 write/read 汇入同一入口，任何夹具安装前先绑定并显示 b1_restart_flow；失败也不解除绑定，并在面板保留诊断。
3. 验证有/无默认档、测试档缺失、v2 夹具损坏、write/read 配置入口，保存/读取/跨天均保持隔离；原 130 项和三种配置门禁回归。
4. 按 Maker 本地流程查询预览状态，只刷新活跃窗口，不重启已停止会话；运行实际 LSP，区分替身检查与真实窗口输入/文件证据。
5. 回填 R2 结果并更新接入记录中的问题状态，核对本轮差异和原文件保护；不提交、推送、构建或修改诊断开关。

```text
scripts/
├─ main.lua                              [修改] 统一测试载入与先绑定后安装
├─ debug/DebugPanel.lua                  [修改] 隔离入口说明
├─ debug/SaveSystemTest.lua              [修改] 重启夹具失败的明确诊断
├─ debug/DebugIsolationTest.lua          [新增] 实际快捷键/按钮组合回归
├─ debug/run_b1.py                       [修改] 隔离场景的独立运行入口
└─ actions/
   ├─ 2026-10-02-b1-content-review.md     [修改] 保留原评审，追加本次修复证据
   └─ 2026-10-02-b1-content-integration.md [修改] 同步 R2 状态并链接本记录
```

GameState 仍是实际存取/状态协调器，DebugPanel 持有当前调试槽，main 负责在显式进入测试上下文时先绑定它。测试不绕开这些生产路径，也不伪造整体 v2 恢复器。

### 自验方法与结果

精确反例 `python -X utf8 scripts/debug/run_b1.py --debug-isolation existing` 已在修复前失败：F8 后为第 5 天，标题仍是普通调试面板，保存按钮触发 `R2 DEFAULT_SLOT_CHANGED`，退出 1。首次沙箱内运行因临时文件访问被拒而未完成；同一命令授权在沙箱外重跑才得到上述项目断言失败。测试仅访问自身临时目录。

修复后的共同入口 `RunB1RestartCheck` 先调用 `SetTestSlot` 并显示面板，再执行检查或读档。F8、配置 write/read 均使用此入口；pcall 捕获夹具失败后保留槽绑定，将具体失败写入面板。`ReadRestartFixture` 补流程档/待确认夹具的明确诊断；实际存取仍走 GameState。没有改动诊断配置开关或生产存档协议。

| 检查 / 命令 | 本次实际结果 |
|---|---|
| `python -X utf8 scripts/debug/run_b1.py --debug-isolation <场景>` | 8 个独立进程通过：`existing`、`missing`、`flow_missing`、`v2_corrupt`、`auto_write`、`auto_read`、`auto_read_flow_missing`、`auto_read_v2_corrupt`；全部退出 0。流程状态安装的同步事件已观察到隔离标题和可见面板；实际按钮保存/读取/跨天保持测试上下文。 |
| 默认槽保护 | 比较默认槽 5 个候选文件（legacy、a/b 快照及 a/b 提交标记），有档时内容逐文件相同，无档时仍无默认文件。检查失败后也点击实际保存按钮，不仅检查报错。 |
| 失败诊断 | 流程档缺失与 v2 夹具损坏的快捷键、自动 read 场景均通过；不向引擎抛出断言，面板日志明确指出对应夹具，保持 `b1_restart_flow`。调整损坏夹具构造为写后读回核对后，两个受影响场景再次通过。 |
| 原 runner / 三种配置门禁 | `python -X utf8 scripts/debug/run_b1.py`：130/130、阶段 0 逻辑 11/11、`runtimeError=false`；`--config-failure load` / `c1` / `stage1` 各自通过诊断及存取/跨天拦截断言，退出 0。[本次输出](../../logs/b1-r2-after.log)。以上均为 Lua 5.4 + File/UI 替身，存档只在隔离临时目录。 |
| Lua LSP | 运行本机 `maker-lua-lsp --mode watch --path D:\taptap\To-the-Human-World\scripts --output-dir D:\taptap\To-the-Human-World\logs\r2-lsp --ls-path <现有 emmylua_ls.exe> --enable-system-log`；本次新鲜诊断 21:02:48 为 **0 Error / 2 Warning**。[诊断](../../logs/r2-lsp/lua_diagnostics.log)。初轮 4 条警告中的新脚本两条已消除；剩余位于 SaveSystemTest 的未修改断言（180、185 行），运行回归通过，未把类型诊断当成实际断言失败。启动日志另有 `.emmyrc.json` 不存在及 LSP 内部日志文件拒绝访问提示，但已收到各文件及最终工作区诊断，不能据进程退出码宣称 0/0。本次启动的 watch 已正常清理。 |
| Maker 预览 | 修改后两次 `taptap-maker.cmd preview status --target-dir D:\taptap\To-the-Human-World --json` 均为 `stopped / process_alive=false`，session `98eb3697-9d20-4786-ba98-325c4e18a42a`、reload 1；按项目规则没有重启。本次未运行真实窗口 F7/F8/鼠标输入、真实 File 重启或布局验收。 |
| 范围及 Git | 本次仅修改树中列出的 6 个既有文件并新增 DebugIsolationTest.lua；其余 51 个原文件 SHA-256 不变，包括内容配置和原未提交资料。诊断开关仍为 off；HEAD 保持 6789bb0、暂存区为空，未提交推送。日志仅存被忽略的本机 logs。最终文字/链接与 `git diff --check` 检查见收尾核验。 |

### 收尾核验与后续

`git diff --check` 通过；两份行动记录 UTF-8、围栏配对、行尾空白与 12 处本地链接检查通过，runner Python 语法检查通过。收尾重新比对 57 个原文件摘要，确认仅上列 6 个修改、51 个不变，新增文件只有 DebugIsolationTest.lua；HEAD 与暂存区保持原状。

代码修复及隔离回归完成。真实窗口输入在下次已启动的预览会话补验；V13 的持久运行环境限制、完整 v2 恢复器和整单玩法仍按原计划处理，本修复不改变这些状态。无需文案重新定规则或修改配置。此次没有新的提交、推送或远端构建动作。
