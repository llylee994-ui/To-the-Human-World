# 新内容联调与 B6：P1～P6 执行记录

> 最新进展见 [r3 与 B6 接续](2026-10-03-r3-integration-and-b6.md)：正式 r3 已合入并通过逻辑检查，B6 文字按钮已接入；窗口/V13 未验收。本记录保留原 P1/P2 的失败与修正过程，不代表当前仍等待内容交付。

## 状态与背景

- 状态：Blocked（P1 完成；P2 测试实现完成但正式内容验收失败；P3 等 T1/T2）。依据 [本机实施计划](../本机实施计划_新内容联调与B6_2026-10-03.md) 执行；基线 fengyycon@cbabddd，保留未提交 B5 及原 docs/actions/。
- 已核对实际远端为 GitHub origin；fetch 后 main=bd606db，仅新增计划的合并记录，未见 T1 修复。当前内容仍 story-v0.3-r1。
- P1/P2 可独立推进；P3 出口依赖 T1/T2，失败则不进入 P4。P6 依赖 T3 正式变体契约，不代写剧情或修改 scripts/data、docs。
- 不提交、推送、构建；不自动重启已停止预览。V13 与 A1～A19 必须区分真实窗口证据和隔离逻辑检查。

## 实施措施

1. 修正纸面 unless 任一排除、原料 addTags 不加辅助同标签奖励；保留正例并与真实模块比较。
2. 用稳定 ID 选择 B4 规则/片段/信件/人物，显式构造稀疏条件与目标状态，防止测试依赖配置排序。
3. 新增正式新内容 runner：当前来源完整流程、未来来源纯计算、九组强镇静/记忆矩阵、真实初始库存连续三单；复用 B5 故障测试。
4. 核对内容依赖、回归与兼容边界。通过 P3 后实施 B6；缺内容时留下明确失败与交接，不改业务规则凑通过。

## 影响文件树（本批实际）

```text
scripts/
├── debug/check_story_content.py          独立纸面复算与语义对照
├── debug/{WorldStateTest,NarrativeTest}.lua  B4 负例/正例及调度隔离
├── debug/fixtures/{B3Fixtures,B4Fixtures,B5Fixtures}.lua  ById 查询、首信按 ID 选择
├── debug/StoryContentFlowTest.lua        新内容真实模块联调
├── debug/run_story_content.py           独立执行入口，复用 B5 故障回归
├── README.md / 本机实施计划_新内容联调与B6_2026-10-03.md / 后端闭环与双人并行开发计划.md  实际状态
└── actions/2026-10-03-story-integration-p1-p6.md  本记录
```

本批未修改 main/core/systems/ui；工作区这些目录的已有 B5 改动保留，不能与本批测试修正混为一批已复核发布结果。P4/P6 未提前实施。

## 自验证方法

- `python -X utf8 scripts/debug/check_story_content.py`：独立语义对照，配置缺口必须失败。
- `python -X utf8 scripts/debug/run_story_content.py`：真实 GameSession 全流程与 B5 故障检查；文件/UI 仅隔离适配器。
- B1～B5 回归、Lua LSP、git diff --check、内容/无关文件保护检查、预览状态。
- P3 通过前不声称 P4/P5/P6 完成；窗口、手机、持久退出分别记录证据。

## 自验证结果

### 实际执行与结果

命令均在工程根运行，Python runner 使用现有 Lua 5.4 与隔离 File/UI；没有安装依赖，也不依赖 `.tmp/story_v03_runtime_review.py`。

