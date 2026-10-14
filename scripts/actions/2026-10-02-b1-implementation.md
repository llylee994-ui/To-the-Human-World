# B1 P1～P6 实施记录

## 状态与背景

Blocked（程序技术项已实施；完整模块恢复与 V13 尚未完成，完整 B1 尚未验收）。用户要求执行 [B1 计划](../B1_存档恢复与最小账本实施计划.md) P1～P6，依据 B0 v0.2；不实现订单、炼药、剧情或商店，不改 scripts/data 与 docs，不提交推送。

后续更新：C1～C3 已于本日同步到 fengyycon@6789bb0，真实 C1 校验及账本接口接入结果见[内容接入记录](2026-10-02-b1-content-integration.md)。下文保留首次实施当时的基线、配置缺口和运行证据；其中“C1 未交付”不再是当前阻塞。完整业务模块恢复器与持久环境验证仍未就绪。

基线 fengyycon@2e9252a，跟踪 origin/fengyycon；实时 GitHub 同名分支一致，main=a171d93。工作区仅原 docs/actions 未跟踪；已保存 40 个原文件摘要。Lua 相对 a171d93 无变化。个人汇报、行动记录、diagnosing-bugs 与 Maker 本地预览流程适用。此前已完整阅读 Lua 指南及示例 14/15/17，本轮复查 File 声明和存储约束。

C1 尚未在工作区出现；已询问配置交付位置。缺真实初态时仅交付技术层与明确标注的夹具，不猜金币/剧情，不将空壳升级成 v2。

## 实施措施

1. P1：隔离槽 b1_recovery，显式调试入口复现启动层级、false、调试读取；记录失败后再修。
2. P2：GameState 统一恢复与保存，全部校验后安装；SaveLoaded 刷新两处天数；失败保护当前状态。
3. P3：受保护编码、可靠文件协议、可辨识读档状态和故障测试；证实协议后接默认槽。
4. P4：最小 Economy 的校验/深副本/纯结算；C1 就绪才初始化真实账本。
5. P5：完整 B0 结构验证及旧档迁移边界；未接模块明确拒绝运行恢复，无生产假模块。
6. P6：Lua LSP、现有自检、真实 File 隔离槽、窗口和重启；记录环境错误与未验证项。

## 实际影响文件树

```text
scripts/
├─ main.lua                              修改：统一入口、状态提示、调试检查
├─ core/GameFlow.lua                     修改：合法流程恢复，保留 false
├─ core/SaveSystem.lua                   修改：完整快照存取与错误语义
├─ core/GameState.lua                    新增：整体校验、保存、安装与通知
├─ core/StateUtil.lua                    新增：纯表副本、合法数据与错误工具
├─ core/SaveSchema.lua                   新增：完整 Envelope 结构验证
├─ systems/Economy.lua                   新增：最小库存/货币账本
├─ debug/DebugPanel.lua                  修改：注入统一回调与错误提示
├─ debug/SelfTest.lua                    修改：专项入口及旧自检兼容
├─ debug/B1RunRequest.lua                新增：显式诊断模式，交付值 off
├─ debug/SaveSystemTest.lua              新增：恢复与文件故障回归
├─ debug/EconomyTest.lua                 新增：账本检查
├─ debug/fixtures/B1Fixtures.lua         新增：隔离且标记的技术数据
├─ debug/fixtures/HeadlessUI.lua         新增：文本测试替身，不能作视觉验收
├─ debug/run_b1.py                      新增：Lua 5.4 隔离回归入口
├─ B1_存档恢复与最小账本实施计划.md       修改：更新实际执行状态并链接本记录
└─ actions/2026-10-02-b1-implementation.md 新增：本记录
```

不删除已有文件。运行日志/截图归本地忽略目录；如果需额外测试工具，在此记录。状态由各模块持有，GameState 用公开接口协调，EventBus 只通知。

## 自验方法

