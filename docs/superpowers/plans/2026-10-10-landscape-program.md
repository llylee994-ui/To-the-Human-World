# 《寄往人间》横版交互与程序侧实施计划

> **For agentic workers:** 使用 `executing-plans` 逐任务实施，按复选框记录证据；本计划不授权自动派生其他会话。Maker 项目提交统一使用 `maker_build_current_directory`，不用独立 Git 提交、推送或 PR 流程。

**Goal:** 为横版前端提供稳定的业务接口，实现可恢复的投料草稿、永久试做记录、按次冻结的炼药事务与每日捕捞计数，同时保留既有词值、分支、评分和一次性来源规则。

**Architecture:** 继续使用 GameSession → GameState 完整候选校验、保存、安装、通知的单一事务链。新增只读查询与试做日志，schema 3 把 journal 放在炼药回滚范围外；未确认结果只计算候选，正式状态只在发货时结算。前端负责导航与动画，程序侧负责合法性、去重和存档。

**Tech Stack:** UrhoX Lua 5.4、现有 core / systems 模块、SaveSystem 双快照与提交记录、SaveJson 精度保护、现有隔离 File/UI 测试运行器。

## 0. 范围与基线

- 规划日期：2026-10-10；代码基线 `d0497cb`。这是详细实施方案，本轮不实现业务代码。
- 对应前端计划：[横版前端实施计划](2026-10-10-landscape-frontend.md)。第 3 节是两边共用接口规范，新增接口是提案，不是当前可调用能力。
- 用户已将目标改为横版；保留 App 955210 / Developer 461896 / SCE m_h4x3 / 现有 Maker 项目绑定。停止旧竖屏纠正路径，不新建应用。
- 当前数据内容为 `story-numeric-v02-r1`，普通订单运行接入覆盖首单和 N01–N10。默认试玩槽为 `numeric_v02_trial`，旧 `slot1` 不自动覆盖或搬迁。
- 方案默认值与前端计划第 1 节相同：先读试做后续，再重置或发货；主词取出不晋升辅词；每日一次捕捞、升级另定；无订单不产生自由实验结果；配料草稿保存；待处理结果锁定变更。
- 这些默认值来自用户需求与本会话建议，不冒充逐项批准。用户改变规则时先同步两份计划，不能静默改一边。
- 本轮不改词条属性、数值、合成八步、分支阈值、评分、正文、原料价格、报酬或投放节奏。
- 不删除内部 recipe。用户删除的是配方书独立功能，不是试做和记录需要的投料数据。
- 延续完整候选 → 校验 → 保存 → 安装 → 通知；不由 EventBus 做二次结算，不另写一个不受提交保护的日志文件。
- 开发前读取 engine-docs/lua-scripting-guide.md 和至少三个相关例子：examples/14-ui-widgets-gallery.lua、examples/15-inventory-drag-drop.lua、examples/16-virtual-list-10k-items.lua。它们用于理解接口接入、拖放数据和列表投影；存档行为以项目自身 SaveSystem 和故障夹具为准，不引入云存档。

## 1. 已确认的代码现状与差距

| 现状 | 依据 | 需要改变 |
| --- | --- | --- |
| Edit 首次有效投料调用 BeginBrew | ui/PlayModel.lua | 选料改为保存草稿，点击开始熬制才冻结本次基准 |
| brewing / pending 阶段禁止剪词、采购、打捞、跨天 | core/GameState.lua CheckAction | 配料阶段可变更；pending 保持锁定 |
| Reset 把 live 恢复为首次基准，并清 pending / recipe | systems/OrderLifecycle.lua | 重置只撤销未结算候选、返回配料；不回退后来获得的正式资源 |
| confirmedById 只有正式发货记录 | systems/OrderLifecycle.lua | 添加所有成功试做历史，重置保留 |
| GetDraft 主要存在 PlayModel 内存 | ui/PlayModel.lua | schema 3 保存草稿；退出和同槽恢复不丢合法选料 |
| canSalvage 为 boolean，Receive 不建立每日用次数账 | core/GameFlow.lua / GameState.lua | 成功收信原子递增当天计数；重复请求不多扣 |
| GameSession targetSchema=2，多处直接写 schema=2 | core/GameSession.lua / GameState.lua / SaveSystem.lua | 有边界地引入 schema 3 与迁移；不能只改一个版本号 |
| 数值运行包已接原料采购，旧接口手册还写 Shop 未实现 | systems/Economy.lua 与 v02 接入说明 | 复用真实 Shop，不重新建立商店账本 |
| 正式主线案件查询不存在，运行包不代表主线已全部接入 | data.content、当前模块与运行接入说明 | 按实际已解锁内容提供案件投影；无映射时说明未开放 |