| 检查 | 实际结果 | 证据 |
|---|---|---|
| `python -X utf8 scripts/debug/check_story_content.py` | 9 个测试方法，4 条失败报告；双条件/空列表与真实 StoryRules 对照、原料 addTags 与真实 Potion 对照均通过。参考 N01 C/D、组合覆盖、阈值覆盖仍失败 | [内容日志](../../logs/p1-content-final.log) |
| `python -X utf8 scripts/debug/run_b4.py` | 339/339，退出 0；包含倒序配置 A～D 与缺 ID 明确报错，原正常正例保留 | [B4 日志](../../logs/p1-b4-final.log) |
| `python -X utf8 scripts/debug/run_story_content.py` | 当前来源 14/16；未来来源纯计算 9/9；事实矩阵 5/9；1098 个检查、6 个失败，退出 1。B5 原故障/恢复覆盖直接调用且通过 | [新内容日志](../../logs/p2-story-final.log) |
| `python -X utf8 scripts/debug/run_b1.py` | 130/130，退出 0 | [B1 日志](../../logs/p3-b1.log) |
| `python -X utf8 scripts/debug/run_b2.py` | 201/201，退出 0 | [B2 日志](../../logs/p3-b2.log) |
| `python -X utf8 scripts/debug/run_b3.py` | 387/387，退出 0 | [B3 日志](../../logs/p3-b3.log) |
| `python -X utf8 scripts/debug/run_b5.py` | 341/341，退出 0 | [B5 日志](../../logs/p3-b5.log) |
| 本地 maker-lua-lsp 全 scripts | 2026-10-03 15:24:12，0 Error / 0 Warning / 0 Hint | [诊断](../../logs/lua_diagnostics.log) |
| `git -c core.safecrlf=false diff --check` | 通过 | 本轮终端检查 |
| 文档/新增文件检查 | 4 份变更文档的 49 个本地链接有效；3 个本批新增文件无行尾空白，新 Lua 未超过 1500 行 | 本轮 Python 只读检查 |
| 内容与无关文件保护 | `git diff --name-only -- scripts/data docs` 为空；原预览文档、主页图 SHA256 与既有保护值一致 | 原 docs/actions/ 和未提交 B5 保留 |
| Maker preview status | stopped / process_alive=false，同一 session=98eb3697-9d20-4786-ba98-325c4e18a42a；未启动/刷新 | CLI 使用 D:/node.js/node.exe 与 Maker 0.0.36 的 dist/maker.js |

测试实现期修正：矩阵首轮手工更改 effects 后，零权重和 intensityByEffect 不符合 PotionResult，9 组都在输入校验失败。已改为修改技术词定义副本并由真实 Potion 生成完整自洽结果；最终 4 组失败才是正式配置的规则缺口，不把初轮夹具失败归咎于内容。正式 data 未修改。

CLI 路径检查曾按 package.json 的 bin 路径调用失败（本机分发没有该文件），之后按既有预览记录核实并使用实际 dist/maker.js，状态读取成功；没有改工具安装或配置。状态返回的旧 10 月 2 日资源日志不算本轮运行故障。

### P2 的真实业务结果与 T1 交接

当前 16 条来源配方均通过真实收信、读信和剪词取得 token。14 条成功检查完整 Preview→重载→Reset→新事务 Preview→拒绝旧事务→Confirm→重复确认→重载→重复确认；正式状态在 Preview 保持不变，确认后与候选完整一致，无额外事件/写入/奖励。失败两条不会跳过或改成预期成功。

| 配方 ID | 实际结果 |
|---|---|
| recipe_n01_a / recipe_n01_b / recipe_n01_recall | 3 / 2 / 3 星，完整流程通过 |
| recipe_n01_conflict / recipe_n01_parade | 1 / 3 星，完整流程通过 |
| recipe_n01_c / recipe_n01_d | Preview 返回 RATING_UNCOVERED @ orderRatings；配置期望仍为 3 / 1 星 |
| recipe_n02_a / recipe_n02_b / recipe_n02_c / recipe_n02_d | 3 / 3 / 2 / 1 星，完整流程通过 |
| recipe_n02_brave / recipe_n02_wait / recipe_n02_home / recipe_n02_separate | 2 / 3 / 3 / 2 星，完整流程通过 |
| recipe_pa_fish_choir | 3 星，完整流程通过 |

9 条未来来源：n01_interview / n01_angry / n01_confused / n01_afraid = 3/2/2/2 星；n02_audit / n02_cat / n02_warm / n02_sad 和 pa_dream_ledger 均 3 星（ID 均有 recipe_ 前缀）。使用明确标记的纯计算技术引用，没有往 GameSession 或玩家库存注入词，不能宣布当前可制作。每条测试核对 future 标记与正文实际词源相符。

每条成功结果核对时间、可发货、期望事实、事实不重复及来源、重要事实片段覆盖、无占位符、星级与反馈；完整事实集合由日志 `[Story] RESULT` 输出，供队友 T2 原样核对。

强镇静矩阵固定 steady=0.8、calm=2.2；recall/forget 分别取 0、0.59、0.6。

