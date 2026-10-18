# 标题页逐日进度回溯

## Status and situation

Completed（本地实施、自动回归与原生布局验证）。2026-10-18 完成 `docs/superpowers/plans/2026-10-17-mobile-feedback-remediation.md` 第三批任务 6：标题页新增“进度回溯”，只展示本轮真实日开头。验收发现的旧事务隔离、轮次身份与类型诊断均已修复；原生触摸及左右安全区验证通过。手机实机仍需扫码复验。没有操作正式存档。

现状边界保持计划口径：既有 `chapter.checkpoint` 是结局前快照，不是逐日历史；本轮以 `chapter.rewind` 承载版本化历史，继续走 `GameState` 的整档校验、双快照提交和装入/回滚协议。

## Implementation measures

1. 新增 `scripts/systems/RewindHistory.lua`。日开头快照保存完整业务投影的可重建形式：已确认订单和回信归档只存不可变 ID，恢复时从当前存档复制并按 `OrderTrial.ValidateCheckpoint` 完整重验；试做记录只存 ID，但带 pending 的“启用回溯时”当前进度点保存完整记录，因为其状态会随后续确认/重置变化。`chapter.rewind` 自身、跨周目留念和结局前快照不进入快照。回溯前另存一份完整业务快照和回溯前历史，供“恢复回溯前进度”使用。
2. `GameState` 在 `StartJourney` 建立第 1 天快照，在成功 `NextDay` 的同一份候选里追加重开日快照，在 `StartNewPlaythrough` 递增轮次并清空旧日节点；跨天失败不会留下假的到达日期。`StartNewPlaythrough` 保留 `chapter.memories`。`BeginClosing` 在顶层保留本轮 `run`/`branch` 身份，完整历史随结局前 checkpoint 保存，避免结局后新周目轮次回到第 2 轮。
3. 旧存档没有历史时，加载后只在内存中补一个标注为“启用回溯时/此刻”的当前进度点，不伪造更早日期；下一次保存才落盘，后续跨天才开始建立完整日开头。
4. 新增 `GameState.RestoreDay` 与 `RestoreBeforeRewind`：先完整校验候选，再用既有 `commit` 保存、装入和回滚；回溯创建新 revision 和新的 `chapter.rewind.branch`，把待确认订单的 `baseline.revision` 重定到新版本，并由 `OrderTrial.Preview` 把分支世代编码进试做序号。旧分支的确认/重置请求在新分支上不再匹配，避免旧回调或过期基准继续生效。失败或提交结果不确定沿用原有锁定和同槽对账。
5. 新增 `PlayQueries.GetRewindView`，只返回摘要和不透明 pointId。`PlayModel` 增加两个动作并在成功后清空旧选料、失败结果、试做预览和阅读缓存。结果页的确认/重置按钮把渲染时的 transactionId 传给 `PlayModel.Resolve`，旧结果页的延迟回调不能确认新分支的 pending。
6. 新增 `scripts/ui/landscape/RewindView.lua`，在标题页以大纸面显示当前日、日节点、分页、选中日摘要（来信、金币、词条、采购记录）、取消/回到第 N 天，以及可选的回溯前进度恢复。日节点按 `content.release.requiredOrderIds` 的 `appearCondition.dayMin` 显示当日故事标题；没有当日委托只显示“第 N 天”，旧内容版本显示“第 N 天（旧版本不可恢复）”。`TitleView` 只在当前旅程经营中显示“进度回溯”；结局阶段仍使用原有“回到结局前”。
7. `SaveSchema`、`ReleaseChapterAudit` 接收并校验可选 `chapter.rewind`；`baseChapter` 在比较经营态字段时排除该扩展。

## Affected file tree

- `scripts/systems/RewindHistory.lua`：新增历史结构、紧凑快照、物化、校验、回溯/备份计划。
- `scripts/ui/landscape/RewindView.lua`：新增标题页回溯界面。
- `scripts/core/GameState.lua`：加载时补当前进度点、跨天/开局/新周目快照挂接、两个回溯命令、收尾轮次身份和结局前恢复分支。
- `scripts/systems/OrderTrial.lua`：把回溯分支世代编码进试做序号，隔离旧分支的确认/重置请求。
- `scripts/core/SaveSchema.lua`：允许 `chapter.rewind`。
- `scripts/systems/ReleaseChapterAudit.lua`：接入历史结构校验，比较经营态时排除回溯扩展。
- `scripts/systems/PlayQueries.lua`：新增 `GetRewindView`。
- `scripts/ui/PlayModel.lua`：回溯动作、成功后的前端状态清理、结果页 transactionId 校验。
- `scripts/ui/landscape/ResultView.lua`、`Panels.lua`、`BrewFeedback.lua`：确认/重置时携带当前 pending 的事务号。
- `scripts/ui/landscape/AppView.lua`：回溯视图的路由、选中日和分页状态。
- `scripts/ui/landscape/TitleView.lua`：标题菜单“进度回溯”入口。
- `scripts/debug/RewindTest.lua`、`scripts/debug/run_rewind.py`：专项回归与运行入口。
- `docs/superpowers/plans/2026-10-17-mobile-feedback-remediation.md`：任务 6 状态与验收勾选更新。

## Self-verification method