- P1 修改前失败证据与修复后相同测试；操作经过实际入口，逐项输出输入/实际/期望。
- F6 显式运行隔离检查，保存并恢复测试前内存；故障注入不跟随普通启动。
- 真实引擎 File 与注入存储失败分别测试，V1～V14 分层记录。
- 当前 preview status 为 stopped；用户本轮执行 P6 授权本地窗口测试，使用明确 target-dir。每批改动检查会话，活着才 refresh，停止后不因改动自动复活。
- 实际 LSP 诊断、git diff --check、内容/图片/其他文档摘要保护检查；不提交或构建。

## 自验结果

实施中。P1 已用 Lua 5.4 + 明确的 File/UI 测试适配器复现：启动 day=1（期望 5）、false 变 true、调试读取 day=6（期望 5）、主标题和面板均未显示第 5 天；5 个断言全部失败。原逻辑自检 11 项通过。修复前的真实预览原自检 12 项通过，但 F6 输入未成功送达，不冒充真实引擎三项复现。

新增测试辅助：`debug/run_b1.py`（隔离文件目录、Lua 5.4 runner）和 `debug/fixtures/HeadlessUI.lua`（仅检查文本，不作视觉证据）。Lua 解释器使用本工程忽略目录 `.tmp/b1-python` 的 lupa 2.6；未全局安装。单次 LSP check 缺 emmylua_check，改用既有 EmmyLua LS。

真实预览再次出现 Cube/Day/DaySpecularHDR.dds 缺失与 themis_x64.dll 加载失败。窗口 safeArea/mainPanel 545×970；历史 12 项不代表资源诊断全绿。首个定时预览会话已停止，后续按 P6 明确授权重新执行重启测试。

### 保存协议的技术决定

两个 payload（a/b）与各自提交记录交替使用。候选写完、关闭、读回一致后才写提交记录；加载按最高完整提交代数，绝不按修改时间选候选。旧 `save_<slot>.json` 保留，默认 schema 仍为 1。此协议不依赖未经证明的 Rename 原子性，也不宣称 Flush 等于物理断电持久化。

普通 Save 结果保持 boolean + 结构化错误。唯一例外：提交记录写入后介质持续拒绝读取，无法诚实判定成功/失败。SaveSystem 抛结构化 `SAVE_COMMIT_UNCERTAIN`，GameState 捕获并锁定保存/推进，必须重新 Load 对账；不作为可直接重试的普通失败。完整记录能读回时，即使 WriteString 报 false/抛异常，也按真实提交成功返回 true。这是对 P3 不确定边界的显式协议补充；相关故障用例待运行。

正式 C1、完整初态与未实现玩法恢复器仍缺失。生产保持 v1 流程；账本和完整 Envelope 结构只在技术夹具中验证，禁止以空对象升级正式档。

### 真实窗口补充发现

窗口确实正常显示中文与配置缺失提示，但 Z/F6 无效果；发送输入后没有专项日志。核对 `examples/05-super-mario-game.lua` 和 `urhox-libs/UI/Core/UI.lua`，实际事件字段用 `eventData["Key"]:GetInt()`，旧入口使用 `eventData:GetInt("Key")`。按本地示例改读事件字段，同步改 TimeStep；此项为 P6 调试入口实际可用所必需，修后再测，不先宣称原因已证实。`.tmp/b1-window.ps1` 仅定位本项目 PID+中文标题并验证焦点，向真实窗口发送测试键、截取窗口，不作为生产脚本。

修正字段后自动发送按键仍未产生专项日志，不能将输入方法失败归因于已修复的存档代码。Maker 本地能力文档明确不提供输入自动化。增加 `debug/B1RunRequest.lua` 显式诊断开关（交付默认 off）：仅人工指定 write/read/error 运行时，在首帧布局后执行专用槽测试；普通启动不进行故障注入。主界面增加调试面板按钮，便于竖屏点击；不增加玩法功能。测试时记录每次开关值，结束恢复 off。

## 最终执行与验证记录

### 程序接口与兼容边界