## 2. 文件责任与修改边界

| 文件 | 操作 | 责任 |
| --- | --- | --- |
| scripts/systems/PlayQueries.lua | 新增 | 正式快照到前端视图的纯查询；不执行命令 |
| scripts/systems/BrewJournal.lua | 新增 | 记录结构、追加 / 更新状态、分组键、查询与校验 |
| scripts/systems/RecipeDraft.lua | 新增 | 草稿合法性、自动主辅分配、原料份数与来源限制 |
| scripts/systems/OrderTrial.lua | 新增 | schema 3 试做、重置、确认的候选计划；计算仍复用现有模块 |
| scripts/systems/CaseBoardProjection.lua | 新增 | 已收到线索与正式事实到案件图的只读投影 |
| scripts/systems/OrderLifecycle.lua | 修改 | 保留订单创建、适配新状态与命令；调用 OrderTrial，保持职责清晰 |
| scripts/systems/OrderAudit.lua | 修改 | 审计 schema 3、草稿、候选与日志关系；不重新生成历史正文 |
| scripts/core/GameState.lua | 修改 | 新门禁、草稿命令、计数与完整候选提交；schema 派发与恢复 |
| scripts/core/GameSession.lua | 修改 | 装配 journal / queries、schema 3 初态、测试可显式选择旧 schema |
| scripts/core/SaveSchema.lua | 修改 | 保留 ValidateV2，新增 ValidateV3；严查 journal 与新流程字段 |
| scripts/core/SaveMigrations.lua | 新增 | 纯迁移函数 MigrateV2ToV3，不读写磁盘或清档 |
| scripts/core/SaveSystem.lua | 修改 | 显式支持 schema 3 外层包；保留双快照、提交记录与错误语义 |
| scripts/core/GameFlow.lua | 修改 | 每日使用次数校验与查询；旧快照兼容需按版本处理 |
| scripts/data/gameplay.lua | 新增 | 非剧情配置：salvageDailyLimit=1，暂不含升级价和额外概率 |
| scripts/ui/PlayModel.lua | 修改 | Drop / TakeOut / ReturnHome / OpenAttempt，连接新草稿和事务 |
| scripts/main.lua、scripts/debug/DebugPanel.lua | 修改 | 正式 / 开发入口隔离、装配参数、手机关闭；不重画前端 |
| scripts/debug/LandscapeFlowTest.lua | 新增 | 状态、投料、日志、捕捞和查询集成检查 |
| scripts/debug/SaveV3MigrationTest.lua | 新增 | v2 各阶段迁移、故障与来源对账 |
| scripts/debug/run_landscape_flow.py | 新增 | 调用现有 content_test_runtime.run，不复制运行器 |

前端拥有 `scripts/ui/landscape/` 和 PlayView 装配；程序侧主改 PlayModel、main、core、systems。遇到队友已有同职责文件先复用，避免重复实现与覆盖。

## 3. 两侧共用接口契约

### 3.1 基本约定

统一采用现有 Result：`{ok=true,value=...}` 或 `{ok=false,error={code,path,message,details?}}`。查询返回副本，数组为从 1 开始的稠密数组；“暂无内容”与“查询失败”不同。ID 不透明，不由 UI 拼接。

`session.queries` 由 GameSession 装配，查询时读取协调器当前快照，不缓存过期正式状态。模型改动成功后前端重新查询；通知只促刷新。

### 3.2 查询方法（均为拟新增）

