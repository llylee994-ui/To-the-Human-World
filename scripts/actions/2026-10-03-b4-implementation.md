# B4 人物后果、回信与评分实施记录

## 状态与背景

- 状态：Completed（B4 纯计算、模块恢复与隔离联合验证；不等同 B5 整单或实机验收）；来源：[B3 复核与下一批交接](2026-10-03-b3-review-and-publish.md)。
- 基线：fengyycon@5c6a319；origin 实际为 GitHub；开工只有原未跟踪 docs/actions/，予以保留。
- 本轮实现 WorldState、Narrative 和 Order.Rate，使用既有 C3；不修改 data/docs、main、正式存档版本，不提交推送或远端构建。不提前实施 B5～B7。
- 已核对 B0 接口、C3 的同快照规则、互斥/覆盖、来源和三星优先约定。阶段 1 来信条件只支持 dayMin/dayMax；其余条件明确拒绝。没有配置的世界 flags、延迟事件不凭空填充。

## 实施措施

1. 提供世界初态、严格快照校验和无事件恢复；纯 Simulate 验证字面通过后匹配同一输入、汇总变化、记录事实来源，拒绝冲突。
2. 共享有界条件/事实/绑定校验，Narrative 依据事实选片段、处理覆盖互斥和有来源的兜底；保留最终文本、片段和绑定副本。
3. 提供 Narrative 恢复与 FindAvailable，替换 B2 隔离装配的调度替身；不接正式 main。
4. Order.Rate 按三星优先和同星 priority/ID 匹配；仅返回评分、不处理报酬。
5. 真实 B3→B4 样例及错误边界、纯度、快照/JSON、B2 调度联合验证，回归 B1～B3，LSP 和预览状态检查。

## 影响文件树（实际）

```text
scripts/
├── systems/StoryRules.lua                 条件、事实、绑定的共享纯校验
├── systems/WorldState.lua                 世界状态归属、同输入模拟
├── systems/Narrative.lua                  剧情状态、回信与调度纯接口
├── systems/Order.lua                      新增评分接口
├── debug/WorldStateTest.lua               世界及来源/冲突边界
├── debug/NarrativeTest.lua                回信、评分、调度联合测试
├── debug/fixtures/B4Fixtures.lua          真实 C3 和 B3 技术输入
├── debug/fixtures/B2Fixtures.lua          真实 Narrative 调度/恢复器替换对应替身；保留原世界/订单替身
├── debug/run_b4.py                        复用已有隔离 Lua 5.4 runner
├── debug/SelfTest.lua                     显式 B4 测试入口
├── README.md                             进度入口
├── 后端闭环与双人并行开发计划.md           同步实际进度
└── actions/2026-10-03-b4-implementation.md 本记录
```

## 自验证方法

- 运行 run_b4.py：A～D/G1～G4 真实药效产生事实、回信、星级；E/F 拒绝后果；重要事实覆盖、填充值、互斥、同快照、冲突、评分排序/一星兜底、失败不修改状态。
- 运行既有 run_b3.py / run_b2.py / run_b1.py，结果分别记录，不把历史结果写成本轮通过。
- LSP 全 scripts 诊断，git diff --check；核对 data/docs/入口及原文件未被改动。
- 检查本地预览状态；停止的会话保持停止。没有实际窗口与移动端证据则不宣称 A1～A19 完成。

## 自验证结果

| 检查 | 本轮实际结果 |
|---|---|
| B4 首次沙箱运行 | 临时目录 WinError 5，未产生有效检查结论；未修改 ACL，改按本机权限运行 |
| B4 首次有效运行 | 279 项中 8 项失败：测试读取 expect.stars，但配置实际为 expect.rating.stars；程序算出的 3/3/2/1 正确。修正测试路径并加 ruleId 对照后 287/287 |
| `python -X utf8 scripts/debug/run_b4.py` 最终运行 | 334/334，退出 0；[日志](../../logs/b4-b4-final.log)。包括真实 B3/B4 Envelope、JSON、候选/基准恢复与默认槽字节检查 |
| `python -X utf8 scripts/debug/run_b3.py` | 387/387，退出 0；[日志](../../logs/b4-b3-check.log) |
| `python -X utf8 scripts/debug/run_b2.py` 最终运行 | 201/201，退出 0；已换真实来信筛选与 Narrative 恢复器；[日志](../../logs/b4-b2-final.log) |
| `python -X utf8 scripts/debug/run_b1.py` | 130/130，退出 0；[日志](../../logs/b4-b1-check.log) |
| 全目录 LSP | 初次新代码 1 Error / 21 Warning，主要为判别表/非空与返回类型推断；修正后重建进程排除缓存。最终 2026-10-03 12:59:07，0 Error / 0 Warning；logs/lua_diagnostics.log |
| 本地预览状态 | stopped / process_alive=false；没有启动、刷新或进行窗口验收，status 中旧错误属于 10 月 2 日历史会话 |
| 隔离与纯度 | Save 调用 0、事件 0；正式世界/剧情/库存及输入内容不变；默认槽 5 份文件前后相同 |
| 工作区边界 | data/docs/main 无差异；原未跟踪预览文档及主页图 SHA256 与交接基线一致；没有提交、推送或远端构建 |
| 文本检查 | git diff --check 通过；3 份更新文档的 33 个本地链接有效，8 个新文件无行尾空白 |