- `GameFlow.ValidateSnapshot/Restore/GetSnapshot` 只处理五个流程字段；缺省与非法值分开，显式 false 保留。恢复返回值和读取快照均与内部状态隔离。
- `GameState.New` 默认只启用 v1，统一 `Load/Save/NextDay`。读取返回 `data, {status, schema?, error?}`；new/loaded/migrated/corrupt/unsupported/migration_required 与配置/对账门禁分别处理。失败不安装、不发 SaveLoaded、不自动另存。调试回归会恢复流程、协调器状态和门禁。
- `Economy.New(content)` 读取统一内容形状；`InitialSnapshot/ValidateSnapshot/Restore/PlanSettlement` 返回 B0 Result。金币/份数是非负整数（JSON 可精确表达范围）；合法投料份数为正整数。设备使用 ID→true 集合；特殊物品使用 B0 的实例 ID→`{itemId,sourceLetterInstanceId,available}`。`PlanSettlement(...).value={state,delta}`；输入与正式账本不变，无保存和奖励事件。
- `SaveSchema.ValidateV2(data,{contentVersion,synthesisVersion,economy})` 进行完整块、false 哨兵、版本/基准、配方、八步 trace、候选账本和确认记录/归档一致性检查。没有对应真实模块的恢复器时 GameState 拒绝安装。World 字段语义、事实来源、词条消耗合法性、允许的世界差异仍由后续真实模块验证，结构检查不能代替 B5。
- v1→v2 显式迁移接口只在完整初态有效、旧发货数为零时生成候选；非零无明细返回 MIGRATION_REQUIRED。当前生产入口不请求升级，旧 JSON 原文件保留。后续不能绕过 GameState 的锁定去重试不确定提交。
- C1 尚缺：`contentVersion`、`stage1.initialEconomy`（尤其金币）、`stage1.initialEquipmentId`；C3 完整世界初态及其余业务恢复器未就绪。无正式开局账本、无真实订单确认/重置。

### 实际运行结果

| 验证 | 结果与证据范围 |
|---|---|
| V1～V3 | 通过。修改前 Lua 5.4 + File/UI 替身 5 个断言失败；修后同一路径通过。真实 File 专项通过，SaveLoaded 一次。真实窗口点击“结束当天”后两处为 6，再点击标明 `b1_restart_flow` 的“读取”后两处为 5、canSalvage=false。 |
| V4 | 通过。new/corrupt/unsupported 分别识别；拒绝覆盖坏档。真实 error 诊断窗口显示“存档损坏…未知字段，保留原档”，保存/结束当天按钮灰置，读取保留。 |
| V5～V6 | 通过（进程内故障注入和新 reader 选择）。包括不可编码值、循环、稀疏数组、WriteString false/异常/部分写、快照读回不一致/异常、提交前后中断、完整提交但写者报错、不确定提交锁定及重新读取对账。基础存储是真实 File；故障由包装器精确注入。此处的 reader 重建不等同 OS 进程重启。 |
| V7 | 未完成真实 C1。技术初态与缺金币拒绝检查通过；金额 17/奖励 2 和 test_* ID 仅在夹具中。未代写内容配置或发开局物资。 |
| V8～V9 | 通过。重复试算确定、库存/输入不变；非法用量/未知原料/重复行/重复特殊实例/非法奖励拒绝；GetSnapshot 和 Restore 返回值不能改内部状态。 |
| V10 | 通过技术分支。缺完整初态、孤立发货数拒绝迁移；完整技术初态可生成迁移候选。真实迁移未启用。 |
| V11 | 通过结构/存储层。accepted/brewing/pending 技术夹具往返一致，版本/基准/缺字段/非法星级/不一致账本/未知块被拒绝。未实现真实待确认玩法。 |
| V12 | 通过。未知业务块保留原档，缺恢复器拒绝；测试替身恢复器中途失败后回滚全部已变动块，通知 0 次；配置错误和提交不确定时禁止推进/保存。 |
| V13 | **失败，已定位预览环境原因。** 原进程确实写入文件，但 Maker 刷新清空其整个临时 game_path；新进程 `RESTART_OBSERVED status=new day=1 error=nil`。不能将此项标为通过。 |
| V14 | 原逻辑自检 11/11、真实窗口布局后累计 12/12；最终专项 Lua 5.4 替身检查 97/97、真实 File 97/97。实际 EmmyLua LS 最终 0 Error / 0 Warning。 |

