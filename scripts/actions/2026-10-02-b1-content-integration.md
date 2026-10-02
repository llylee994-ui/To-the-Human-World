# B1：同步 C1～C3 并继续接入

## 状态与背景

Completed（本轮同步与 C1 接口接入检查完成；完整 B1 仍 Blocked）。用户要求“拉取代码，继续”。基线 fengyycon@2e9252a，上一轮 B1 程序实现及原 docs/actions 均未提交，必须保留。origin 实际是 GitHub；本轮 fetch 后快进 origin/main=6789bb0，当前 fengyycon 与本地 origin/main 无提交差异。未提交、推送或远端构建。

提交前复核与后续修复（2026-10-02）：原复核发现 R2，F8 读取测试进度后保存会覆盖默认玩家槽；现已统一 F8 和 write/read 的隔离入口，在载入前绑定测试槽，失败也保持隔离。新增 8 个入口/按钮场景、原 130 项及三种配置门禁通过；本次 LSP 0 Error / 2 Warning，实际窗口按键复验待补，预览已停止且未重启。本次未提交推送；详见[评审、修复与证据](2026-10-02-b1-content-review.md)。下文原接入过程与历史验证结果保留。

远端只与本地 `scripts/B1_存档恢复与最小账本实施计划.md` 的状态行重叠；先将该单文件本地改动存入具名 stash，快进同步，再合并状态事实。其他 Lua 改动和未跟踪文件不暂存、不覆盖。同步后核对所有原本地改动摘要。

上一轮 V13 已定位当前 Maker 本地预览会删除临时 savedata，本轮不将拉取内容当作该环境问题已解决。不修改 Maker 安装文件或内容数据，不伪造持久化证据。

## 实施措施

1. 保全本地改动、同步 6789bb0，核对内容包及更新后的 B0/B1 约定。
2. 用现有 Lua 5.4 环境运行真实 Data.Load/ValidateStage1 和 Economy 初始化，复现配置接口差异。
3. 按 B1 接入真实 C1 和账本校验/恢复；完整 v2 仍须有真实模块恢复器，不能造空壳升级。
4. 补真实配置正常/错误样例和账本保存恢复检查；遵守 P5 保留正式 v1，完整模块未就绪前不引入其他快照格式。
5. LSP、专项回归、当前窗口状态与差异核对；保持 V13 环境限制单独列出。

## 影响文件树（实际）

```text
scripts/
├─ main.lua / core/GameState.lua          两级内容校验与具体错误门禁
├─ systems/Economy.lua                   C1 校验、错误码与账本恢复
├─ debug/EconomyTest.lua                 实际 C1 正常/错误样例
├─ debug/SaveSystemTest.lua              实际账本保存恢复
├─ debug/run_b1.py                       三种配置失败的独立启动检查
├─ debug/B1RunRequest.lua                实机专项临时开关，交付前恢复 off
├─ B1_存档恢复与最小账本实施计划.md        同步双方状态
├─ actions/2026-10-02-b1-implementation.md  标记历史缺口已被本记录更新
└─ actions/2026-10-02-b1-content-integration.md 本记录
```

`data/` 与 `docs/` 仅接收远端内容，未自行改写；没有删除项目文件。Economy 仍是纯候选计算模块，GameState 为整体恢复协调器，SaveSystem 协议未在本批修改。

## 自验方法与结果

已快进到 fengyycon@6789bb0；其余 18 个原本地改动/未跟踪文件摘要一致，无冲突。计划状态行已合并双方事实，单文件备份 stash `76506890` 暂保留。拉取后原 Lua 5.4 + File/UI 替身回归为 97/97。

已用真实 Data 的七个 errorSamples 复现错误码/缺字段差异，再修 Economy 开局校验并接入口 Data.ValidateStage1。开局原料表须显式列出当前配置中的原料份数（未赠送可填 0），从材料定义读取 ID，不硬编码四种材料；恢复库存允许合法缺省项，不重新套开局要求。

真实 C1 账本已通过 Economy 公共恢复接口及专用 `b1_c1_ledger` 槽的 Lua 5.4 检查。完整 Envelope 的其余业务块仍使用明示的技术夹具；此项不能证明正式入口已经恢复完整 v2。生产仍沿用 v1，不另造混合版本或生产假模块。

已追加 `debug/run_b1.py` 的独立配置失败启动检查，验证新 Data.ValidateStage1 失败能阻止存取/跨天并保留诊断。

