# B6 原生写入失败与窗口恢复

## 状态与现场

Completed（本批明确写入失败与恢复验收完成，非全部 A1～A19）。用户指示继续上一批剩余的真实窗口保存失败与恢复验收。沿用隔离 Maker 候选和已有工程，结束时预览已停止；fengyycon 分支、origin 实际为 GitHub。保留所有既有代码、文案与图片工作区改动，不提交推送或构建。

上一槽 b6_persist_20261004_a 已完成三单，保留不改。本批新建独立槽 b6_fault_20261004_a，经正常窗口完成首单准备，不注入库存、剧情或存档。原生 File/SaveSystem 不替换。只在 .mpv 的该槽下一写入银行文件上暂设只读属性，失败后恢复原属性；不改 ACL、不锁目录或其他槽。

## 实施措施

1. 加入只读诊断：仅明确测试槽显示留证按钮，输出正式快照、状态、门禁与事件计数；不改模块状态。最终重开沿用公开 Confirm 幂等探针。最初 F9 未产生记录，已改成实际可点击按钮；未用缺失证据判定通过。
2. 通过真实窗口生成待确认，记录原生提交代数与文件、内存快照和窗口。
3. 对下一写入银行的快照文件临时只读，真实点击确认；核对 SAVE_WRITE_FAILED、pending 保留、正式状态及事件不变。
4. 恢复文件属性，点击重试；只结算一次。正常关窗重开核对完整结果和重复确认。
5. 若可在不改变玩法的条件下扩展提交标记失败，则同样明确记录；不预先声称提交不确定或断电情况已测试。
6. 恢复验收开关 off，关窗并核对无只读遗留，更新验收入口。

## 影响文件树

- scripts/actions/2026-10-04-b6-native-save-failure.md：本轮行动事实。
- scripts/debug/B6FaultEvidence.lua：新增，仅本轮独立槽显示只读留证按钮，观察 EventBus 并读公共快照/门禁；不操纵游戏进度。
- scripts/ui/PlayModel.lua：实际写入失败界面暴露内部路径；只将明确 SAVE_WRITE_FAILED 的用户提示改为未生效/检查存储后重试，诊断详情仍打印，其他错误类型保持原含义。
- scripts/debug/B6Evidence.lua：启动上述诊断。
- scripts/debug/B6PersistenceProbe.lua：将本轮唯一槽纳入已有确认重试诊断。
- scripts/debug/B6RunRequest.lua：临时指向新槽，结束恢复 off。
- scripts/debug/maker-preview-lab/fault_evidence.py：新增，本槽原生采证及受限只读属性注入/恢复；记录原属性，拒绝重复启用，验证精确槽路径及缓存边界。
- scripts/debug/maker-preview-lab/verify_fault_evidence.py：新增，复核39项本轮原生证据；不运行或修改游戏。
- scripts/debug/maker-preview-lab/README.md：补故障验收入口和恢复方法。
- scripts/B6_窗口与退出恢复验收.md、scripts/README.md、scripts/本机实施计划_新内容联调与B6_2026-10-03.md：同步新增实际结果。
- logs/b6-fault-*：本机证据，不提交；D:/taptap/.mpv/data 下指定槽文件只读属性临时变更，原样恢复，不复制旧数据。

## 自验证方法

- Lua 修改前参考既有指南、事件 API 及 UI 示例；修改后全目录 LSP 与既有 B6 逻辑回归。
- 每批代码修改后查 preview status，运行中才刷新；本次用户已授权真实窗口启动。
- 真实窗口截图目视、留证按钮快照，原生 Lua 日志与双提交记录验证。
- 保存失败与正式结算的快照/事件/存档比较，正常退出重开验证。
- 检查只读属性全部恢复、off、stopped，文档链接及 git diff --check。

## 自验证结果

### 真实窗口结果

用户0、同一新槽 b6_fault_20261004_a，正常打捞/读信/剪睡觉/接单，投入睡觉和一份海盐。没有复制其他存档或修改原生 File/SaveSystem。

| 场景 | 文件介质实际故障与结果 |
|---|---|
| Preview 保存失败 | 下一银行 b.json 只读；generation5、brewing、完整内存/已提交档和全部文件内容保持不变，0事件。恢复原属性后用原配方重试，generation6、pending，DeliveryPreviewReady仅1次。 |
| Confirm 快照失败 | 下一银行 a.json 只读；明确 SAVE_WRITE_FAILED / snapshot_write。原 pending 的快照、事务、回信、评分、正式账本和全部文件不变，0事件，可重试。 |
| Confirm 提交标记失败 | a.commit 只读；a.json 候选已改写，但提交标记未改变；明确 SAVE_WRITE_FAILED / commit，仍选择 generation6/b 银行，内存和正式状态不变，0事件。恢复属性后先关窗重开，仍恢复原 pending，未将未提交候选误作已确认。 |
| Reset 保存失败 | 下一银行 a.json 只读；重置未生效，原 pending 完整保留，0事件，原有跨天/接下一单/剪词门禁仍在。恢复属性后正常确认成功。 |
| 最终确认与重开 | generation7，110金币、海盐2、睡觉卡已用于order:1、已确认1单；完整 live 等于原 pending.candidateLive。PotionDelivered、MoneyChanged 等6种正式通知各1次。正常关窗重开完整快照/文件一致，公开Confirm再试2次均alreadyConfirmed=true、0事件、状态不变。 |