本地命令：`python -X utf8 scripts/debug/run_b1.py`；`maker-lua-lsp --mode watch --path <工程>/scripts --output-dir <工程>/logs --ls-path <现有 emmylua_ls.exe>`；所有 Maker preview run/refresh/logs 均显式指定工程绝对路径。LSP 首次在沙箱内未实际刷新诊断，识别后通过授权运行已有 LS，使用新时间戳结果；没有把旧日志当新验证。

真实 File 最终 97 项：session `fcb50519-b37d-439c-b94e-785b89e1498d`，reload 0，PID 66436，2026-10-02 19:56:08。本地证据：

- [Lua 5.4 替身回归](../../logs/b1-lua54.log)、[最终真实 File 回归](../../logs/b1-engine-final-write.log)、[LSP 诊断](../../logs/lua_diagnostics.log)。
- [点击跨天后的第 6 天](../../logs/b1-button-day6.png)、[实际读取恢复第 5 天](../../logs/b1-button-restored5.png)、[坏档提示与禁用按钮](../../logs/b1-error-ui.png)。均为实际窗口截取，不是无头 NanoVG 图。
- [重启失败日志](../../logs/b1-engine-restart.log)、[错误模式日志](../../logs/b1-engine-error.log)。日志和图片在忽略目录，仅本机可用，不提交引擎或测试产物。

### V13 原因与仍未完成的工作

实际找到的测试文件位于：`C:/WINDOWS/TEMP/maker-cache-Jc4LbE/127.0.0.1_64265/53bc6793f820dabafabd01f2a928d661f2cd126dbedf85936ad451e83c106865/savedata/0/save_b1_restart_flow_a.json`（同目录有 commit 和 v2 夹具）。

已安装 Maker 0.0.36 的本地 `dist/maker.js`：56342 行每轮 `mkdtemp("maker-cache-")`，56365 行将其作为 `-game_path`，56482 行 `clearAssetCache()` 删除整个临时目录。刷新后旧路径 Test-Path 为 false；新 PID 63784 / reload 1 的实际加载为 new。故障发生在存储目录生命周期，不是单纯 Lua 层级错误。未修改 Maker 安装文件、搬运存档到新缓存或借此伪造重启通过。

仍需在保留持久 savedata 的运行环境补 V13（并最终进行移动端验证）。当前预览的保存只在本轮窗口生命周期内可用；不能以这次 PC 结果承诺手机持久性。WASM 刷新内存文件系统限制见引擎 file-storage 文档；本轮未新增服务器/云存档。

引擎 Cube/Day/DaySpecularHDR.dds 与 themis_x64.dll 诊断重复出现；另一次 official-res 清单临时下载失败导致 prepare 中止，重试成功。将这些环境问题与游戏专项结果分开记录。键盘自动输入未完成验收；鼠标按钮操作和布局已实看。

收尾：B1RunRequest 恢复 off；34 个非本轮修改的原文件（含 data/docs/图片等）摘要与基线一致；保留原 docs/actions 未跟踪内容。未提交、推送、发布或远端构建。P4 正式接入等待 C1，P5 完整运行恢复等待真实初态/模块，P6 的 V13 等待持久运行环境；无需重议已接受规则。

最终正常启动复查：session `fcb50519-b37d-439c-b94e-785b89e1498d` / reload 2 / PID 45188，19:58:29 原自检累计 12/12，无 B1 故障注入输出；[正常启动日志](../../logs/b1-normal-start.log)。最终 `git diff --check` 通过（只有既有 LF/CRLF 转换提示），分支/HEAD 仍为 fengyycon@2e9252a，data/docs/assets 的 Git 差异为空。
