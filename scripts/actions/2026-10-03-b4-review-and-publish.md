# B4 复核与下一批交接

## 状态与背景

- 状态：Completed（B4 复核、回归、文档同步及实现提交推送完成；不等同 B5 整单或实机验收）。
- 用户要求：复核 [B4 实施记录](2026-10-03-b4-implementation.md)，有问题记录，无问题提交推送，并说明下一步。
- 基线：`fengyycon@5c6a319`；本轮 fetch 后与 GitHub `origin/fengyycon` 一致。
- 结论：在 B4 纯计算、模块恢复和隔离联合验证范围内，未发现阻止本批提交的问题。未将尚未实施的 B5 订单事务或实机验收算作完成。
- 本轮只复核发布既有程序并补交接文档；不修改 Lua/Python、data/docs/main 或主页图片，不实施 B5，不启动预览，不提交 Maker 构建。原未跟踪 `docs/actions/` 保留。

## 实施措施

1. 对照 B0/C3 核对同快照规则、人物字段、事实来源、片段覆盖/互斥/兜底、评分次序和调度边界。
2. 复跑 B4 与 B3/B2/B1；确认测试使用真实 B3/B4 结果，期望表没有成为运行输出。
3. 补充 B5 任务顺序和内容配合边界，检查文档链接、原文件哈希及暂存范围。
4. 提交本批相关 `scripts/` 文件，推送 GitHub `fengyycon` 并核对远端。沿用实际 `origin`，不改远端、不操作 main。

## 影响文件树

```text
scripts/
├── README.md                                本轮追加复核入口
├── 后端闭环与双人并行开发计划.md              既有 B4 进度更新；追加 B5 交接链接
├── systems/{StoryRules,WorldState,Narrative}.lua  既有 B4 共享规则及真实模块
├── systems/Order.lua                        既有新增 Rate
├── debug/{WorldStateTest,NarrativeTest}.lua   既有模块/联合测试
├── debug/fixtures/B4Fixtures.lua             真实配置与技术 Envelope
├── debug/fixtures/B2Fixtures.lua             既有真实 Narrative 替换
├── debug/{run_b4.py,SelfTest.lua}             既有显式测试入口
└── actions/
    ├── 2026-10-03-b4-implementation.md        原实施记录，本轮保留
    └── 2026-10-03-b4-review-and-publish.md    本轮新增记录
```

WorldState 拥有人物状态，Narrative 拥有剧情状态，Order.Rate 只做评分。候选计算不安装正式状态、不扣料发奖，B5 负责未来的完整保存与提交。

## 自验证方法与实际结果

从工程根 `D:\taptap\To-the-Human-World` 执行：

| 检查 | 本轮结果 | 边界 |
|---|---|---|
| `python -X utf8 scripts/debug/run_b4.py` | 334/334，退出 0 | A～D/G1～G4 的真实事实/片段/评分，E/F 拒绝后果，规则冲突、兜底、来源、纯度、快照及 JSON/技术 Envelope |
| `python -X utf8 scripts/debug/run_b3.py` | 387/387，退出 0 | 药效与字面判定回归 |
| `python -X utf8 scripts/debug/run_b2.py` | 201/201，退出 0 | 已接真实 Narrative 的调度与恢复器；剩余世界/订单替身不视为正式集成 |
| `python -X utf8 scripts/debug/run_b1.py` | 130/130，退出 0 | 存档及账本回归 |
| runner 内阶段 0 逻辑自检 | 11/11 | 不含窗口布局 |
| 已有 LSP 诊断 | 2026-10-03 12:59:07，0 Error / 0 Warning | 沿用实施期证据；本轮不改程序，未重跑 LSP |
| `git -c core.safecrlf=false diff --check`、`git diff --cached --check` | 均通过 | 包含全部新增文件的完整暂存差异已检查 |
| `git diff --numstat -- scripts/data docs scripts/main.lua` | 空 | 内容、设计文档与正式入口未改 |
| 四份相关文档本地链接 | 36 个，0 个失效 | 按文件所在目录解析 |
| 原待提交文件 SHA256 比较 | 本轮只改变 README 与双人计划 | 程序、原实施记录及无关未跟踪文档保留原字节 |
| 暂存与实现推送 | 14 个相关 `scripts/` 文件，`85cbed9` 推送成功 | 无关 `docs/actions/` 未加入提交 |

