# B3 复核与下一批交接

## 状态与背景

- 状态：Completed（B3 复核、回归、文档同步及实现提交推送完成；不表示整单或实机验收完成）。
- 请求：复核 [B3 实施记录](2026-10-03-b3-implementation.md)，有问题记录，无问题提交推送，并交接下一步。
- 基线：`fengyycon@6820d25`；本轮 fetch 后与 `origin/fengyycon` 一致。`origin` 为 GitHub。`origin/main` 的新提交 `daf882a` 是合入 B2 的 PR #3，没有额外文件差异；本轮不另作 main 合并。
- 结论：在 B3 纯计算和隔离验证范围内，未发现阻止本批提交的问题。双人计划末段仍写“未实施 B3”，与当前状态矛盾，随本次交付修正文档。
- 范围：复核并发布既有实现，更新交接文档；本轮不修改 Lua/Python、内容配置、设计文档或主页图片，不实施 B4，不启动预览或 Maker 构建。

## 实施措施

1. 对照 B0、synthesis.lua 八步说明、C2 样例及填写说明，检查 Potion、Order、CalculationGuard 与测试。
2. 复跑 B3、B2、B1，核对新模块通过公开接口读取状态、只计算副本、不扣料/发奖/保存/通知。
3. 同步文档入口与后续任务，检查变更范围、文档链接、暂存差异。
4. 仅提交本批相关 `scripts/` 文件，推送 GitHub `fengyycon`，核对远端提交号。保留原未跟踪 `docs/actions/`。

## 影响文件树

本轮新增/更新的文档：

```text
scripts/
├── README.md                                 增加复核与下一批入口
├── 后端闭环与双人并行开发计划.md               修正末段过时状态
└── actions/2026-10-03-b3-review-and-publish.md  本记录
```

本轮复核并提交的既有 B3 文件：

```text
scripts/
├── systems/CalculationGuard.lua       共用计算边界及 Result 错误转换
├── systems/Potion.lua                 八步合成、结果校验与残留采样
├── systems/Order.lua                  纯配方解析和字面判定
├── debug/{PotionTest,OrderTest}.lua    配置样例、边界、纯度及结构兼容检查
├── debug/fixtures/B3Fixtures.lua      真实模块产生的技术基准
├── debug/run_b3.py                    复用已有隔离 runner
├── debug/SelfTest.lua                 显式 B3 检查入口
└── actions/2026-10-03-b3-implementation.md  原实施记录，保留历史结果
```

Order 通过 Letter/WordToken/Economy 公共接口解析基准，Potion 接纯数据；没有另建业务状态或存储入口。正式 main 保持 v1。

## 自验证方法与实际结果

工程根：`D:\taptap\To-the-Human-World`。

| 检查 | 本轮结果 | 边界 |
|---|---|---|
| `python -X utf8 scripts/debug/run_b3.py` | 387/387，退出 0 | C2 A～G4、八步/时间边界、重复/槽位/库存、失败明细、纯度、JSON 及完整技术 Envelope 兼容 |
| `python -X utf8 scripts/debug/run_b2.py` | 201/201，退出 0 | 信件、词条、原子候选提交和调试隔离回归 |
| `python -X utf8 scripts/debug/run_b1.py` | 130/130，退出 0 | 存档和最小账本回归 |
| 以上 runner 的阶段 0 逻辑自检 | 11/11 | 不含窗口布局检查 |
| 既有 LSP 日志 | 2026-10-03 12:14:29，0 Error / 0 Warning | 本轮没有改程序，沿用实施期日志，未重跑 LSP |
| `git -c core.safecrlf=false diff --check`、`git diff --cached --check` | 均通过 | 包含全部新文件的暂存差异已检查 |
| `git diff --numstat -- scripts/data docs` | 空 | 没有改动受保护内容与设计文档 |
| 四份相关文档本地链接 | 31 个，0 个失效 | 按文件所在目录解析相对路径 |
| 原待提交文件 SHA256 比较 | 只有 README 与双人计划按本轮措施改变 | Lua/Python、原 B3 实施记录及无关未跟踪文档均保留原字节 |
| 暂存范围与实现推送 | 12 个相关 `scripts/` 文件；`68a501d` 推送成功 | 无关 `docs/actions/` 未加入提交 |