| 方法 | Result.value 字段 | 用途 |
| --- | --- | --- |
| GetLetters() | LetterRow[]：`letterInstanceId, sourceLetterId, title, senderName, read, remainingCutCount, orderStatus` | 抽屉；orderStatus 为 unaccepted / accepted / pending / confirmed |
| GetWordTray() | `cards, categories`；card 为 `tokenId, wordId, text, categoryId, sourceLetterInstanceId, sourceTitle, available, selectedRole`；category 为 `id,title,availableCount` | 托盘；selectedRole 为 false / main / aux，已消耗来源仍可历史查询但不可投入 |
| GetJournalStories() | JournalStory[]：`sourceLetterId,title,attemptCount,discoveredOutcomeCount` | 只列已收到的故事，收到但无试做时 count=0 |
| GetJournalPage(sourceLetterId) | `sourceLetterId,title,outcomes`；outcome 为 `outcomeKey,displayTitle,attempts`；attempt 摘要为 `transactionId,status,stars,recipeSummary` | 同后续合并；未知/未收到故事拒绝，不泄露配置 |
| GetAttempt(transactionId) | JournalRecord 副本，结构见第 4 节 | 全屏历史阅读，不调用 ResolveDirect / Rate |
| GetSalvageView() | `dailyLimit,usedToday,remaining,availableLetterIds,enabled,reasonCode,message` | 海边；没有瓶子与没有次数分别说明 |
| GetOrderSummary() | `orderId,phase,sourceLetterId,title,requirementDesc,draft,pending,actions,requirementHint` | 无单返回 orderId=false, phase=idle, draft=false, pending=false；phase 为 idle / accepted / pending |
| GetShopView() | `currency,items,enabled,reasonCode,message`；item 为 `ingredientId,name,price,ownedQuantity,remainingToday` | 只卖已有原料，不卖词卡；价格和限购复用正式配置 |
| GetCaseBoard() | `availability,nodes,edges`；node 为 `id,kind,title,summary,sourceIds`；edge 为 `from,to,label,sourceIds` | availability 为 ready / unopened；只返回真实已解锁内容 |

`requirementHint` 为 `{evaluated=false}` 或 `{evaluated=true,canShip,failures}`。草稿缺主词时不假算成功；允许在正式业务外对副本做现有 Calculate/Evaluate 只读预检，最终 Preview 必须再次校验。未发现后续不放入 hint。

GetOrderSummary.actions 使用现有 `{enabled,reasonCode,message}`。pending 只投影已保存正文、星级和事务 ID，不将 candidateLive 暴露给界面用于改余额。

### 3.3 命令与模型方法

| 接口 | 请求 / 返回 | 行为 |
| --- | --- | --- |
| session.order.UpdateDraft(request) | `{orderId,draft}` → Result<Draft> | 在 accepted 阶段校验并保存整份草稿；无变化不写档 |
| session.order.Preview(request) | `{orderId,equipmentId,mainTokenId,auxTokenIds,ingredients,specialItemIds}` → Result；pending 返回 `orderId,phase,transactionId,potion`，条件不足返回 `phase=accepted,requirementResult,potion` | schema 3 内部建立本次基准并保存结果；外部不传 baselineId |
| session.order.Confirm(request) | `{orderId,transactionId}` → 现有确认 Result | 结算一次并标记 journal=shipped |
| session.order.Reset(request) | `{orderId,baselineId,transactionId}` → Result，phase=accepted | 保留历史与正式 live，返回可继续剪词/采购的配料阶段 |
| model.Drop(kind,id) | kind 为 word / ingredient → Result<Draft> | word 空主位先主，否则辅；ingredient 每次一份 |
| model.TakeOut(kind,id) | 同上 → Result<Draft> | 词按 tokenId 匹配；主词取出留空，原料减一份 |
| model.ReturnHome() | 无业务 Result，设置模型 page=home / dirty=true | 不清草稿、不调用 Reset / CancelBrew / Confirm |
| model.OpenAttempt(transactionId) | Result<JournalRecord>，模型记 selectedAttempt | 历史只读；不更改 currentOrder |

保留 model.Read / Cut / Accept / Buy / Preview / Resolve / NextDay / Reload / GetDraft 的调用方式。Resolve(false) 从当前 pending 构建合法 baselineId，UI 不自行拼凭据。

schema 3 的 BeginBrew 不再作为前端步骤；对旧 schema 2 夹具保留旧入口。新生产路径直接调用 Preview，不进行“先保存 BeginBrew 再保存 Preview”的双提交。

Preview 外部请求不含 baselineId，但冻结后内部保存的 recipe 必须补齐 orderId 与 baselineId，继续满足 ResolveRecipe 和结果审计。外部重复请求先与草稿/已保存 recipe 的选料投影比较，不拿缺少 baselineId 的表直接与完整 recipe 做相等比较。

跨天默认已有 accepted 订单可保留；若有非空草稿，查询门禁给出 `DRAFT_NOT_EMPTY` 并提示先清空投料。UI 提供清空后再请求跨天，不隐式丢草稿。无当前订单或空草稿跨天依旧复用 NextDay。

## 4. schema 3 数据和不变量

### 4.1 外层数据

```lua
-- 拟定结构；下面标识只是说明字段，不是生产默认值。
data = {
    contentVersion = content.contentVersion,
    revision = 0,
    nextOrderSerial = 1,
    live = {gameFlow={}, letters={}, wordTokens={}, economy={}, world={}, narrative={}, orders={}},
    currentOrder = false,
    journal = {byAttemptId={}, attemptIds={}},
}
```