| recall | forget | 实际 | T1 期望 |
|---|---|---|---|
| 0 或 0.59 | 0 或 0.59 | 强镇静一次，4 组通过 | 相同 |
| 0 或 0.59 | 0.6 | 强镇静缺失，2 组失败 | 强镇静一次 |
| 0.6 | 0 或 0.59 | 强镇静缺失，2 组失败 | 强镇静一次 |
| 0.6 | 0.6 | 记忆冲突一次、无强镇静，1 组通过 | 相同 |

这 9 组是纯事实边界输入，不声称均能由当前旧锅和正式词库配出。修复责任和规则 ID 仍按 [队友 T1](../队友实施计划_配置修复与剧情交付_2026-10-03.md)：rule_n01_missed_promise_unaware、rule_n01_hurt_customer_noticed、rule_n01_action_dulled；不改生产 unless 语义、不加星级兜底。

独立连续经营：首单 A → 第 2 天 N01 A → 第 4 天 N02 A，三次正式确认，余额 270；海盐 0、夜露 1、灰烬草 3、干花瓣 3。始终用真实初始账本，未补钱料，不据此推断完整周目经济通过。

### P3～P6 的出口与未完成项

- P3：已核对远端 main=bd606db、fengyycon=cbabddd（完整 SHA 由 `git ls-remote` 核对），内容仍 story-v0.3-r1；没有 T1/T2 修复提交可合入。相关回归已跑，但完整 B5 逐文件交付复核及版本提交未执行，不能发布已通过的新内容基线。没有提交、推送或 Maker 构建。
- 兼容边界：文件 schema=2 与内容 contentVersion 分开。现有 GameState 将内容/计算版本不符归为 migration_required 并保留文件；本轮复用 B5 对不兼容版本及禁止重算待确认的检查。T1 改规则须交新内容版本策略，不能维持旧 pending 却按新规则重算。
- P4：未实施。按原计划“失败则停在本步骤”，须先由 T1 修复并重跑 P2/P3；未创建重复页面、未在 UI 添加 N01 特判。
- P5：仅核对环境与本地存储文档；真实预览已停止，没有重新启动，因此剪词/pending/确认三个退出点均未验证，V13 不勾选。引擎文档说明 File 使用项目/用户隔离的相对路径，WASM 刷新会丢内存文件；本轮未取得本机受支持的持久退出运行方式与存储位置证据，不引入服务器/云存档绕过问题。A1～A19 的真实窗口/手机验收本轮均未执行，隔离测试仅对应部分逻辑。
- P6：未实施。现有 N02 文档仍为 A/B/C/D 与默认短句，缺正式变体 ID、事实条件、记忆冲突/趣味事实并存优先级及最终版本策略；未收到 T3 正式契约，不自行补文案或冻结未知业务字段。现有 appearCondition 仍只支持 dayMin/dayMax。

接续入口（本批历史）：队友交付 T1/T2 的 SHA、内容版本和规则 ID 后，合入约定内容，重跑两个正式 runner 及相关回归；通过 P3 再接 B6。T3 独立交付后再按 P6 对齐存档字段。无需重复确认既有规则。

## 后续增量：一次性 W-P1/W-P2（2026-10-03）

本节更新当前依赖，不覆盖上述历史失败日志。fetch 取得 f76de64/r2，原 T1/T2/T3 已在提交中交付；本机只读加载其 data 后正式原版流程 1265 项零失败，当前配方 16/16、未来纯计算 9/9、矩阵 9/9。旧 N01 六失败已消除，不再向队友重复索取原修复。T3 文档的程序契约与实现仍待 P6。

用户已确认一次性规则并先执行本机任务。W-P1/W-P2 技术专项 227/227；r2 全词一次性技术副本流程 1266 项零失败，三单后 270 金币、11 种可用词；WordToken 派生库存视图已提供。正式 r2 仍 30 词 reusable=true，正式 W01 两项门禁明确失败；当前工作区仍 r1，未合入 r2，也未提交/推送。P3 当前依赖改为 W-T1 正式切换、新版本和 W-T2 逐张词源账，不能把技术副本通过当作正式验收。B6/V13 未实施，剩余任务与证据见 [一次性实施记录](2026-10-03-single-use-word-implementation.md)。