测试采用 Lua 5.4 与 File/cjson/UI 适配器。本轮按正常本机权限运行既有隔离 runner，未更改 ACL 或测试依赖。未重复执行单独的三种配置门禁及八种 R2 runner 场景；这些沿用 B2 复核结果，不冒称本轮重跑。

未验收：真实引擎窗口、移动端、完整 v2、进程退出重进、人物后果、星级和整单确认/重置。B3 的完整技术 Envelope 检查仍用显式 B4/B5 后果占位，不能等同真实整单验收。

## 下一步：本机做 B4，队友继续内容交付

B3 已能回答“这锅药有什么作用、是否满足信上的要求”。B4 要回答“人物因此经历了什么、怎么回信、本人给几星、之后哪些信可出现”。沿用 B0 与当前 C3，不重新决定已接受规则。

| 顺序 | 本机程序任务 | 出口 |
|---|---|---|
| 1 | 实现 `systems/WorldState.lua` 的初态/快照校验/恢复及纯 `Simulate` | 对同一输入快照匹配配置规则，再合并人物变化与事实；不改正式状态，不发奖励，不将梦境当作未配置的案件证据 |
| 2 | 实现 `systems/Narrative.lua` 的恢复接口和 `ResolveDirect` | 基础、单效果、组合片段按条件、覆盖与互斥选取；占位符有真实来源，重要事实得到表达，缺失不能拼凑成功文本 |
| 3 | 实现 Narrative 的 `FindAvailable` | 按正式快照及已声明条件筛选订单信，替换 B2 调度替身；直接回信不进打捞队列，不人为跨天，未支持条件明确拒绝 |
| 4 | 扩展 Order 的 `Rate`，跑真实 B3 → B4 联合用例 | 按三星→二星→一星匹配，priority/ID 仅同星级排序；A/B 三星、C 二星、D 一星，D 不同时出现“完整认出母亲”片段；同单报酬不随星级改变 |

联合检查还应覆盖 G2/G3 副作用只产生已配置的零碎多梦、无重要事实覆盖/无填充来源报错、评分一星兜底、重复求值一致、输入及正式库存/世界不变、真实模块快照往返。不要从 sampleCases.expect 直接复制事实/片段/星级当成实际计算结果。

队友继续维护 `scripts/data/` 与 `docs/`：

- 现有 C3 已交付，可直接支持 B4，不要求重写路人甲；若联调发现事实、互斥、覆盖或字段缺口，按具体路径补配置和期望结果。
- 主线节点表、普通订单正文与回信、事实/评分表可并行写；首单作为回归基线保留，新增机制先交接接口，按既有内容版本与旧档规则接入。
- 程序字段和结果如何落盘由两人对齐后交付，不让文案同时修改 main/core/系统实现。

B4 后才进入 B5：接单→保存本单基准→试做→后续→确认/重置、完整恢复器、正式 v2 与持久退出验证。闭环就绪后立刻接 B6 简单界面试玩，再接 B7 正式美术。本轮不提前实施这些批次。

## 发布回执

- 实现提交：`68a501d`（`feat: 实现 B3 炼药计算与订单字面判定`）。
- `git push origin HEAD:refs/heads/fengyycon` 成功，远端从 `6820d25` 前进到 `68a501d`。
- 实现推送后的工作区仅有原未跟踪 `docs/actions/`；原实施记录、程序文件均按复核版本提交，未改剧情或数值。
- 本发布回执另作文档提交随同推送；最终远端提交号在交付消息中给出。只推 GitHub `origin/fengyycon`，未推 main，未提交 Maker 构建，未启动预览。