收尾已结束本轮创建的专用 LSP watcher 与子进程，诊断日志保留；没有触动预览进程。

未运行单独 R2 八场景/三种配置门禁；不将其历史证据记为本轮结果。Lua 5.4 runner 使用 File/cjson/UI 适配器，本轮没有窗口、手机或进程退出重进证据。

## 实际接口、字段和错误边界

`WorldState.New(content)` / `Narrative.New(content)` 创建独立实例；模块默认实例绑定统一 data.content。两者提供 `InitialSnapshot/ValidateSnapshot/Restore -> Result<snapshot>`、`GetSnapshot -> snapshot|nil`。调用方先 Data.Load/ValidateStage1，再装配。Restore 失败保留原状态，成功只安装副本、不派发事件。B5 集成仍须先校验全部模块，再整体安装。

| 接口 | 输入与输出 |
|---|---|
| `WorldState.Simulate(world,potion,context,rules?)` | context 为 `{letterId,orderId,day,facts?}`；facts 仅指此前输入事实。rules 缺省从订单的 directRuleSetId 选取；显式传入须等于该配置集。先真实 Order.Evaluate，再读取同快照条件，返回 `{world,facts,worldChanges}` |
| `facts[]` | 配置字段 `{id,subjectId,objectId?,value,important}` 加 `sourceRuleId`、`inputs={potionEffects,subjectState,context,when,unless}`；when/unless 每条保存 `{source,path,op,expected,actual,matched}`。结果按事实 ID 排序 |
| `worldChanges[]` | 按字段路径排序，`{path,op,value,before,after,sourceRuleIds}`；同字段同值 set 可合并，add 累加；不同 set 或 set/add 冲突拒绝。只写已声明人物标量，并对候选重新做完整 schema 校验 |
| `Narrative.ResolveDirect(facts,context,template?)` | context 为 `{letterId,orderId,day,world,potion}`，world 使用模拟候选。核对字面通过、事实所属规则集、候选世界与模板引用后返回 `{letterId,fragmentIds,bindings,renderedText}`。bindings 按片段 ID 存实际使用的占位名→值 |
| 片段选择/渲染 | 条件按事实存在性匹配（false 也存在）；关键→组合→单效果→通用，同档 priority 降序/ID 升序。互斥组按 priority/ID，覆盖图禁止循环，基础段不能被覆盖删除。输出 opening→配置顺序的基础段→选中段→closing |
| 兜底 | 普通片段缺来源时尝试已配置且事实兼容的 fallback；仍须覆盖全部 important 事实。来源不足报 FILL_SOURCE_MISSING，无表达覆盖报 CONTENT_UNCOVERED，互斥/虚构事实表达报 NARRATIVE_CONFLICT；不展示残留占位符 |
| `Narrative.FindAvailable(live,conditions?)` | 返回尚未收到、满足 dayMin/dayMax（含边界）的订单信 ID 数组，按 ID 排序；不包含 direct_followup，不改变世界/时间/解锁集合。conditions 只能省略或空；其他出现条件明确 CONFIG_INVALID，不因已收到就跳过错误配置 |
| `Order.Rate(facts,ratingConfig)` | ratingConfig 为评分集 ID 或其完整配置数组；返回 B0 `{stars,feedback,ruleId,factIds}`。事实须来自已通过字面的模拟。按三星→二星→一星，同星 priority/ID；无覆盖 RATING_UNCOVERED，反馈缺来源 FILL_SOURCE_MISSING，不降星掩盖错误 |

快照继续沿用 B0 的 world={npcs,flags}、narrative={unlockedLetterIds,delayedQueue,resolvedEventIds}。当前内容没有 world.flags schema 或延迟事件定义，因此这些集合只有显式空值可恢复；未知非空数据报告 CONFIG_MISSING，不丢字段或假装事件已执行。unlockedLetterIds 只接受合法 order ID→true。FindAvailable 仅检查它实际使用的流程/信件/剧情块，完整世界校验由 WorldState 恢复器交给 B5 统一执行。

世界规则、片段、评分不读取 sampleCases.expect；期望仅供 debug 对照。R.Facts 校验结构和配置来源，不充当 B5 事务真实性/重算证明；调用方不能将任意伪造事实当作已发货结果。字面失败 E/F 在 WorldState 和 ResolveDirect 入口拒绝，空事实无评分覆盖。

## 联合结果与下一批

- A/B/C/D 分别为 3/3/2/1 星，事实、片段 ID 和评分 ruleId 均匹配 C3 期望；C 使用人物真实歌名；D 有明确难受事实且不出现认出母亲段。
- G2/G3 的副作用只生成已配置的零碎多梦，无案件证据；G1～G4 均三星；E/F 拒绝后果/回信/评分。
- 六种真实输出装入现有技术 Envelope 并通过 SaveSchema.ValidateV2，世界候选/基准快照可往返；这不是接单、待确认保存或确认/重置实现。
- 下一批 B5：订单生命周期、首次投料基准、待确认保存、成功保存后一次确认/重置、完整恢复器和正式 v2。闭环后即 B6 简单界面试玩，再 B7 美术/实机。
- 首单 C3 未发现阻断本批的配置缺口。内容队友继续既定主线和普通订单包；新增世界字段、延迟事件或非 dayMin/dayMax 条件需先约定 schema。extension_test 的新增 NPC 未声明 B4 初态，本轮只沿用它验证 B2 扩展调度，不虚构其世界状态。