本轮修复前：新增 C1 检查后为 120 项中 13 个断言失败，七例的错误码全部不符，缺原料竟返回 OK；证据 `logs/b1-c1-before.log`。修复后：130/130 通过，另三种独立启动故障（Data.Load、C1 缺金币、Data.ValidateStage1）均正确拦截读档/写入/跨天并显示诊断。LSP 首轮 1 Error/3 Warning 均位于测试代码，修复复查已为 0 Error / 0 Warning（20:21:18）。

按已授权 P6，运行单次真实窗口专项（仅 b1_* 槽），真实 File 上的 C1 往返及本轮配置提示已验证。临时使用既有 write 诊断开关，结束已恢复 off 并在活跃会话刷新。

### 最终验证与边界

| 检查 | 本轮实际结果 |
|---|---|
| 同步与保全 | `git fetch origin` 后 `git merge --ff-only origin/main`，HEAD=6789bb0；没有 merge/rebase 冲突。状态行单独合并，其余原改动在拉取前后 18 份摘要相同。具名 stash 仅保留旧状态行备份，内容事实已合回，不存在待应用的程序代码。 |
| 真实 C1 | 开局候选读取当前配置：金币 30、四种原料各 3、仅旧锅、无特殊物品。七个错误样例均返回约定 code 与字段路径；不补默认金币、不放行缺料。没有修改 data。 |
| V7 接口/存储层 | 完整技术 Envelope 的 economy 使用真实 C1；使用明确的技术请求“某材料 1 份、奖励 1 金币”，保存 31 金币和剩余 2 份后恢复，未重新赠送物资。其余业务块仍是夹具，正式默认 v1 尚不持有账本，不能标为完整正式 v2 恢复通过。 |
| Lua 5.4 替身回归 | `python -X utf8 scripts/debug/run_b1.py`：130/130，原逻辑自检 11/11。[日志](../../logs/b1-c1-lua54.log)。 |
| 三种配置门禁 | 同一 runner 分别加 `--config-failure load`、`c1`、`stage1`：独立运行均通过，错误诊断保留、存取/跨天被拒绝，即使直接调用按钮回调也不能写默认槽。仅测试替身证据，未冒充真实错误窗口检查。日志为 `logs/b1-c1-gate-*.log`。 |
| 真引擎 File 与窗口 | session `98eb3697-9d20-4786-ba98-325c4e18a42a` / reload 0 / PID 1560，20:23:24 专项 130/130；原自检含布局 12/12。[真实 File 日志](../../logs/b1-c1-engine.log)、[实际窗口](../../logs/b1-c1-window.png)。实看主界面与面板都是第 5 天，可打捞 false，字体及内容校验提示可读。 |
| LSP | 使用现有 maker-lua-lsp watch / emmylua_ls 检查 scripts，最终 0 Error / 0 Warning（20:25:22）。[诊断](../../logs/lua_diagnostics.log)。没有用脚本静默退出当作检查通过。 |
| V13 | 本轮未重跑，沿用上一轮已定位的失败：Maker 刷新删除临时 game_path/savedata。仍需持久运行环境与最终移动端验证；130 项通过不能替代退出重进。 |
| 预览环境 | DownloadInitialPackage 一度没有新日志，之后继续进入脚本。Cube/Day/DaySpecularHDR.dds 和 themis_x64.dll 诊断再次出现，`preview check` 为 FAIL，不能声称预览整体全绿。正常 off 刷新到 reload 1 / PID 48752 后因本次 240 秒测试时限停止，未拿到该次正常启动完成证据，未再次启动。[刷新日志](../../logs/b1-c1-normal.log)。 |

收尾：诊断开关为 off，保留用户文件，`scripts/data` / 已跟踪 `docs` 无本地差异，原未跟踪 docs/actions 摘要未变；`git diff --check` 通过。日志/截图均为被忽略的本机证据，不加入提交。

下一批接口已可使用 `Economy.InitialSnapshot/ValidateSnapshot/Restore/GetSnapshot/PlanSettlement`。C2/C3 已经到位，但 Potion/Order/WorldState/Narrative 尚未运行联合验证，也未据此冻结内容版本。B2～B4 真实模块恢复器接齐后才启用完整 v2；当前不增加生产假模块，也不把存档故障重启能力与整单确认幂等混为一项验收。
