# B5 整单事务与正式恢复实施记录

## 状态与背景

- 状态：Completed（B5 程序实现与隔离联调；V13、窗口及实机尚未验收）；来源：[B4 复核与下一批交接](2026-10-03-b4-review-and-publish.md)。基线 fengyycon@084f307，origin 为 GitHub；原未跟踪 docs/actions/ 保留。
- 范围：真实 Order 状态、完整恢复校验、接单/基准/待确认/确认/重置，GameState 原子保存与门禁，隔离验证后正式 main v2 装配。
- 不修改 data/docs，不提交推送/远端构建，不启动已停止预览，不提前实施 B6/B7。真实 Maker 持久退出 V13 仍须独立证据，不能由 JSON 或测试 runner 替代。

## 实施措施

1. Order 内部分离生命周期与已保存结果审计，保留 B3/B4 公共纯计算接口。校验历史、待确认、候选差异、账本/词消耗/世界/归档/计数，加载不调用后果/回信/评分生成器。
2. Accept 成功保存才接取；BeginBrew 固定唯一基准。Preview 从基准算完整候选并保存；Confirm/Reset 先保存再安装/通知。
3. 同单增加持久试做序号，重置后也不复用 transactionId；保留基准 revision。此为技术状态字段，不引入剧情或平衡规则。
4. GameState 统一提交与异常对账，跨天也走 v2 原子候选。禁止基准期间接新单、剪词、跨天等写操作；只读 GetView 可查原因。
5. 使用真实模块构造初态和恢复器；在隔离联调通过后切换 main。历史 B1 调试仍使用显式 v1 隔离协调器，不将旧测试明细当作正式 v2。

## 影响文件树（实际）

```text
scripts/
├── systems/Order.lua                    保留计算，暴露生命周期及恢复器
├── systems/OrderLifecycle.lua           订单状态及纯候选计划
├── systems/OrderAudit.lua               已保存结果与整份候选联合审计
├── core/GameState.lua                   统一提交、门禁、对账
├── core/SaveSchema.lua                  新技术字段与结构兼容
├── core/GameSession.lua                 真实模块装配和首单初态
├── main.lua                            检查通过后启用正式 v2；隔离旧调试
├── debug/{OrderFlowTest,OrderRecoveryTest}.lua  整单、故障与恢复用例
├── debug/fixtures/B5Fixtures.lua         真实模块、隔离存储与故障适配器
├── debug/{run_b5.py,SelfTest.lua}        显式专项入口
├── README.md / 后端闭环与双人并行开发计划.md  实际进度
└── actions/2026-10-03-b5-implementation.md   本记录
```

## 自验证方法

- 同基准 A～D/G、字面失败、幂等接单/基准/试做/确认/重置、过期事务/旧 revision，真实库存/词/金币/人物/归档/计数原子一致。
- 编码/写入/读回失败、提交不确定锁定、安装/通知异常、坏档/内容版本不符、v1 迁移；重进保留文本、禁止生成器重算及重复奖励。
- B1～B4 回归、启动配置门禁与调试隔离检查、全 scripts LSP、预览状态、git diff --check 与保护文件哈希。
- 不将测试存储的进程恢复或无头 UI 适配器作为引擎 V13、窗口或手机验收。

## 自验证结果

