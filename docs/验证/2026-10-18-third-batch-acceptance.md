# 第三批验收：标题页进度回溯

日期：2026-10-18。验收对象：HEAD `6010d79` 之上的第三批工作区改动，包含新增的 RewindHistory、RewindView 和专项测试。

结论（2026-10-18 最新）：**两个逻辑问题及类型诊断已修复，自动回归与本地原生回溯验证通过**。手机实机仍需更新测试版后扫码验收。修复和原生探针没有操作正式存档；远端操作见本次 Maker 构建结果。

## 需要修复

### 1. 回溯后重做订单，旧确认请求能够确认新配方（高优先级）

位置：`scripts/systems/RewindHistory.lua:382-392`，关联 `scripts/systems/OrderLifecycle.lua:94-97,151`、`scripts/systems/OrderTrial.lua:140-144`。

回溯恢复了 `nextOrderSerial` 和订单内的 `nextAttemptSerial`，只提高整档 revision、重定向 pending baseline revision，没有为新分支隔离订单/试做事务。Confirm 请求只携带 orderId 和 transactionId，不检查回溯后的 revision。

复现步骤（真实业务模块、隔离存储）：

1. StartJourney，记录第 1 天恢复点。
2. 接第 1 单并预览默认配方，保留其确认请求 `{orderId, transactionId}`。
3. RestoreDay 回到第 1 天，重新接单；改用 `e01_result_mother_dream` 对应配方，生成不同的药水。
4. 发送第 2 步保留的旧确认请求。

实际输出：

```text
old transaction=order:1:attempt:1; new=order:1:attempt:1; different potion=true
old confirmation accepted=true; changed=true; delivered=1
```

预期：旧分支确认被拒绝，新的 pending 及资源保持原样。当前行为违反计划“回溯后旧回调不得影响新分支”。这需要存在旧请求/延迟回调才会触发，不能据此声称普通点击必然误发货。

修复方向：订单操作需绑定分支世代或确认时的状态版本，并在协调器拒绝过期请求；同时检查预览、重置和 UI 延迟回调。只提高整档 revision 而不让订单请求校验它，不能解决此问题。补回归应使用两个不同配方，避免误把相同事务视为安全重试。

### 2. 非旅人路线收尾会丢失轮次，第三轮被记录为第二轮（中优先级）

位置：`scripts/core/GameState.lua:516-517`，关联 `scripts/systems/ReleaseCoordinator.lua:127-128`。

BeginClosing 重建 chapter，把旧 rewind 放在结局前 checkpoint 内；StartNewPlaythrough 只读顶层 chapter.rewind。收尾/结局后顶层没有该字段，于是无论原先第几轮都按 1 计算，新轮次固定变成 2。

复现采用结局事务测试夹具的单委托集合，仍走真实 StartJourney、StartNewPlaythrough、发货、NextDay、愿望尾声、ConfirmEnding 和 StartNewPlaythrough，没有直接改写轮次：

```text
closing history=nil; checkpoint run=2
new-run after wish ending expected=3; actual=2
```

预期：第 2 轮完成后，新旅程是第 3 轮。应在收尾生命周期保留本轮身份，或读取结局前 checkpoint 中的有效轮次。现有专项只覆盖经营态直接开新局，没有覆盖第 2 轮结局后再开新局。

## 修复结果（2026-10-18）

### 1. 订单分支隔离

`chapter.rewind` 新增可选 `branch`（默认 0），每次逐日回溯、恢复回溯前备份或回到结局前都会递增。`OrderTrial.Preview` 把 `run`/`branch` 编码进试做序号，新事务 ID 不再复用旧分支的 `order:N:attempt:M`。旧确认和旧重置请求携带的 transactionId/baselineId 在新分支上不再匹配，协调器返回 `STALE_TRANSACTION`/`STALE_BASELINE` 或 `INVALID_ORDER_STATE`，新 pending 和资源保持原样。