journal 在 live 与 baseline.live 之外；由 GameState 保存同一个 envelope。不要给 live 增加第二份试做记录，不单独用文件或 UI 缓存保存历史。

### 4.2 当前订单与草稿

```lua
-- accepted 时 baseline / recipe / pending 为 false；draft 为合法可编辑草稿。
currentOrder = {
    orderId = orderId, letterInstanceId = letterInstanceId,
    phase = "accepted",
    draft = {equipmentId=equipmentId, mainTokenId=false, auxTokenIds={}, ingredients={}, specialItemIds={}},
    baseline = false, recipe = false, pending = false,
    nextAttemptSerial = 1, lastResetTransactionId = false,
}
```

- schema 3 持久阶段只有 accepted / pending；“正在播放烟雾”是前端动画状态，不是持久 brewing。
- 草稿可以缺主词，但不能带未知设备、不可用词卡、重复 token、超槽原料和未知特殊物品。当前未支持特殊物品投料时保持空数组，不捏造接口。
- 每次有效 Drop / TakeOut / Edit 生成候选并保存；指针移动不写档。保存失败草稿与正式库存均不改变。
- 选入卡仍 available=true，通过 draft 的 selectedRole 表达暂用；正式消耗只在 Confirm。
- 跨天、订单切换与恢复必须检查草稿，不能让同一卡投入两个未完成订单；仍只允许一个当前订单。

### 4.3 JournalRecord

```lua
record = {
    transactionId = transactionId, orderId = orderId,
    sourceLetterId = sourceLetterId, letterInstanceId = letterInstanceId,
    attemptDay = day, status = "pending", -- pending / reset / shipped
    originSchema = 3, -- v2 导入历史为 2
    contentVersion = contentVersion, synthesisVersion = synthesisVersion,
    recipe = recipeSnapshot,
    recipeDisplay = {main=false, aux={}, ingredients={}},
    followup = followupSnapshot,
    rating = ratingSnapshot,
    outcomeKey = outcomeKey,
}
```

recipeDisplay.main/aux 保存 `tokenId,wordId,text,sourceLetterInstanceId`，ingredients 保存 `ingredientId,name,quantity`，确保历史卡已消耗时仍能看配方；它们与 recipe 来源必须一致。正文与 rating 直接复制已保存结果，不因读书重新计算。

outcomeKey 由 followup.letterId 与有序 fragmentIds 用长度前缀编码组合，避免连接字符串碰撞；只用于分组，不替代结果规则 ID。不同试做保留 transactionId 和各自星级，不能把最高星覆盖所有历史。

### 4.4 事务规则

| 操作 | live | currentOrder | journal |
| --- | --- | --- | --- |
| 投料、取出 | 不扣资源 | 更新并保存 draft，保持 accepted | 不变 |
| 条件不足的合法试做 | 不变 | 保持 accepted，无 pending / 基准残留，草稿保留 | 本轮不记录无后续失败，不编造星级 |
| 成功试做 | 不变 | 当前 live 建本次 baseline；存候选与结果，phase=pending；序号加一 | 同提交追加 pending 记录 |
| 重置 | 不变，不从旧基准覆盖 | 回 accepted，基准/recipe/pending 清空；保留设备，清空词和原料草稿；保留单调试做序号及最后重置 ID | 对应记录改为 reset |
| 发货 | 安装本次 candidateLive，正式扣卡/料、发报酬、更新人物和归档 | currentOrder=false | 对应记录改为 shipped，同一次提交 |
| 历史阅读 / 关闭面板 | 不变 | 不变 | 不变 |

同一 pending 相同请求复用原事务，不重新生成或追加日志。已确认事务重复 Confirm 返回已有记录不再次结算。相同 Reset 凭据重试不再写档；旧事务对新的 pending 不可重置/确认。

新基准 ID 使用 `orderId .. ":baseline:" .. nextAttemptSerial`，新事务沿用 `orderId .. ":attempt:" .. nextAttemptSerial`。尝试序号只有成功生成待处理结果才前进，重置不倒退。v2 导入保留旧 `orderId .. ":baseline"`；schema 3 审计仅对 originSchema=2 的导入记录/结果接受这种旧基准，不把所有新尝试也降级成同一个基准 ID。既有 OrderAudit 将 baselineId 写死为旧格式的检查必须按版本修改，不能直接删除该检查。

pending 时 live 必须等于本次 baseline.live，禁止剪词、采购、打捞、跨天和换料；读取和导航可以进行。重置只撤销候选，因 live 从未结算，不需整局回滚。

