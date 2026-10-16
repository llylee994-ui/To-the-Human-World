# 11 封委托的跨天与结局门禁

## 状态与情况

- 状态：Completed（触发规则与跨天限制已实现，自动检查完成；原生窗口／手机待验收）。分支 `feat/ending-flow`，基线 `6bbeefc`，独立工作区 `D:\taptap\To-the-Human-World-endings`。
- 用户于 2026-10-15 明确要求：当天信件发货成功才能结束今天；11 封全部完成才开放学徒和愿望结局；取消第 14 天强制收尾；船票保留提前离开。表现形式后做，主线不接入。
- 完成以正式确认并保存成功的订单记录为准，一至三星均算；保留学徒至少 8 单三星及四件家居的既有条件。
- 原代码允许空草稿接单、未收信直接跨天，且 D14 可零单收尾。原规格对应旧规则，本轮同步接口与当前规格。
- 旧档兼容：经营档可按原每日一捞补收并发货，允许超过 D14；已冻结的合法旧结局保留。旧未完成收尾页可返回结束前，新的结局命令须满足 11 单完成。
- 不改剧情正文、配方、价格、存档槽、演出、3D 宿主；不提交、推送、构建或新建 Maker 项目。Maker 状态为本工作区未绑定，本轮不运行 init。

## 实施措施

1. 在 `ReleaseEndings` 集中派生正式完成记录与每日结束条件；查询和命令共用同一门禁。
2. 已收到但未发货的委托阻止跨天；还有今日可打捞委托且有额度时，先收信发货。旧档积压不要求同一天突破一捞额度，已收委托全部完成后可次日补下一封。
3. 全部必需订单完成才允许收尾；完成最后一单后仍留在经营态，主动结束当天或收尾才进入选择。船票继续使用独立启程事务。
4. 取消经营日期上限；旧 D14 收尾仅在历史存档审计中保留兼容，未完成旧收尾显示恢复入口。
5. 更新旧断言及新增业务回归；保留保存失败、提交不确定、重复确认和恢复保护。同步当前规格、接口手册与人工验收步骤。

## 影响文件树（实际）

```text
scripts/
  core/GameState.lua                         跨天协调及收尾路由
  systems/ReleaseEndings.lua                 完成事实、每日门禁、结局资格
  systems/ReleaseCoordinator.lua             终局命令与查询门禁
  systems/ReleaseChapterAudit.lua            历史终局及无日期上限的存档审计
  ui/landscape/{Panels,ReleaseClosingView,WishView}.lua  必要状态提示与恢复入口
  debug/ReleaseDayGateTest.lua + .meta        每日门禁、旧档、真实 11 单回归（新增）
  debug/{ReleaseEndingTest,ReleaseEndingSaveTest,ReleaseClosingIntegrationTest}.lua  结局与保存事务回归
  debug/{ReleaseUITest,ReleasePurchaseTest}.lua  控件门禁与购买回归
  debug/{NumericV02FlowTest,ReleaseFlowTest}.lua  58 配方独立旧档见证与新周目路线分开
  debug/fixtures/{ReleaseFixtures,ReleaseEndingFixtures}.lua  正式发货及历史存档测试夹具
  debug/run_release_rules.py + .meta         隔离专项测试入口（新增）
  前端接入接口手册.md                         当前调用契约
  ui/landscape/人工验收.md                    当前验收步骤
  actions/2026-10-15-ending-day-gates.md       本行动记录
docs/superpowers/
  specs/2026-10-13-ordinary-release-design.md  同步用户确认的当前规则
  plans/2026-10-13-ordinary-release.md         标明历史步骤已由当前规则替代
```

## 自检方法

- 隔离 Lua 5.4 与内存存档：未收、未读、未接、已接未发、投料、待确认、重置都不可越过未完成委托；发货失败不放行，成功与重读后放行；重复发货不重复推进。
- 用真实 11 单路线核实第 10 单仍不可收尾，第 11 单后主动选择学徒/愿望；船票未完成剧情仍可提前离开。
- 构造符合旧版结构并经过完整存档审计的 D14 经营/收尾/结局夹具，验证补做、返回与历史结局保留；不篡改玩家存档。
- 使用已安装 EmmyLua LSP 检查受影响代码，核对 Git 差异及 UTF-8；检查本目录预览状态，不启动已停止预览。
- 逻辑与控件适配器检查不代替原生窗口、手机和真人完整周目验收。