回归加入 `scripts/debug/RewindTest.lua`：首单默认配方确认请求保留，回退第 1 天后改用 `recipe_v02_e01_2`（睡眠＋梦）生成不同药水；旧预览在草稿不匹配时被拒绝，旧确认和旧重置均被拒绝，随后新的事务可以正常确认。结果页的确认/重置按钮现在携带渲染时的 transactionId，`PlayModel.Resolve` 会拒绝来自旧结果页的延迟回调。实际新事务号形如 `order:1:attempt:1000001`，旧请求为 `order:1:attempt:1`。

### 2. 收尾保留轮次

`BeginClosing` 重建 chapter 时，在顶层 `chapter.rewind` 只保留本轮身份（`run`/`branch`，空的日节点和备份）；完整历史仍随结局前 checkpoint 保存。`StartNewPlaythrough` 因此能读到真实轮次并递增；旧结局档顶层没有身份时，会从结局前 checkpoint 的有效轮次读取。`RestoreEndingCheckpoint` 也会开启新分支，避免恢复结局前后旧确认落回新订单。

回归使用真实 `StartJourney`、`StartNewPlaythrough`、发货、`NextDay`、愿望尾声、`ConfirmEnding`、`StartNewPlaythrough`：第 2 轮完成后新旅程为第 3 轮。另用克隆档删除顶层身份后重载，验证旧结局档仍能从 checkpoint 读到第 2 轮并开始第 3 轮。

### 3. LSP 类型推断

对 `GameState.lua` 的回溯计划局部变量增加显式 `---@type {ok:boolean, value:any, error:any}` 标注，针对原报告中的 `planned.ok/value` undefined-field。本轮没有与验收相同的 LSP 配置可复跑，需复核时再确认 0 Error。

## 本次重新运行的验证

| 检查 | 结果 |
| --- | --- |
| `python -X utf8 -B scripts/debug/run_rewind.py` | 14 通过、0 失败（含两个修复回归） |
| `run_release.py --suite flows` | 58 条登记流及真实 11 单链通过 |
| `--suite saves` | 26 通过、0 失败 |
| `--suite ending-saves` | 24 通过、0 失败 |
| `--suite ui` | 11 通过、0 失败；使用 UI 替身，不是画面证据 |
| `--suite purchases` | 7 通过、0 失败 |
| `--suite schedule` | 5 通过、0 失败 |
| `git diff --check` | 通过 |
| 上述两个额外边界探针 | 修复前稳定复现；修复后由 `run_rewind.py` 的两个新回归覆盖并通过 |

EmmyLua 原诊断中 `GameState.lua` 回溯计划局部变量有 6 条 undefined-field（planned.ok/value 的类型推导）；本次已加显式表类型标注。由于本轮没有与验收相同的 LSP 配置可复跑，仍需复核 0 Error；不把真实 Lua 测试通过当作 LSP 零错误。

## 已确认与待验收

代码与自动测试确认：无头像、日期分页、完整业务状态恢复、失败不安装半份状态、回溯前备份、旧档仅提供“启用回溯时”恢复点、全局留念和设备音量不回退。

两个逻辑问题已由专项回归确认修复。尚无第三批的原生窗口/手机画面证据：横屏安全区、左右横屏、日期及故事标题可读性、分页和恢复按钮可触达、实际触摸及恢复后回到游戏，均不能标记通过。

本地 preview status 返回 session `aab29213-49b8-4213-9242-8386db0a10ee`、reload 15、`state=stopped`、`process_alive=false`；按项目规则没有自动重启。没有生成或沿用旧版二维码冒充本批验收结果。

## 第二次独立验收（2026-10-18）

复验结论：**原两个逻辑问题确认修复；静态检查仍有 1 条 Error，尚未全部通过。** 本次未修改实现，未启动本地窗口，未远端构建或更新手机二维码。

重新执行首次验收使用的两个隔离复现步骤，实际结果：