- 纯业务使用真实 `GameSession`/`GameState`/`SaveSystem`、真实 Fixture 文件和隔离存储；UI 使用 `HeadlessUI` 与真实 AppView/PlayModel。
- 覆盖计划列出的五组验收：真实 1→2→3 日开头与重新载入、写入/读回/提交不确定、旧档无历史/跨周目/结局后/未完成配方/旧回调/内容版本、标题真实节点与取消不写、回溯前备份及留念/设备设置不回退。
- 额外覆盖旧档当前进度点带待确认结果时的恢复。
- 不把 headless UI、Lua 测试或静态审查当作手机画面或原生布局证据。

## Self-verification results

### 专项

`python scripts/debug/run_rewind.py`：**14 项全部通过**，包括：

- 第 1、2、3 天真实快照；回到第 2 天后重新载入，`live`、`currentOrder`、`journal`、`nextOrderSerial` 与第 2 天开头一致，revision 递增；后续日节点截断。
- 写入失败、读回失败、提交不确定均不产生半回溯；不确定提交重新读取后仍可从回溯前备份恢复完整进度。
- 旧档无历史时不伪造早期日期；加载后只有“启用回溯时”的当前进度点，下一次跨天开始建立日开头。标题页把该点标注为“启用回溯时的进度”，不冒充日开头“清晨”。
- 结局后拒绝逐日回溯，原有结局前快照仍可恢复。
- 未完成草稿被回溯丢弃、被备份完整保留；旧报价回调返回 `STALE_DAY`/`STALE_REVISION`。
- 新周目轮次递增、旧日节点清空；旅途留念保留；`music_settings.json`/`sound_settings.json` 字节不变。
- 旧内容版本节点可见但不可恢复，恢复返回 `CONTENT_VERSION_MISMATCH`。
- 标题页打开、恢复、取消不写、回溯前备份恢复；恢复后旧 draft/配方视图清空。
- 第 2 天节点显示“第 2 天：面包坊与抄写铺”；第 1/3 天分别显示“铁锚巷的一夜”“两个人的晚饭”；第 12 天以后没有标题；旧内容版本节点显示“第 N 天（旧版本不可恢复）”。
- 14 个日期分页为两页；保存失败保持回溯页并显示“保存失败”。
- 回溯后改用不同配方重做首单：旧预览、旧确认请求和旧重置请求均被拒绝，新事务正常确认；旧结果页携带旧 transactionId 的回调也被 `PlayModel.Resolve` 拒绝。
- 第 2 轮完成愿望结局后再开新局，轮次为第 3 轮，收尾不会丢失本轮身份。

### 第三批验收修复（2026-10-18）

验收文档 `docs/验证/2026-10-18-third-batch-acceptance.md` 报出的两个逻辑问题已修复：

- 订单分支隔离：`chapter.rewind` 增加 `branch`，回溯/恢复备份/回到结局前都会递增；`OrderTrial.Preview` 把分支世代编码进试做序号，旧 `transactionId`/`baselineId` 在新分支上不再匹配。
- 收尾轮次：`BeginClosing` 在顶层只保留本轮 `run`/`branch` 身份，完整历史留在结局前 checkpoint；`StartNewPlaythrough` 能读到真实轮次并递增，旧结局档缺顶层身份时回退读取 checkpoint。
- LSP：`GameState.lua` 回溯计划局部变量增加显式表类型标注；未用与验收相同的 LSP 配置复跑，待复核。

### 既有回归

- `python scripts/debug/run_release.py --suite flows`：58 个登记流 + 真实 11 单链通过。
- `--suite ui`：11/11；`--suite saves`：26/26；`--suite ending-saves`：24/24；`--suite purchases`：7/7；`--suite schedule`：5/5；`--suite closing`：通过。
- `scripts/ui/landscape/tests/run_travel_ticket.py`：47 断言；`run_first_batch.py`：966 断言；`run_brew_workbench.py`：188 断言；`run_word_tray.py`：64 断言。
- `python scripts/debug/run_rewind.py` 复跑 14 项全部通过；`--suite endings` 7/7 通过。

### 已知非本轮回归

- `scripts/ui/landscape/tests/run_home_entry.py` 在 `HomeEntryTest.lua:157` 失败（`preview saves actual result`）。用 `git stash` 暂存本轮全部改动后复跑，仍以同一断言失败，确认是先前就存在的 schema 3 UI 回归问题，不是本轮引入。
- `scripts/ui/landscape/tests/run_letter_presentation.py` 仍在 `PaperConsistencyTest.lua:58` 因旧 `activePanel` 查找失败；2026-10-17 行动记录已记录该基线失败。
- (`scripts/ui/landscape/tests/run_ui_contracts.py shop` 的入口自检仍在查找已改名的 `tab_shop`/`lockedView`，属于既有测试适配问题，未作为本轮证据。)
- EmmyLua LS 本地实例未加载项目 `.emmylua`/工作区配置，诊断结果包含全项目的 `require`/`math` 未定义噪声，不能作为有效 LSP 证据；本轮以真实 Lua 模块加载和回归为准。

### 边界

未启动本地预览、未操作正式存档、未走 Maker 构建/提交、未推送 GitHub。手机实机仍需在更新手机测试版后复验：标题菜单入口、纸面在小屏/安全区下的分页与按钮、真实触摸回溯、回溯后返回游戏。
