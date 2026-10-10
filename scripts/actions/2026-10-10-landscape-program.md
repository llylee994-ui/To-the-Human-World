# 横版程序 P1–P6 实施与交付

## 状态与情况

Completed（本轮程序及接口交付；真实主线映射与手机验收仍未完成）。用户授权按Maker main的横版程序计划P1–P6实施、更新实际接口手册并通过Maker官方流程提交推送。起点fengyycon@81681c2，远端70454e2新增两份计划及说明。工作区有其他窗口的方向文档、素材和meta删除，全部保留。docs/README.md和手机历史记录存在双边新增说明，先备份并合并文字，不覆盖任一方。

本轮遵循program计划第3节契约；前端负责PlayView和ui/landscape及美术，程序侧负责PlayModel/main/core/systems。计划采用的每日1次、旧档迁移当日次数保守耗尽、无单不自由试做等默认值明确标注，不作为额外剧情或平衡定案。按本轮明确计划授权新增非剧情data/gameplay.lua，其余内容不改。

## 实施措施

- [x] 同步70454e2，合并两份重叠说明，保留本地工作。
- [x] P1：只读查询契约、草稿合法性与字段样本先提供给前端。
- [x] P2：schema3、显式旧schema2路径、完整迁移与草稿保存。
- [x] P3：按次冻结Preview、Reset不回退live、Confirm只结算一次。
- [x] P4：永久journal、分组、历史来源与状态审计。
- [x] P5：每日成功捕捞计数、重复请求和跨天门禁。
- [x] P6：真实案件投影空态、正式入口隔离及接口手册。
- [x] 必要逻辑/迁移/故障/数值/LSP检查。
- [x] 官方提交及双端核对。

## 影响文件树

- systems/PlayQueries、RecipeDraft、BrewJournal、OrderTrial、CaseBoardProjection：新查询/草稿/记录/事务/案件投影。
- core/GameSession、GameState、SaveSchema、SaveSystem、GameFlow、SaveMigrations、SchemaProjection：装配、完整候选与版本迁移。
- systems/Narrative：兼容新计数的只读可收信查询；既有 Order/OrderLifecycle/OrderAudit 不改，通过 SchemaProjection 临时投影复用其审计和八步计算，原 schema3 ID 先单独严格审计，投影不落盘。
- ui/PlayModel、main、debug/DebugPanel：程序接口、默认生产schema、隔离入口；不接管前端组件。
- data/gameplay.lua：本轮计划默认捕捞上限，非剧情配置。
- debug/LandscapeFlowTest、LandscapeEntryTest、LandscapeNumericFlowTest、SaveV3MigrationTest、run_landscape_flow.py：新版行为/迁移/正式入口/全配方。
- debug/fixtures/B5Fixtures、OrderRecoveryTest、SingleUseWordTest：旧夹具显式 schema2；NumericV02FlowTest 可跑2/3；run_b1识别新版正式入口测试。
- README.md、scripts/前端接入接口手册.md：横版接入状态和实际接口增量，保留既有文档改动，提交仅包含本轮增量。
- 本记录：阶段结果/交付；.tmp/landscape-program-20261010与logs：忽略的保护备份和检查证据。

## 自验证方法

先验证查询不写档及旧规则差距，再补实现。重点迁移idle/accepted/brewing/pending/confirmed、草稿与journal恢复、写入/编码/读回/提交前后失败、重复发货、过期事务、重置后补货及新基准、每日计数和来源。保留旧数值/分支/评分；完整LSP零错误。仅后台测试，不重启前台窗口，不把File/UI替身当手机证据。

## 自验证结果

### 程序证据（2026-10-10，本机后台）

