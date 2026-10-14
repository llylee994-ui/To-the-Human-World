# r3 正式一次性联调与 B6 接续

## 状态与背景

Completed（本批 r3 逻辑联调、B6 程序及隔离检查；W09 窗口/V13 未验收）。用户要求“拉取新代码继续”。从 fengyycon@45ed5a9 拉取实际 GitHub origin/main@50ee7a8；内容提交 324e9a1 已交付 story-v0.3-r3、全 30 词一次性及 W-T2 逐张词源账。沿用一次性计划与本机 P1～P6，不提交/推送/远端构建，不自动启动已停止预览。

工作区已有 B5、P1/P2、W-P1/W-P2 程序及交接改动必须保留。远端与本地重叠两文件：主线故事档案第一行的用户增量、一次性计划的本机状态说明；先备份并仅暂存这两项，快进后恢复合并。其他未提交和未跟踪文件不清理。

## 实施措施

1. 保留本地增量，快进到已核对远端；阅读 r3 交接及规则差异。
2. 用正式 r3 完成 W01～W08 的逻辑层检查、B1～B5 和内容流程回归；技术扩展来源与正式路线区分，旧版本文件原样保留。
3. 复核 B5 装配与事务，P3 逻辑出口通过后接 B6 简单可操作界面：真实来信/剪词/实例投料/候选结果/确认重置/跨天，库存来源与将消耗提示；不代写内容。
4. 运行 LSP 和适用检查，核对预览状态；真实窗口、手机和 V13 无证据不勾选。按实际进展更新交接。

## 影响文件树（实际）

```text
scripts/
├── debug/SingleUseWordTest.lua / StoryContentFlowTest.lua  正式策略与兼容验证
├── ui/PlayModel.lua                     导航、未提交选料与公共命令；无独立业务账本
├── ui/PlayView.lua                      可滚动文字/按钮、来源/剩余量、保存结果/消费提示
├── debug/PlayFlowTest.lua / run_b6.py    实际按钮回调与真实模块的隔离测试
├── debug/fixtures/HeadlessUI.lua        补子控件销毁/滚动适配；不模拟视觉验收
├── main.lua                            统一装配
├── README.md / 本机实施计划_新内容联调与B6_2026-10-03.md / 后端闭环与双人并行开发计划.md  状态
├── 一次性词条_规则与双人实施计划_2026-10-03.md 冲突合并、当前状态
├── actions/2026-10-03-single-use-word-implementation.md / 2026-10-03-story-integration-p1-p6.md  后续证据入口
└── actions/2026-10-03-r3-integration-and-b6.md 本记录
```

队友的 data/docs 更新仅从已提交远端合入，不由本机编写。具体新增文件与检查结果随实现更新。

## 自验证方法

合入前后本地保护文件与 diff 核对；正式 run_single_use_words、run_story_content、check_story_content、B1～B5；内容方检查不传 export（不写 docs）；Lua LSP、界面适配器检查、预览 status、git diff --check。本地隔离测试不代替真实窗口和持久退出。

## 自验证结果

### 拉取与保留

- fetch 后实际 origin/main=50ee7a8；`git merge --ff-only origin/main` 成功，仍在 fengyycon，未创建合并提交。只针对两份重叠文档建立 stash `18d9fcdbeb8a97bf86b6ef1887ffbc3f050c8981`，另存 `.tmp/r3-pull-preserve/` 原文备份；恢复后均保持未暂存。备份保留，不重复 apply。
- 一次性计划首段发生冲突：内容侧 r3 状态与本机旧 r2 技术验收状态并存。已保留内容交接及前轮证据链接，更新为 r3 已合入待验状态。主线档案第一行用户增量自动合并且当前 diff 仍仅该行；未改写队友新剧情。无未解决冲突。
- 正式 scripts/data 相对新 HEAD 无差异；没有手工改词策略、规则、余额、物料或剧情。原预览行动文档和主页 PNG 的 SHA256 与前轮保护值一致。原 B5/P1/P2/W-P1/P2 文件保留。