### 4.5 每日捕捞

schema 3 gameFlow 保存 `salvageUsedToday` 非负整数；dailyLimit 来自 `data/gameplay.lua`，本轮为 1。canSalvage 作为兼容派生值，等于当天处于 day 且 used < limit；不能维护两个可以互相矛盾的独立开关。

ReceiveLetter 只有真实 changed=true 且成功保存才递增 used；重复同信、无候选、无次数、保存失败均不多扣。NextDay 同一提交重置 used=0。

本轮没有可买网兜升级；不复用药锅设备价格作为网兜价，不新增随机稀有瓶概率。以后升级增加上限时另做供应与节奏验算。

## 5. 迁移策略与恢复

保留 schema 2 验证与旧夹具入口，新增 schema 3，不要只把 SaveSystem 上限改为 3。GameSession、GameState.prepare/install、SaveSchema、OrderAudit、各恢复器和内容版本检查必须成套适配。

### v2 → v3 映射

| 旧状态 | 新状态与处理 |
| --- | --- |
| 无订单 | 复制完整正式 live，currentOrder=false，补 journal |
| accepted | 保留订单与序号，初始化空 draft、清空基准 |
| brewing | 此阶段没有保存完整选料；迁为 accepted 空 draft，保留试做序号与 lastResetTransactionId；提示配料需重新选择 |
| pending | 保留原 recipe、结果、事务号、baseline 和 candidateLive；增 draft=recipe 的选料投影，复制 journal pending；不得重算剧情或评分 |
| 已发货历史 | 按 confirmedById 补 journal shipped，正文和星级直接复制保存记录 |
| 旧已重置试做 | 旧档未保留正文，无法恢复，不伪造该历史 |

捕捞旧档没有每日收信时戳，不能准确推断 usedToday。默认迁移当天标记 used=1（保守耗尽），次日恢复；提示“旧存档迁移当天的捕捞次数从次日恢复”。该策略是方案默认值，不伪称用户批准；如需更宽松政策，修改本条并添加测试，不能暗送额外瓶子。

迁移 pending 时 baseline.live 与 candidateLive 的 gameFlow 也执行相同格式转换并保持候选发货计数差异，不直接把 candidateLive 替换为当前 live。相同的保守次数应用于所有相关快照，不改变原配方、消耗和报酬。

v1 先走已有合法迁移，再转换 v2；有发货计数但无明细继续锁定，不暗中生成明细。未知 schema、内容版本不兼容、损坏存档不覆盖。迁移保留原有效提交代，成功校验新 envelope 后通过已有提交机制写下一代，失败可恢复原代；不切换到 slot1 或清空试玩槽。

## 6. 分阶段任务

### P1：查询契约与交互投影

**Files:** 新建 PlayQueries.lua、RecipeDraft.lua；装配 GameSession.queries；更新前端接入手册。

**Consumes:** 当前真实 content、GetSnapshot、letters.GetView、wordTokens.GetInventoryView、order.GetView。**Produces:** 第 3 节只读接口与草稿合法性工具。

- [ ] 在 LandscapeFlowTest 添加“查询不改变快照、不写档；同名不同来源保留；未知故事拒绝；无单返回 idle”的断言。
- [ ] 实现纯查询，将旧 v2 pending/accepted 投影为统一视图；日志方法尚未交付时明确返回 NOT_IMPLEMENTED，不能返回虚构记录。
- [ ] 实现草稿校验，沿用设备 slots、repeatWordDefinition、repeatIngredient、来源词卡规则；缺主词只允许编辑，不允许熬制。
- [ ] GetShopView 读取正式价格、库存和 shopPurchases 计算当日余量，不重建经济模块。
- [ ] 向前端交付字段样本、Result 错误例与明确“当前已实现/仍未实现”清单。

**独立验收:** UI 可用真实查询显示抽屉、托盘与商店，读取次数不造成任何业务事件。

### P2：schema 3、持久草稿与迁移

**Files:** SaveSystem / SaveSchema / GameState / GameSession / GameFlow / OrderLifecycle / OrderAudit；新建 SaveMigrations.lua、BrewJournal.lua 与 SaveV3MigrationTest.lua。

**Consumes:** 第 4 节结构、第 5 节迁移、现有双提交介质。**Produces:** 可恢复且可审计的 schema 3 初态、draft、journal 与 gameFlow计数。