- `python -X utf8 scripts/debug/run_landscape_flow.py`：141 个流程断言 + 70 个迁移断言通过。查询零写档/事件；重复剪词、不同来源重复规则、主辅取出、草稿故障、补剪/补货、字面失败、重复 Preview/Reset/Confirm、过期凭据、四阶段恢复、每日次数、未知与篡改结构保护。
- 故障矩阵：草稿/Preview/Reset/Confirm × write/encode/readback/before_commit/after_commit/uncertain；未提交不安装、不发事件，已提交恢复同一结果。通知失败业务仍已提交。迁移另覆盖同六类故障，原有效代保留或新代可恢复。
- 迁移：idle/accepted/brewing/pending/confirmed/reset；真实v1无历史计数可迁、有计数无明细保持锁定；未知版本/内容版本不符/损坏保留文件。旧pending正文、评分、ID不重算；缺失旧试做不伪造。生产仍使用 numeric_v02_trial 原槽。
- `python -X utf8 scripts/debug/run_landscape_flow.py --entry`：正式 schema3、开发工具隐藏、错误提示触屏关闭仍锁写、首次读取损坏后重试仍为同槽，通过（UI/File替身）。
- `python -X utf8 scripts/debug/run_landscape_flow.py --numeric`：schema3 的58条登记配方与同档11单链通过，61卡、消耗11卡、采购124、结余146；重置后正文/评分与原配方一致。
- `python -X utf8 scripts/debug/run_numeric_v02.py --flows`：显式schema2的同一58配方/11单链通过；`--shop` 与 `--startup` 通过，独立玩家槽保存恢复、不覆盖旧slot1。
- `python -X utf8 scripts/debug/generate_numeric_v02.py --check`：61词/11单/58分支/196规则格/58登记配方一致；`run_numeric_v02.py` 真实来源、互斥边界和发货通过；`check_numeric_runtime.py` 9325个区间样本通过。
- 历史内容3dbca09的隔离兼容回归：OrderFlowTest 373/0、SingleUseWordTest 229/0、PlayFlowTest按钮172/0、BrewPreparationTest 104/0。`run_story_content.py --content-ref 3dbca09`：1265/0，已到达16/16、未来纯计算9/9、组合矩阵9/9。不是当前投放包的手机证据。
- MobileFrontendTest 使用当前v02内容通过，保留剪词纸张/按钮/滚动标记、自动槽、保存失败、一次确认、触屏关闭。曾误用历史内容导致词ID不匹配；改用该测试实际依赖的当前内容后通过，未修改测试预期掩盖业务失败。
- Maker Lua LSP：0 error、15项既有warning、1 hint；新增程序无遗留静态错误。`git diff --check` 通过（仅换行提示）。
- 本地 preview status：stopped / process_alive=false，遵守约定不重新启动、不移动鼠标。没有新增实际窗口/手机验收证据。

日志在忽略目录 `logs/landscape-flow.txt`、`landscape-entry.txt`、`landscape-numeric.txt`、`landscape-legacy.txt`、`landscape-mobile-legacy.txt`、`landscape-story.txt`、`landscape-program-lsp/`；不将日志、临时目录、引擎资料或凭证提交。

### 实施中发现与修复

1. Narrative原只接受五字段gameFlow，新增捕捞计数曾被当未知字段拒绝；现按实际快照选择对应流程验证。
2. schema3第二次接单曾带回旧审计投影的历史baselineId，永久记录关联校验拒绝；现仅复制新增接单集合，已确认历史保留原值。全配方及11单链复核通过。
3. 首次读取坏档的activeSlot原先未绑定，恢复可能落到默认slot1；现读取前绑定所请求的槽，损坏后按钮同槽重试通过。
4. 初次“无原料睡眠卡应字面失败”的测试假设错误；现用真实信任主词验证不满足睡眠条件，没有修改数值规则。

### 交接与未完成项

- P1–P5程序能力已实现并通过上述逻辑检查；P6正式入口隔离与案件空态已实现。
- 没有运行中的主线案件节点/联系映射，CaseBoard返回unopened；P18真实shipped线索解锁未交付，不从reset记录推断线索。
- 每日一次、旧档当日额度保守耗尽是计划默认值；特殊物品、捕捞升级及价格未接入；无单不自由试做。
- 前端F1–F6仍按前端计划维护PlayView/ui/landscape/美术。导航和历史只读契约已提供，不覆盖前端组件。正式横屏布局、触控、拖拽、长信/记录滚动、安全区、真实进程退出恢复均待实际设备验收；本轮不宣称手机通过。
- 官方交付见下节。本轮仅交付本行动记录列出的文件；其他窗口的文档、美术和meta删除保留在原工作区。

## 官方交付结果

- 本次沿用既有 main 交付工作区 To-the-Human-World-b6-submit，仅拷贝30个本轮负责文件；README/接口手册只取本轮增量。未提交其他窗口的素材、meta删除、方向文档或编辑器工作。
- Maker 官方 maker_build_current_directory：提交 `5ec7354`，pushed，远端构建成功（53秒）；项目绑定 76909fb8-3dc3-4adc-8c49-fe56bab4393e 未变。构建自动生成13个新文件meta，形成 `ea5a11a`，已核对只含资源索引。
- GitHub main/fengyycon 同步到 `ea5a11a`；与 Maker main 的 ls-remote SHA 相同。未强推。
- 已读官方返回 runtime.log 和 state.json：日志当前为空，watcher连续失败0、lastError=null。表示监听正常，不表示游戏已被打开或手机验证通过。
- 此记录作为交付归档再走同一 Maker 官方流程，同步GitHub；无新的Lua/内容变更。最终归档提交以工具返回和本轮最终回复中的SHA为准。
- 仍未完成：真实主线案件映射；前端F1–F6横版组件、实际窗口布局/触控/安全区、手机真实退出恢复验收。