```text
closing history=table; checkpoint run=2
new-run after wish ending expected=3; actual=3
old transaction=order:1:attempt:1; new=order:1:attempt:1000001; different potion=true
old confirmation accepted=false; changed=false; delivered=0
```

重新运行 `run_rewind.py`：14 通过，0 失败；flows 的 58 条登记流及真实 11 单链通过。存档、结局存档、UI、采购、日程套件分别为 26、24、11、7、5 通过，0 失败。UI 套件仍是替身，不能当成原生画面证据。`git diff --check` 通过。

对第三批 14 个新增/修改 Lua 文件逐一请求 severity 1 诊断，其中 13 个无 Error；`scripts/core/GameState.lua:553` 仍有如下 Error，重复请求结果一致：

```text
assign-type-mismatch: Cannot assign `table` to `{ error: any, ok: boolean, value: any }`.
```

原因：第 552 行把 planned 声明为带指定字段的结果对象，但两个计划方法经 `CalculationGuard.Run` 返回的静态类型是通用 `table`，赋值边界缺少匹配的类型契约。此前 6 条 undefined-field 已消除，不能因此声称 LSP 已为零。需要修正这个赋值/返回值的类型声明，再复跑诊断；目前业务测试没有复现相应的运行时错误。

本地状态复读仍为 stopped/reload 15；用户要求“有问题告诉我，没问题再重启并接手机”，因此未越过本轮未通过的检查更新测试版本。

第二批历史证据：已完成本地原生预览验证；随后花草自由摆放补充修改也做过本地重启和原生探针（reload 13），关闭探针后正常重启到 reload 15。对应 `docs/验证/evidence/second-batch-acceptance-2026-10-18` 与 `docs/验证/evidence/wish-free-placement-2026-10-18`。这些证据不能代替本轮第三批画面验收，也不等于手机实机验收。

## 类型修复与本地原生验证（2026-10-18）

用户授权修复、重启验证及更新手机测试版后，在 `GameState.lua` 对通用 table 的返回值使用 Result 结构的显式类型收窄，替代不兼容的直接类型赋值。未修改回溯业务逻辑。修复前重现 1 条 assign-type-mismatch，修复后对本批 15 个相关 Lua 文件逐一诊断，severity 1 为 0；`run_rewind.py` 14/14 通过。

新增默认关闭的 `RewindNativeProbe`，复用生产 AppView、GameState、真实委托和内存存储夹具；使用引擎触摸事件路由，不操作系统输入，不写正式玩家存档。真实完成第 1 至 7 单并跨到第 8 天后验证：

- 原生日期分页、选择第 2 天、触摸确认恢复、克隆隔离存档重新加载第 2 天。
- 在小屏的详情区触摸向上滚动，点击“恢复回溯前进度”，恢复到第 8 天；取消不写入。
- 保存失败时停留在回溯页、显示失败提示，业务状态完全不变。
- 1206×540 的左右安全区适配及原生 1450×815 电脑窗口中，纸面、关闭、滚动区域及底部操作完整落在安全区内。
- 验证结束确认真实玩家状态未变。

原生探针 session `678a9a6e-4e44-43e9-94e6-47a385aa6617`、reload 1 与 3 完整 PASS。截图与关键日志位于 `docs/验证/evidence/third-batch-rewind-2026-10-18/`。最初探针直接点击滚动视区外的备份按钮导致探针失败；按实际交互补上触摸滚动后通过，没有为此修改产品界面。标题入口截图采集于背景尚未完整绘制时，仅证明菜单入口，不能用它宣称标题背景完成视觉验收；回溯纸面与背景的后续截图已查看。

该验证使用电脑引擎和手机尺寸适配器，**不等于物理手机验收**。引擎日志仍有既有的 `DaySpecularHDR.dds` 与 `themis_x64.dll` 两条启动错误；本轮没有将其作为新增回溯错误或声称整个引擎日志无错误。