- [ ] 建立 v2 idle / accepted / brewing / pending / confirmed 固定快照夹具；使用真实旧结果，不修改旧文件来迁就新校验。
- [ ] 先增加迁移和草稿保存失败断言，再实现版本派发；rg 找出 schema=2、targetSchema、ValidateV2 和 schema>2 各处限制，逐处明确保留旧分支或适配新分支。
- [ ] GameFlow 与其它共享恢复器明确接收版本或用会话适配器传入版本；隔离测试切 schema 时不得修改全局生产默认造成另一会话误读。OrderLifecycle 的 schema 3 派发由已校验会话上下文传入，不由前端发送 schema 参数。
- [ ] 增加 ValidateV3、Journal 校验和 OrderAudit schema 3 分支；pending 候选账本、词卡来源与归档的强校验不能删掉。
- [ ] 新增 UpdateDraft 命令，按完整候选保存，变更只触碰 currentOrder.draft；返回副本。相同草稿请求无写入。
- [ ] GameSession 的生产默认 targetSchema=3；旧 schema 2 隔离测试显式指定 options.targetSchema=2，不让旧测试偷偷改变生产默认。
- [ ] Load/ReloadCurrent 完整恢复所有块并保留 activeSlot；迁移成功也不能只在内存升级而磁盘仍不一致。
- [ ] 对每种写入、编码、读回、提交前、提交后故障注入复核状态；不确定提交进入恢复锁定，不把它当普通失败再写。
- [ ] 交付迁移证据，明确旧 brewing 草稿缺失和当日捕捞保守策略的用户提示。

**独立验收:** 草稿重启恢复，旧 pending 不重算，旧 slot1 不变，新日志不是独立文件；未知版本仍保护旧档。

### P3：按次冻结的试做 / 重置 / 发货

**Files:** 新建 OrderTrial.lua；修改 OrderLifecycle / OrderAudit / GameState / PlayModel；扩展 LandscapeFlowTest。

**Consumes:** P2 schema 3、RecipeDraft 校验与既有 Potion/Order/Narrative/WorldState/Economy。**Produces:** accepted↔pending 的完整事务与新模型投料方法。

```lua
-- 计划内部步骤；命令最终经协调器一次保存，不直接写文件。
-- Preview(schema3):
-- 1. 校验 accepted + 请求等于已保存合法 draft + 当前来源库存。
-- 2. 取当前 live 作为本次基准，调用已有 Calculate / Evaluate。
-- 3. 不可发货：返回 accepted + requirementResult，不留下基准或候选。
-- 4. 可发货：计算 simulation/followup/rating 与结算候选。
-- 5. currentOrder.pending、序号和 journal pending 同次 candidate 保存。
-- Reset(schema3): 保留 live/journal；标记 reset，清 pending/基准，回 accepted。
-- Confirm(schema3): 安装 candidateLive，同时 journal 标记 shipped，清当前单。
```

- [ ] 写“选料后可补剪/采购；开始后锁定；失败试做不留下锁；重置后再次补货不会回退”的用例，运行并确认旧实现不满足新规则。
- [ ] Edit 通过 UpdateDraft 保存，移除新生产路径对 BeginBrew 的调用；加入 Drop / TakeOut，第一卡主、随后辅、主词取出留空。
- [ ] Preview 内部冻结当前基准并计划 journal；条件不足时保持草稿且不生成星级/后续。
- [ ] Reset 清当前候选而不赋值旧 baseline.live；保留序号防止事务 ID 重用；同次请求重试幂等，旧请求不能撤销新结果。
- [ ] Confirm 同提交完成正式结算与 journal 状态；通知异常不触发第二次奖励。
- [ ] ReturnHome 仅设置 page；OpenAttempt 只读查询。保持前端 Resolve 调用方式，记录 V3 与旧 V2 差异。
- [ ] 更新旧 BrewPreparationTest 中“重置后永远不许补剪”的新生产预期；旧基线回归保留独立 schema2 路径，不能把改变规则后的测试数量冒充全旧行为兼容。

**独立验收:** 稳定配方仍命中原后续和星级；两次试做两条历史；正式资源只在确认时减少一次。

### P4：记录书查询、去重与来源审计

**Files:** BrewJournal / PlayQueries / OrderAudit / LandscapeFlowTest。

**Consumes:** P3 保存的 JournalRecord。**Produces:** 已收到故事书签、同后续多配方页、历史全文。