| 检查 | 本轮实际结果 |
|---|---|
| B5 首轮 | 293/293；真实模块候选、确认/重置、写入故障、对账与初步坏档检查 |
| 正式 v2 接入后的回归问题 | B2 T17 发现默认槽被调试跨天自动保存；原因是旧入口只绑面板槽名。已在回调前切至专用隔离协调器并加载测试槽，修复后 B2 201/201。测试问题未触及真实玩家文件 |
| `python -X utf8 scripts/debug/run_b5.py` | 最终 341/341，退出 0；[日志](../../logs/b5-b5-final.log) |
| `python -X utf8 scripts/debug/run_b4.py` | 334/334，退出 0；[日志](../../logs/b5-b4-final.log) |
| `python -X utf8 scripts/debug/run_b3.py` | 387/387，退出 0；[日志](../../logs/b5-b3-final.log) |
| `python -X utf8 scripts/debug/run_b2.py` | 201/201，退出 0；[日志](../../logs/b5-b2-final.log) |
| `python -X utf8 scripts/debug/run_b1.py` | 130/130，退出 0；[日志](../../logs/b5-b1-final.log) |
| `run_b1.py --config-failure load/c1/stage1` | 3/3；配置坏时禁止读入/保存/跨天，默认槽没有新写入。logs/b5-gate-*.log |
| `run_b1.py --debug-isolation ...` | existing/missing/flow_missing/v2_corrupt/auto_write/auto_read/auto_read_flow_missing/auto_read_v2_corrupt，8/8；真实入口回调默认槽字节保持不变。logs/b5-r2-*.log |
| LSP | 首次 2 Error/12 Warning；增量检查清零后，全新进程另发现 main 的 pcall 返回值推断问题。补充返回变量类型声明，再启全新进程于 2026-10-03 14:06:40 检查全 scripts：0 Error/0 Warning/0 Hint；随后 B1 再跑 130/130 |
| 文档与差异 | 3 份更新文档的 34 个本地链接有效；8 个新增文件无行尾空白，新增 Lua 均未超过 1500 行；git diff --check 通过 |
| 预览状态 | stopped / process_alive=false；没有复活旧会话，未运行窗口或手机验收 |
| 保护范围 | data/docs 无差异；原未跟踪预览文档和主页图 SHA256 与基线一致；没有提交推送或构建 |

本轮 runner 使用 Lua 5.4、隔离 File/cjson/UI 适配器。B5 同时运行真实 SaveSystem 双快照协议的故障介质检查及 File 适配器写盘后新会话恢复，后者仍非 Maker 的进程退出重进。V13 未验收，不勾选 A1～A19 的窗口/实机条款。

## 实际接口与保存约定

`GameSession.New(content, options?)` 是生产装配入口，包含真实 GameFlow、Letter、WordToken、Economy、WorldState、Narrative、Order 及 Order.CurrentOrder 恢复器。main 已在隔离联调通过后使用它，显式 targetSchema=2；`GetGameSession()` 给后续界面提供 state/order 公共接口。SaveSystem 默认写法仍兼容历史 v1 调试，生产协调器每次明确传 schema=2。

| Order 实例公共接口 | 实际行为 |
|---|---|
| `Accept({letterInstanceId})` | 已收/已读且 kind=order 才接受；保存 acceptedById 与 currentOrder 后分配 `order:<serial>`。同信重试返回原订单，不加序号或重复保存 |
| `BeginBrew({orderId})` | 保存唯一 `<orderId>:baseline`，含当前 revision/contentVersion/live；重复调用复用，不重拍基准 |
| `Preview(RecipeRequest)` | 调用真实 B3/B4、词消耗计划、库存结算、归档及来信筛选，保存 live=S0/pending=候选后才通知 DeliveryPreviewReady。字面失败 ok=true/phase=brewing，无保存/后果/奖励；配置失败 ok=false |
| `Confirm({orderId,transactionId})` | 匹配待确认事务；整份候选保存成功后安装全部模块，currentOrder=false，revision+1，最后通知。历史同事务重试返回 alreadyConfirmed=true，不保存/结算/通知 |
| `Reset({orderId,baselineId,transactionId?})` | pending 必须匹配事务；保存回同基准 live、brewing、recipe/pending=false 后安装。重复同次重置无写入，旧事务不能撤销新试做或已确认单 |
| `GetView({orderId}?)` | 返回阶段、正式/试做库存、基准/配方、已存 pending 或确认 record 的副本，以及每个操作的 enabled/reasonCode/message；不保存或重新生成结果 |
| `InitialSnapshot/ValidateSnapshot/Restore/GetSnapshot` | 管理 acceptedById/confirmedById；CurrentOrder 提供独立适配器视图，仍由同一 Order 实例拥有。整份联合审计经 `ValidateEnvelope` 执行 |