### 正式 r3 与既有回归

命令均在工程根目录运行。Python runner 使用 Lua 5.4 和隔离 File/UI 适配器；以下无真实窗口/引擎退出证据。

| 命令 | 实际结果 | 证据 |
|---|---|---|
| `python -B -X utf8 scripts/debug/run_single_use_words.py` | 正式 r3，30 词均一次性；229/229。默认使用当前策略/版本，只有同名双来源为明确技术夹具；旧档采用 r2 真实版本/可复用策略 | [专项](../../logs/r3-single.log) |
| `python -B -X utf8 scripts/debug/run_story_content.py` | 当前配方 16/16、未来纯计算 9/9、事实矩阵 9/9，1266 项零失败；含真实接单/基准/保存/确认/重置/重载的连续三单 | [正式流程](../../logs/r3-story.log) |
| `python -B -X utf8 scripts/debug/check_story_content.py` | 9 个测试方法通过；纸面枚举 16398 个合规结果均有覆盖（该枚举单独不是运行全流程） | [内容检查](../../logs/r3-content.log) |
| `python -B -X utf8 docs/验证/check_single_use_content.py` | 正式全词策略、字段冻结、旧基准拒绝、真实模块候选三单及 64 组合供给通过；30 可达/34 首次缺卡。未传 export，不改文案产物 | [内容方检查](../../logs/r3-teammate-words.log) |
| `python -B -X utf8 scripts/debug/run_b1.py` | 130/130 | [B1](../../logs/r3-final-b1.log) |
| `python -B -X utf8 scripts/debug/run_b2.py` | 212/212 | [B2](../../logs/r3-final-b2.log) |
| `python -B -X utf8 scripts/debug/run_b3.py` | 387/387 | [B3](../../logs/r3-final-b3.log) |
| `python -B -X utf8 scripts/debug/run_b4.py` | 339/339；队友报告的夹具失败已由本机原 P1 修正，不是 r3 内容失败 | [B4](../../logs/r3-final-b4.log) |
| `python -B -X utf8 scripts/debug/run_b5.py` | 373/373 | [B5](../../logs/r3-final-b5.log) |
| `python -B -X utf8 scripts/debug/run_b6.py` | 实际按钮适配器 51/51，完成连续三单，重置、失败/恢复、来源及数量路径通过 | [B6](../../logs/r3-final-b6.log) |
| `run_b1.py --config-failure load / c1 / stage1` | 三种入口配置失败均显示诊断、锁定操作，默认档不写入 | logs/r3-ui-config-*.log |
| `run_b1.py --debug-isolation existing / v2_corrupt / auto_read` | 三种既有调试隔离均通过，默认玩家档字节保留 | logs/r3-ui-isolation-*.log |

上述命令均退出 0。前三单正式 A→A→A：确认 3 单，270 金币，14 张取得、3 张消耗、剩 11 种词；没有补给或库存注入。W01～W08 的逻辑层检查通过，W02 的可见错误和 W05 来源展示另由按钮适配器覆盖，仍不等于 W09 真实窗口操作通过。

### B5 复核与 B6 实现