## 自检结果

### 已完成检查

命令工作目录为本独立工作区。以下测试均使用 `python -B -X utf8 scripts/debug/run_release_rules.py`，附加 `--lua-deps D:\taptap\To-the-Human-World-bgm\.tmp\b1-python`；UI、购买、收尾模型检查再附加 `--engine-libs D:\taptap\To-the-Human-World-bgm`。依赖只读借用，未安装包或修改其他工作区。

| 参数／检查 | 实际结果与范围 |
|---|---|
| `--suite gates` | 8 场景通过；未收至重置各状态、1/2 星正式发货、失败/不确定提交、重复确认、D14→D15→D16、旧收尾与旧结局、未完成委托时购票恢复 |
| `--suite route` | 实际 11 单在 D1～D11 正式发货；前 10 单拒绝收尾，第 11 单开放；8 三星与真实购买四家居后选择学徒、恢复，再选择愿望；均保存和重读成功 |
| `--suite flow` | 58 配方独立见证全部通过；另一个真实 schema 4 新周目连续完成 11 单、收集 61 卡、消费 11 卡、基础路线余额 1130，采购审计通过 |
| `--suite saves` | 24 场景通过；结束/恢复/新周目保存故障、提交不确定、幂等、审计保护 |
| `--suite closing` | 真实 PlayModel 确认收尾、日期不增加、经营关闭通过 |
| `--suite ui` | 当时全部 10 场景通过；新增最后一单结束当天控件后以 `--filter 'completed story day'` 单独通过，总计 11 个不同 UI 场景 |
| `--suite purchases` | 全部 7 场景通过，含船票 D10/D11、报价过期、家居、真实交错发货 |
| `--suite endings --filter 'departure D10'` | 通过；票价、日期、幂等、恢复 |
| `--suite endings --filter 'D14 cannot close'` | 通过；D14 未完成时 NextDay／BeginClosing 均拒绝且不改状态 |
| `--suite endings --filter 'consumed sample'` | 通过；消耗词仍可作样本、顺序、冻结正文、恢复及新周目 |
| `--suite endings --filter 'empty accepted'` | 通过；未发货接单不能跨天或收尾，购票恢复保留重置日志 |
| 内容加载与 `ValidateStage1()` | 每次入口均通过，内容版本仍为 `ordinary-release-v2`，未修改正式剧情/数值数据 |
| `git diff --check`、UTF-8 严格解码、行动文档链接核对 | 最终差异通过；25 个改动／新增文本文件全部可解码，相关行动记录链接有效 |
| `python -B -X utf8 .tmp/check_ending_rules_lsp.py`（已安装 EmmyLua stdio LSP） | 最终 17 个改动 Lua 文件全部收到诊断，0 error / 173 warning；主要为测试夹具动态字段、控件文本函数及可空值的类型提示，并非零警告。原始证据 `.tmp/ending-rules-lsp/diagnostics.json`，包含文件哈希；未修改引擎库或全局设置 |
| Maker 状态与 `taptap-maker preview status --target-dir D:\taptap\To-the-Human-World-endings --json` | 本工作区未绑定；返回 `Preview requires a bound Maker project with .maker-mcp/config.json.`。未 init、启动/刷新预览、构建或发布 |

### 验证边界与剩余项

- 独立配方允许从明确旧漏日夹具收集词来源，完整新周目始终用真实每日发货门禁；未把独立见证当作 58 条完整周目的真人验收。
- 事务/UI 专项使用 `SmallComplete` 缩小测试专属必需订单集以避免每个故障点重复长周目；这部分不证明正式 11 单门槛，门槛由上表真实 `route` 单独证明。
- 先前全量 `ReleaseEndingTest` 多条长路线运行未完成，未记全量通过；以完整 11 单路线及定向边界检查作为本轮证据。
- 原生窗口、手机触控与真人周目未验收；逻辑和控件适配器检查不能替代这些验收。
- 结局演出、主线按用户要求留待后续；本轮没有提交、推送或 Maker 发布。