只读探针显示所有失败前后 canMutate=true，允许重试；pending 时 Confirm/Reset可用，而 NextDay/CutWord/Accept/Preview不可用。此处是**明确失败**，没有误判成提交不确定，也没有用重读新档掩盖错误。

实际会话：

- 准备会话 7f4482f6-f8ac-4272-bbd8-6da05884e654，PID61764→刷新60272→刷新13980（reload0/1/2），最终生成正常 brewing 基准后关窗。刷新发生在故障启用之前，未保存的投料按正常界面重选。
- e355dc80-a462-4356-8a0d-d7d9c78facba，PID52084：Preview失败和恢复后生成pending。
- 19502498-9584-45c3-aabc-f1196bdd0f09，PID45348：Confirm快照/提交标记失败，恢复属性后关窗。
- aeff1853-8565-4e1a-8c6d-3cb3db4ae65a，PID9796：恢复原pending、Reset失败、恢复属性后确认。
- f9928ab0-b5b5-41eb-9c97-e1f32f71cdc5，PID41044：最终恢复和重复确认，已正常关窗。

### 界面修正与证据

最初失败提示直接展示 SaveSystem 位置和存档文件名，见[修正前](../../logs/b6-fault-preview-failed.png)。只对明确 SAVE_WRITE_FAILED 改成“保存失败，本次操作未生效。请检查存储空间或写入权限，再重试。”详细错误保留在 PlaySaveFailure 日志，未更改其他错误或结算行为。修正后在真实[确认失败](../../logs/b6-fault-confirm-failed.png)、[提交标记失败](../../logs/b6-fault-commit-failed.png)、[重置失败](../../logs/b6-fault-reset-failed.png)窗口都能完整换行显示。未提交/未消耗不是猜测，已用完整内存、磁盘、事件交叉核对。

客户区412×734，测试专属只读按钮占底部一行；只在精确槽启用，正常off不显示。已打开各截图目视核对。最终[重开词卡画面](../../logs/b6-fault-reopen.png)和[39项证据核对](../../logs/b6-fault-verification.json)。本轮不重新宣称手机安全区或全部布局验收通过。

### 检查与恢复

- `python -X utf8 -B scripts/debug/run_b6.py`：新增诊断前后/提示修改后现有按钮适配测试170项通过（准备专项104项包含其中）；仅作为逻辑回归，原生证据另列。
- `maker-lua-lsp --mode watch`：最终0 Error/0 Warning/0 Hint（logs/b6-fault-lsp/lua_diagnostics.log，13:26:23及后续off检查）。初版事件参数索引警告已修正；F9实际无采证输出，收集器明确拒绝，随后改为按钮。按钮实测可取得完整快照。
- `python -X utf8 -B scripts/debug/maker-preview-lab/verify_fault_evidence.py`：39项通过，包括其他原生槽文件哈希全部不变、四次故障对应文件属性全部恢复、最终进程停止。旧三单槽270金币成果未动。
- 原生Lua日志未出现异常堆栈；PlaySaveFailure为预期受控错误记录。每次Runtime仍有既有Cube/Day/DaySpecularHDR.dds、themis_x64.dll错误，preview check和run总结果仍FAIL/1，不等同于存档专项失败，也不能报告总检查通过。
- B6RunRequest恢复off；故障恢复记录active=false，文件原属性32全部还原。采证以Runtime真实启动时间区分同会话refresh后的日志，不能只用session.started_at。
- 两次窗口助手参数误写英文数字，被参数校验拒绝；其中一次前一个确认点击已执行，后续只采证，没有重复点击结算按钮。未作为业务失败统计。
- 最终off后的LSP于13:33:22仍为0E/0W/0Hint，诊断进程已停止；`git diff --check`通过（仅既有LF/CRLF提示），92个本地文档链接均存在。scripts/data与.project无差异。原版Maker SHA256仍为62deb6cd7adc3975d23ce5750be53116f02ef7b9b5b9d49e5ace44fbbc144652，候选仍为9079523c318885b10199c76c75580885f5f601e393c6e00f1a5b0f561d54ca23，本轮两者均未改。

### 剩余边界

本次是Windows隔离候选上只读文件触发的原生写入失败，不代表磁盘满、部分短写、断电/强杀或提交成功后读回不可用均已验收。提交不确定→锁定→重新读取同槽仍只有适配器测试；手机和官方持久运行入口未实测。继续依照B6剩余表推进，不把A18或A1～A19整项勾完。原版Maker安装、配置、游戏内容与云存档未改；没有提交推送。