本轮测试使用 Lua 5.4 与 File/cjson/UI 适配器；按正常本机权限运行既有隔离 runner，未更改 ACL 或依赖。单独 R2 八场景及三种启动配置门禁未重跑，沿用之前记录；不列为本轮通过。

静态复核重点：规则读取同一原始快照，合并写入后重新校验人物结构；false 来源不当缺省；评分先星级再同星 priority/ID；回信覆盖图拒绝循环、基础片段不能被删除、重要事实不可遗漏；恢复只安装副本，无结算事件；阶段 1 仅支持 dayMin/dayMax，其他调度条件明确拒绝。

未验收：真实窗口/手机、完整 v2、持久退出重进、正式订单生命周期。当前无 world.flags 和延迟事件配置，对非空状态明确报缺配置；这项边界与实施记录一致，不表示后续事件系统已经完成。

## 下一步：B5 整单流程，由本机负责程序与集成

目标：把“收到信、剪词、算药、算回信”串成真正可保存、可确认、可重置的一单。按以下顺序推进，不一次绕过全部门禁开启正式 v2：

| 顺序 | 要完成的工作 | 必须验证的出口 |
|---|---|---|
| 1 | Order 状态、快照校验与恢复器；补全真实初态及所有模块装配 | 完整 Envelope 无业务替身；坏档不能部分恢复。待确认内容、结算明细、候选差异须联合校验，不能只检查字段形状 |
| 2 | `Accept`、`BeginBrew` | 已读订单才能接取；保存成功后才进入相应阶段；首次投料前保存唯一基准，重复请求不创建新基准或订单 |
| 3 | `Preview` | 从同一基准调用 B3/B4，生成药效、判定、人物候选、事实、回信、评分与结算；保存待确认成功才展示。失败保留原状态，不提前扣料发奖 |
| 4 | `Confirm`、`Reset`、`GetView` | 确认只扣料/发奖/更新人物、队列和计数一次；重置回同一基准并保留此前剪词。保存失败保留原待确认，重复/过期请求不能重复结算或撤销已确认单 |
| 5 | GameState 门禁与正式 v2 集成、持久恢复检查 | brewing/pending 禁止破坏基准的操作；真实模块齐备并通过隔离联调后再切入口。重进读取已保存结果，不重算回信、不自动确认、不重播奖励 |

B5 重点测试：A～D 从同一基准确认/重置；库存、词条、余额、人物、队列、发货数一起变化或一起不变；编码/写入/读回失败；提交结果不确定时锁定对账；提交后安装或通知异常；重复确认、过期 transactionId、旧 revision；损坏档、不兼容内容和 v1 迁移。旧档已有发货计数但无明细时不能伪造历史。

V13 的 Maker 临时 savedata 清理问题仍须在真实持久运行环境补证据；新 reader 或 JSON 往返不能代替进程退出重进。隔离联调完成也不应把这一项勾掉。正式运行操作遵守已有预览授权边界。

队友继续维护 `scripts/data/`、`docs/` 的主线和普通订单包；现有首单 C1～C3 足以开始 B5，无需重写剧情。出现真实内容缺口时按路径交接；新增世界字段、延迟事件和调度条件先约定 schema，不让本机默编配置。

B5 闭环后立即进入 B6：用简单按钮完成一单试玩，再进入 B7 正式美术与实机验收。本轮仅交接，不提前实施。

## 发布回执

- 实现提交 `85cbed9`（`feat: 实现 B4 人物后果回信与评分`）。
- `git push origin HEAD:refs/heads/fengyycon` 成功，远端从 `5c6a319` 前进到 `85cbed9`。
- 实现推送后，工作区仅剩原未跟踪 `docs/actions/`。本回执单独作为文档提交随同推送，最终远端 SHA 见交付消息。
- 仅推送 GitHub `origin/fengyycon`，未推 main 或 Maker，未启动预览。