新增技术字段：currentOrder 必填 `nextAttemptSerial`（始于 1）和 `lastResetTransactionId`（false 或 ID），confirmedById 记录 `deliveryDay`。事务 ID 为 `<orderId>:attempt:<序号>`；每次成功保存 Preview 后序号递增，Reset 不回退，因此同基准同配方也不会重用过期确认凭据。BeginBrew/Preview/Reset 不改变正式 live/revision；接单、剪词等正式变化及 Confirm/跨天递增 revision。结构层兼容历史技术夹具，生产审计要求新字段齐备；不把旧技术 v2 夹具当正式可迁移档。

候选中包含：人物世界、词条消耗、金币/库存、归档、已确认明细、发货计数、声明条件可用的来信解锁集合。通知只供观察：PotionDelivered、OrderRatingRecorded、MoneyChanged、ItemRemoved、NpcStateChanged、LetterArchived；载荷带订单/事务/revision 和结果副本，没有监听者二次结算。

## 联合审计、门禁与失败语义

- 先结构检查及所有真实模块校验，再安装任何状态；恢复失败尝试回滚，锁定后对账。坏档/未来版本/配置失败保留原文件，内容或合成版本不相容提示 migration_required。
- 订单审计从明确初态与确认明细核对账本、词消耗和人物变化；按真实配方复核药效/字面结果、事实规则输入与变化、已选片段/绑定/存储文本、星级与固定报酬。待确认 candidateLive 必须等于所有允许变化的完整投影，不允许夹带跨天、额外收益、词变化或遗漏归档。
- 加载不调用 WorldState.Simulate、Narrative.ResolveDirect 或 Order.Rate，不重新选择故事、不替换保存文本、不自动确认、不重播奖励。审计只对已存来源/片段/绑定及文本做一致性比较；发现不相容就拒绝恢复。
- 保存编码/写入/读回失败保持原内存和可恢复旧档，不发正式事件。提交结果不可读时锁定 recovery_required，只允许读同一槽对账；提交后安装失败标记 committed=true。通知失败返回 notificationErrors，确认仍然成功，重试不重复结算。保存/安装/通知期间拒绝嵌套命令。
- brewing/pending 禁止收取/剪词/改变阅读状态/跨天、接另一单、购物/领附件及切换加载槽；可读 GetView、同槽恢复、确认/重置。购物/附件未实现时返回 NOT_IMPLEMENTED，基准期间优先 ORDER_LOCKED。完整商店未被本批引入。
- v1 只迁移合法 gameFlow，保留 false，并用实际 C1～C3 初态补齐；旧 deliveredOrders>0 无明细时返回 migration_required，不虚构历史。迁移读入不自动覆盖旧文件，下一次成功保存才落 v2。
- B1 历史调试流程档使用显式 v1 隔离协调器；B2 调试也先绑定该专用槽，再执行实际按钮。检查失败后仍保留隔离上下文，不能落回默认玩家槽。正式装配不使用这些替身。

## 后续与限制

- 程序闭环可进入 B6 简单按钮/文字界面试玩；本轮未接玩法界面或正式美术。
- V13 必须在真实持久运行环境补“退出进程→重开→同待确认/已确认结果”证据，Maker 旧预览仍停止；本轮不启动预览、不声称持久实机验收完成。
- 首单配置未发现阻断本批的缺口。阶段 1 审计基于初始账本和订单收益；将来引入购物、附件收益、世界 flags、延迟事件或额外来信条件时，内容与程序须先扩充对应账本/事件 schema。不能只填新表而绕过审计。
- 内容队友继续主线与普通订单交付；首单作为回归基线保留。本轮不修改内容版本、剧情、数值或默认玩家存档。