- [ ] 校验 byAttemptId 与 attemptIds 双向一致；每个事务只一条，状态只能 pending/reset/shipped。
- [ ] pending 日志与 currentOrder 的来源、recipe、followup、rating 一致；shipped 与 confirmedById 对应；reset 不改变正式世界。
- [ ] 对 reset 历史核对来源信、token 定义和配方显示快照，不要求历史词卡现在仍可用，也不重新计算正文。
- [ ] 实现长度前缀 outcomeKey 与分组查询；同一后续不覆盖不同星级、搭配与尝试状态。
- [ ] GetJournalStories 只列收到的信，不从完整 content 提前生成所有书签；GetAttempt 未知 ID 返回错误。
- [ ] 检查迁移已发货记录能重读；旧缺失试做没有伪造条目；读书零写档。

**独立验收:** 试做→重置→重启仍能查完整后续，发货一次不重复记录，历史阅读不推进剧情。

### P5：每日捕捞与跨天

**Files:** GameFlow / GameState / PlayQueries；新建 data/gameplay.lua；扩展 LandscapeFlowTest。

**Consumes:** schema 3 salvageUsedToday 与已配置可收信件。**Produces:** 每日一次成功捕捞与准确门禁。

- [ ] 将 usedToday 增量与 ReceiveLetter 的真实 changed=true 收取放在一个完整候选中；成功保存再安装。
- [ ] 重复信请求先保持已有幂等语义，不因次数耗尽将已成功结果错误变成第二次扣费。
- [ ] 条件不足、无瓶、保存失败均不占次数；查询区分 no-content、quota、order-locked。
- [ ] NextDay 同提交增加天数并归零次数；非空 draft 提示清空，空草稿 accepted 可跨天并保持来源订单。
- [ ] 把补货购买、计数与后续候选快照的 schema 3 关联校验一起补齐，保证 Confirm 不把捕捞计数恢复为错误旧值。
- [ ] 运行当前试玩投放日程，核对每日一次没有隐式改信件出现日或强制收取未来信。

**独立验收:** 一天成功一次，次日可再捞；重复、失败和退出恢复不增加额度。升级按钮本轮不销售未定义效果。

### P6：主线案件投影与正式入口隔离

**Files:** CaseBoardProjection / PlayQueries / main / DebugPanel；内容映射放入已有真实主线配置或新增 data/case_board.lua。

**Consumes:** 已收到主线来信、已正式提交的事实、已配置的案件节点/联系。**Produces:** 真实线索只读查询和安全正式入口。

- [ ] 先清点运行包是否包含主线节点与线索对应配置；记录实际可接清单。文档存在不等于运行配置已接入。
- [ ] 节点/联系只引用合法人物、地点和已取得来源；被重置试做不得解锁。无真实映射时 availability=unopened，保留未完成状态，不虚构案件。
- [ ] main 继续在载入完成后创建唯一会话，向前端 PlayView 传入；保留配置/读档失败保护。
- [ ] 正常入口不自动显示 DebugPanel 和 B1/B2 按钮，不进入调试槽或运行改写流程状态的自检；开发入口明确隔离，保留已有验收运行器。
- [ ] 若开发面板保留，面板自身增加可触控 ×；日志不遮住正式错误提示，正式读档错误使用可关闭的玩家提示且保持写入锁。
- [ ] 更新 README 和接口手册的目标为横版、正式/开发入口说明及案件接入范围；旧竖屏设计文档标历史参考，不改队友正文或美术。

**独立验收:** 正常手机路径无键盘依赖和调试覆盖；样例案件不进入真实存档；真实主线映射缺失仍明确标未交付。

## 7. 检查实现方式与测试矩阵

### 7.1 复用现有测试执行器

新增运行器内容可按下列方式落地，不另装 Lua 或复制 File 模拟器：

```python
"""Landscape workflow checks with isolated File/UI adapters; not a phone test."""
import argparse
import sys
sys.dont_write_bytecode = True
from content_test_runtime import run

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--migration", action="store_true")
    args = parser.parse_args()
    module = "debug.SaveV3MigrationTest" if args.migration else "debug.LandscapeFlowTest"
    raise SystemExit(run(module))
```

Lua 模块沿用 `Run(report)` 和真实 session 夹具；故障介质复用 `debug.fixtures.B5Fixtures` 的模式，不修改全局引擎 File。夹具需要明确 targetSchema=3 和真实已出现的可剪 span，不能用假 token 绕过来源规则。

### 7.2 必须覆盖的行为