- 已复核 GameSession 真实装配、GameState 保存/安装/通知顺序与重入锁、SaveSchema/OrderAudit 版本和历史消费审计、OrderLifecycle 基准/事务/重置、WordToken 消耗策略，以及入口调试隔离。没有发现需本轮改写这些业务实现的缺陷；本轮新生产代码集中在 UI 和 main 装配。
- PlayModel 只保留导航和未提交选料。正式库存来自会话副本，首次有效选料前调用 BeginBrew，保存失败不保留本次选料；读/剪/接单/跨天/Preview/Confirm/Reset 都用既有公共命令。主/辅用具体 tokenId，重复定义遵循 recipePolicy，原料按份数占 equipment 槽，无可用卡不补发。
- PlayView 提供来信、阅读/剪词、词卡来源与历史、投料、字面失败原因、后续/星级、将耗卡与材料、确认/重置和历史重读。后续读取 Order.GetView 保存副本。确认失败保留待确认页面，重载 pending 自动回结果页；确认后重读不结算。
- main 保留 SafeAreaView、MiSans 和现有适配缩放，装配可滚动玩法区；EventBus 通知仅标记刷新，下一帧再重建控件，避免在事务/点击派发中修改控件树。历史调试切换协调器后，玩法入口锁住以保护玩家档。
- 炼制中的未提交选料是临时 UI 状态，退出后需重新选料；首次投料基准与已经保存的 pending 配方/后续仍随存档恢复。当前正式特殊物品规则未配置，显示槽位与不可投入说明，不编造附件玩法。
- P3 的内容/程序逻辑联调条件已满足，B6/W-P3 程序已接入；程序尚未提交，不能给队友一个已发布的程序 SHA。保留当前内容 SHA 与本地测试记录，提交/推送待明确指令。

### 未验收与后续

- Maker preview status 为 stopped / process_alive=false，同一 session=98eb3697-9d20-4786-ba98-325c4e18a42a。依据工程规则不启动已停止窗口；未刷新、未远端构建。
- W09 真实窗口布局/触控、P5/V13 的剪词/pending/confirmed 三个真实进程退出点、A1～A19 实机仍未验收。不能把 HeadlessUI 的按钮测试写成视觉或退出验收。
- P6 未实施：T3 正文变体已交，但新字段及存档契约仍需按原计划对齐后由内容侧落配置。本轮一次性接续不把未接入主线/变体/结局当作运行能力。
- W10 完整路线仅有内容方模型，本轮未重复运行全部主线文稿/经济检查，亦未接入后续 20 单或身份；不把文稿合入等同玩法实现。

### 收尾结果与操作入口

- 本机 maker-lua-lsp 全 scripts 最终诊断：2026-10-03 19:14:36，0 Error / 0 Warning / 0 Hint，见 [诊断](../../logs/lua_diagnostics.log)。过程中修正 UI 可变字段的字面量类型推断、可空子控件/输入检查；未屏蔽诊断。界面实际按钮检查保持 51/51。
- `git -c core.safecrlf=false diff --check` 通过；7 份本批开发文档的 82 个本地链接有效（加入本节诊断链接前计数）。新增 UI 单文件 177/216 行，未超过拆分阈值。无未解决冲突、无暂存改动；scripts/data 相对合入 HEAD 不变。
- 最终预览状态仍 stopped；没有启动/刷新。按 [本机计划 P5](../本机实施计划_新内容联调与B6_2026-10-03.md#7-p5v13-与真实交互补验)“不因本计划自动重启已停止窗口”执行，故真实窗口与退出项保留未验收。
- 下次实际启动后：来信→打捞→阅读→逐处剪词→接单→选主词和原料→炼药发货→查看后续→重置→换料再发货→确认；再从来信页结束当天接下一单。词卡页显示具体来源、当前剩余及历史数量；后续页可重读已确认结果。
- 若默认档为 r2 或坏档，界面显示原诊断并锁定，不自动清档。真实 V13 应先明确独立验收槽与受支持的持久存储环境，再验证剪词、pending、confirmed 三个退出点。B6 当前未提供清档/新槽按钮来绕过兼容门禁。

### 后续复核接续（本记录保留 r3 历史结果）

2026-10-03 后续已合入 aef9558／story-v0.4-r1，并发现和修复准备阶段卡关、恢复槽位问题，补类别与试做观察。当前为 29 定义、13 种／14 张，B6 检查更新为 170/170；完整差异、回归和计划影响以 [本轮复核记录](2026-10-03-r3-b6-review-and-word-contract.md) 为准。旧文中“未发现缺陷”“P6 旧 T3 已交”等是当轮证据，新 N02 需要重新交接要求、剪词与变体，不能直接套旧四词稿。