| ID | 前提与操作 | 断言 |
| --- | --- | --- |
| P01 | 单次剪词请求重复 | 一张 token、一个剪口，查询不新增 |
| P02 | 投主词、辅词，主词取出，再投一张 | 主位空再填，已有辅位不改；无正式扣卡 |
| P03 | 同 token 重复、同名不同来源、原料超份 | 同 token 拒绝；同名按配置；超库存/槽位拒绝且草稿不变 |
| P04 | accepted 非空草稿后采购与补剪 | 成功；后续开始熬制使用最新库存与来源 |
| P05 | 缺主词或主轴不足 Preview | accepted，草稿保留，无 pending/journal/奖励 |
| P06 | 合规 Preview 两次相同请求 | 相同事务和后续，一条日志，无资源变化 |
| P07 | pending 时采购、剪词、捕捞、跨天、换料 | 拒绝，快照/草稿/计数均不变 |
| P08 | Reset 后补剪/采购，再 Preview | 原先新增资源保留，新基准取最新 live，历史仍在 |
| P09 | 旧 Reset / Confirm 凭据对新 pending | 拒绝，不撤销新结果 |
| P10 | Confirm 后重复请求与重启 | 一次扣料扣卡、一次报酬、一次发货计数、一次 shipped 记录 |
| P11 | 写入 / 编码 / 读回 / 提交前故障 | 无部分草稿、半条日志、半个计数或幽灵奖励 |
| P12 | 提交后不确定、通知异常 | 前者锁定同槽恢复；后者不重发奖励 |
| P13 | 退出后恢复 accepted/pending/reset/shipped | 草稿、当前结果、记录状态及正式账本匹配 |
| P14 | 一天收信、重复收、再收另一封 | 首次成功扣一次；重复不多扣；超额度拒绝；次日归零 |
| P15 | v2 五类状态及损坏/未知版本迁移 | 完整转换或保护旧档，无正文重算/缺失历史伪造 |
| P16 | 查询未知故事/词卡/尝试 | 有结构化错误，无未发现故事泄露；读查询零写档 |
| P17 | 非空草稿跨天，清空后跨天 | 首次拒绝并提示，清空后正常推进 |
| P18 | reset 主线试做 / shipped 主线结果 | 前者不解锁案件，后者按实际配置解锁一次 |

按“先添加关键失败用例 → 运行确认暴露差距 → 最小实现 → 再跑相关检查”执行。UI 排布不写镜像实现的测试；事务、迁移和来源约束必须有行为证据。

### 7.3 执行命令与证据范围

```powershell
python -X utf8 scripts/debug/run_landscape_flow.py
python -X utf8 scripts/debug/run_landscape_flow.py --migration
python -X utf8 scripts/debug/generate_numeric_v02.py --check
python -X utf8 scripts/debug/run_numeric_v02.py
python -X utf8 scripts/debug/run_numeric_v02.py --flows
python -X utf8 scripts/debug/run_numeric_v02.py --shop
python -X utf8 scripts/debug/run_numeric_v02.py --startup
python -X utf8 scripts/debug/check_numeric_runtime.py
python -X utf8 scripts/debug/run_story_content.py
```

前两条在对应新文件实现后执行。后续数值检查保持原配方和结果；涉及阶段/计数的旧用例需明确更新预期或留在显式 schema 2 兼容路径，不能把预期改成实现输出来掩盖错误。先运行相关检查；全部必要检查通过后不无理由重复全套。

纯 Lua 流程与 File 夹具不证明引擎显示、真实磁盘或手机退出恢复。与前端一起完成手机录屏 / 截图和恢复检查，再记录最终通过范围。

## 8. 实施顺序与交付条件

1. P1 先交查询契约；前端可独立做场景与信件/词卡/商店。
2. P2 建好 schema 3、迁移和草稿；P3/P4 打通真实试做与记录；前端再接拖拽、结果和书页。
3. P5 捕捞计数；P6 入口隔离及真实案件投影。案件内容未接则单独报告缺口，不能阻塞普通订单闭环但不能宣称案件板完成。
4. 更新 `scripts/前端接入接口手册.md`，明确实际实现与提案的分界，写入命令、结果字段、门禁、草稿、迁移与日志例子。
5. 交付测试命令、结果数字、失败项、存档槽和迁移证据。检查 Git 差异，按用户明确的提交/推送指令通过 Maker 官方工具提交。
6. 每批代码/资源改动后查询本地 preview status；仅活跃会话刷新并获取日志。远端构建成功后读取工具返回 runtime log 与 watcher state，不能把空日志等同手机通过。

最终完成条件：前端能用真实接口完成一单及其重置/回看，schema 3 恢复与旧档保护通过，一次性词卡和重复发货不变，横屏手机可操作。数值或故事内容的新增需求另做方案，不混入本轮基础交互改造。
