# 普通剧情首发版 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> 本项目默认在当前会话按 `executing-plans` 顺序实施。Task 1～4业务已完成；Task 5代码与正文已接入，原生页面视觉／手机验收尚未完成；Task 6未完成。未远端构建或提交游戏。前端按阶段接入：Task 2更新说明与药效，Task 3接购买，Task 4～5接终局。

**Goal:** 完成首单＋10 封普通剧情的日程、收入、辅料与三结局闭环，目标完整周目 60～90 分钟。

**Architecture:** 保留现有内容生成器、合成八步、GameState 原子提交和横版前端。增加小型首发配置、纯结局规则、终局协调与展示模块；永久商品购买参与经济重放。采用独立首发内容版本/存档槽及 schema 4，旧试用档不重算。

**Tech Stack:** Lua 5.4 / TapTap Maker UrhoX / urhox-libs/UI / Python 来源生成器与 Lupa 隔离业务测试。

**Spec:** `docs/superpowers/specs/2026-10-13-ordinary-release-design.md`。

**2026-10-13 用户修订：** 家居换为桌布60、椅子100、挂灯140、书架180，复用现有 `data.furniture` 的 `decor_*` ID。Task 1 证据见 `docs/验证/普通剧情首发_Task1验收_2026-10-13.md`；辅料、D14收尾与schema 4继续按后续任务执行。

## Global Constraints

- 正式范围只有埃利亚斯＋N01～N10，11 单、58 篇后续；案件和其他身份延期，源文件保留。
- 报酬每单 100，同单所有星级同额；开局 30、四料各 3、每日成功打捞 1、原料各日供 6。
- D1 首单、N01 D2 至 N10 D11；船票 666，D1～D10；D14 结束进入收尾，不出现 D15。
- 家居桌布/椅子/挂灯/书架 60/100/140/180；学徒正式完成 11 单且至少 8 单三星、家居齐全，并主动选择。
- 拼贴只引用实际获得的词来源；已消耗卡仍不能炼药；不设 12/5 门槛，至少拼一词。
- 当前Task 2内容版本 `ordinary-release-v2`，默认槽 `ordinary_release_v2`，Task 3已接入schema 4，同内容schema 3完整审计后升级。Task 1的v1槽及更早旧槽保留，不按新数值改写旧结果。
- 当前工作区已有其他人的剧情、生成包、界面及文档改动；按具体文件核对差异，不覆盖或整仓暂存。每批仅纳入本任务的已检查改动。
- 用户代码写 `scripts/`；不改 `urhox-libs/`、引擎目录或用户 MCP 环境。
- 不自动启动已停止的预览。代码/资源批次后查 preview status；存活时 refresh 并取 logs/check，视觉验收先读图。
- 本任务不授权远端 build/submit/push；通用代码检查不触发 Maker build。后续显式远端请求走 Maker MCP。
- UI 复用当前横版木柜台/旧纸/HarborStyle 与安全区；不新增 raw NanoVG，素材首发先复用。
- 第一项执行前完整阅读 `engine-docs/lua-scripting-guide.md`；通过 `examples/api-index.md` 阅读至少三个相关示例，记录实际路径；UI 用 `engine-docs/recipes/ui.md` 和现有页面范式。
- 所有写事务均校验、保存后安装；提交不确定按同槽恢复，不用前端模拟成功。

## 工作顺序与阶段交付

| 阶段 | 可交付结果 | 依赖 |
|---|---|---|
| A 日程/收入 | 11 单按天投放并都付 100，新槽可完整经营 | 无 |
| B 辅料 | 四料实际影响后果，58 篇后续仍可达，经济候选复算 | A |
| C 永久购买/存档 | 家居真实入账，schema 4 重放、恢复和故障行为通过 | A、B |
| D 结局业务 | 三入口、D14 收尾、拼贴和结束前恢复真实持久化 | C |
| E 前端/正文 | 家居、资格、收尾、拼贴和结局可完整操作 | D |
| F 完整验收 | 三路线/边界/退出恢复与真人时长记录 | A～E |

每阶段结束做一次本任务差异复核与阶段证据记录；不把“计划完成”当作“游戏完成”。

## Task 1: 日程、收入与正式来源

**Files:**
- Create: `scripts/data/release.lua`、`scripts/debug/ReleaseScheduleTest.lua`、`scripts/debug/run_release.py`。
- Modify: `scripts/debug/generate_numeric_v02.py`、`scripts/data/content.lua`、`scripts/data/numeric_v02.lua`（生成）、`scripts/debug/fixtures/NumericV02Cases.lua`（生成）。
- Modify: `docs/文案/供给验算表_v02.md` 的报酬来源和保守账口径、`docs/验证/词值v02_运行接入说明_2026-10-09.md` 首发接入增量。

**Interfaces:**
- `Data.release` 指向新纯配置；原 gameplay.salvageDailyLimit 保持 1。
- Task 1 的 `run_release.py --suite schedule|startup` 分别验证日程业务与正式启动/旧槽保护，默认 schedule。Task 2～5逐阶段加入 ingredients/economy/purchases/endings/ui；Task 6汇总为 full 并改默认，当前不暴露未实现的模块。
- 生成器继续提供 `compile_pack()`，样例生成读取当前生效辅料；来源哈希覆盖 release.lua。

- [x] 建立失败检查，直接读真实生成包的 order 信：

```lua
local D=require 'data.content'
local orders={}
for _,l in ipairs(D.letters) do if l.kind=='order' then orders[#orders+1]=l end end
assert(#orders==11)
for index,l in ipairs(orders) do
    assert(l.appearCondition.dayMin==index)
    assert(l.reward.currency==100)
end
assert(D.saveSlotId=='ordinary_release_v1')
```

- [x] 运行 `python -X utf8 scripts/debug/run_release.py --suite schedule`，应先因旧日程/旧报酬失败。
- [x] 新配置写具体值，不散落到界面：

```lua
return {
    contentVersion='ordinary-release-v1', saveSlotId='ordinary_release_v1',
    finalDay=14, minThreeStarOrders=8, orderReward=100,
    requiredOrderIds={'letter_pa_01','letter_n01','letter_n02','letter_n03',
        'letter_n04','letter_n05','letter_n06','letter_n07','letter_n08','letter_n09','letter_n10'},
    ticket={id='travel_ticket',price=666,offerStartDay=1,lastPurchaseDay=10},
    homeItems=require 'data.furniture', -- 桌布60/椅子100/挂灯140/书架180
}
```

- [x] 将来源表 E01/N01/N02 与后八单报酬统一 100；生成器使用 `day=index+1`（Python enumerate 从 0），Data 使用 release 的版本/槽位。
- [x] 用现有 Narrative.FindAvailable 与收信测试覆盖 D1/D2/D10/D11、漏两天后顺序补收、重复打开不扣打捞次数。不得用固定文字列表冒充真实调度。
- [x] 运行生成器、`--check`、schedule 测试和正式内容检查：

```powershell
python -X utf8 scripts/debug/generate_numeric_v02.py
python -X utf8 scripts/debug/generate_numeric_v02.py --check
python -X utf8 scripts/debug/run_release.py --suite schedule
python -X utf8 scripts/debug/run_story_content.py
```

- [x] 将后续阶段尚未实现的终局保留为明确未开放；不在此阶段生成虚假成功。记录 A 阶段变更/证据，检查本批差异。

## Task 2: 四种辅料与分支/经济验算

**Files:**
- Modify: `scripts/data/ingredients.lua`、`docs/文案/供给验算表_v02.md`。
- Modify: `scripts/debug/generate_numeric_v02.py`、生成包和生成配方夹具、`scripts/ui/landscape/Panels.lua` 的过时提示。
- Modify: `scripts/systems/PlayQueries.lua` 的只读药效查询、`scripts/data/release.lua` 内容版本与槽位、专项运行器及旧版本断言。
- Create: `scripts/debug/ReleaseIngredientTest.lua`、`scripts/debug/ReleaseEconomyTest.lua`、`docs/验证/普通剧情首发_辅料与经济验算_2026-10-13.md` 及两份JSON结果。
- Read: `scripts/systems/Potion.lua`、`scripts/data/synthesis.lua`、`docs/文案/分支条件表_v02.md`，不为本次配料改星级或拒绝条件。

**Interfaces:**
- 保留 Potion.Calculate/Order.Evaluate/WorldState.Simulate/Order.Rate 签名。
- `GetOrderSummary().potionPreview` 为false或 `{effects,intensityByEffect}`；前端只展示当前真实药效，不提前模拟正文、评分或写存档。商店读取原料desc，炼药页显示desc与数值。
- 验算报告逐锅记录来源 token、原料、真实 effects/fact/stars、成本；逐单流水记录采购前现金与日供余量。

- [x] 建立四料失败用例，实际调用 Potion.Calculate；单盐主效 1→0.9、双盐 1→0.8、单露 1→1.25、单草 1→1.5＋dream 0.4、单瓣 calm 增 0.3。配方通过真实 ResolveRecipe 获得，不直接伪造最终药效。
- [x] 运行 ingredients suite，确认旧值失败；按规格修改 mods/addTags 和商店描述，保留价格与现有八步算法。
- [x] 分别建立后果变化见证：N06 稳手主词＋疼痛辅词加入盐后跨疼痛阈值；N08 低镇静配方加入两份花瓣跨 calm 0.6；灰烬草沿首单梦境 0.4～0.6 分支；夜露沿接近高强度界线的 happy/calm 配方。用真实计算输出选择有效的夜露见证，不能以倍率变化但后果没变声称满足验收。
- [x] 为 58 篇后续各保留一份可达登记锅，独立通过来源表的区间条件判断预期。普通基准锅可去掉盐/露保持原后果，不能直接把变更后的结果抄成新预期。覆盖无料锅及所有两槽原料组合、阈值前后和恰好主轴 0.8。
- [x] 在一个真实隔离周目完成 11 单，确认来源一次性消耗、每单奖 100、库存/现金可恢复；另跑每单至少三星基础路线与含最多 3 个低星的学徒候选路线。
- [x] 经济枚举无料/常规/昂贵有效锅、票窗漏两单、家居 480 和日供 6。记录正常完成八单是否可付 666；极端乱买不作保证。四料中某件没有后果见证时回到本任务调数值，不能用新随机失败或大量新剧情补用途。
- [x] 再生生成物，运行：

```powershell
python -X utf8 scripts/debug/generate_numeric_v02.py
python -X utf8 scripts/debug/generate_numeric_v02.py --check
python -X utf8 scripts/debug/run_release.py --suite ingredients
python -X utf8 scripts/debug/run_numeric_v02.py --flows
python -X utf8 scripts/debug/run_numeric_v02.py --shop
python -X utf8 scripts/debug/check_numeric_runtime.py
```

- [x] 若旧测试含 80/0/D20 等断言，改为核对独立 release 规格；保留旧已提交内容快照回归。记录最终冻结辅料值和 B 阶段证据。

## Task 3: schema 4 与永久商品采购账

**Files:**
- Create: `scripts/systems/ReleaseLedger.lua`、`scripts/debug/ReleasePurchaseTest.lua`、`scripts/debug/ReleaseSaveTest.lua`。
- Modify: `scripts/core/SaveSystem.lua`、`SaveSchema.lua`、`SchemaProjection.lua`、`GameState.lua`、`GameSession.lua`、`scripts/main.lua`。
- Modify: `scripts/systems/Economy.lua`、`OrderAudit.lua`、`OrderTrial.lua`、`BrewJournal.lua`；`SaveMigrations.lua` 只补同内容版本结构升级保护。

**Interfaces:**
- `ReleaseLedger.New(content).PlanPurchase(economy,request,context)` → Result<{state,cost,itemId,transactionId}>。
- request 为 `{itemId,expectedDay,expectedPrice,expectedRevision}`；context 为 `{day,deliveredOrders,revision,kind}`，kind 为 home/departure。
- economy.itemPurchases 行为 `{itemId,unitPrice,day,afterDeliveredOrders,transactionId}`；schema 4 初始化为空数组。每 item 一次，transactionId 唯一。
- chapter 初态 `{phase='operating',wishDraftSourceIds={},ending=false,endingTransactionId=false,checkpoint=false}`；phase 为 operating/closing_prepare/closing/wish/ended。
- 新协调入口 `state.PurchaseHomeItem(request)`；家居所有权由真实账派生。现有商店传显示时quote，旧PurchaseFurniture保持兼容；schema 4不并存旧ownedFurnitureIds/furniturePurchases。
- Task 3还增加ReleaseFixtures、ReleaseFlowTest，运行purchases/saves/flows/startup；当前chapter只允许operating空终局，Task 4再扩展阶段。
- 证据：`docs/验证/普通剧情首发_Task3验收_2026-10-14.md`。按用户要求不使用子代理。

- [x] 写失败用例：窗口只选商品不改状态；余额恰好/不足；买椅子扣 100；重复确认不二次扣；不认识商品拒绝；炼药投料非空或 pending 拒绝。
- [x] 写保存失败/提交不确定/通知失败重读用例；增加“改余额/价格/未来 afterDeliveredOrders/重复家居记录”坏档拒绝。运行 purchases suite 确认红灯。
- [x] 为 schema 4 建独立结构验证，保留 schema 1～3 显式旧测试。审核所有 `==3` 分支，显式接受 3/4，禁止用“非 3 都是 2”的分支。
- [x] 扩展 Economy.InitialSnapshot/ValidateSnapshot，家居/票的永久行不混成原料购买。编写价格、日期、发货进度与幂等验证，所有扣款在候选副本完成。
- [x] OrderAudit 在每个 afterDeliveredOrders 阶段按日期合并原料和永久采购重放；验证原料日供、永久一次性、现金不倒借。保留永久记录到投影与基准，不能删字段后直接接受最终余额。
- [x] 在 GameState 增加经过统一提交协议的家居命令；Result 返回真实余额和 itemId，不由 UI 扣钱。老内容档不能迁移到新 contentVersion；新默认槽单独开局，旧槽字节不变。
- [x] 测试示例（隔离 Session/Storage 初始化辅助定义在各测试模块，使用现有 B5/B6 File 适配器）：

```lua
local before=session.state.GetSnapshot()
local r=session.state.PurchaseHomeItem({itemId='decor_chair',expectedDay=1,
    expectedPrice=100,expectedRevision=before.revision})
assert(not r.ok and r.error.code=='CURRENCY_SHORT')
assert(U.Equal(before,session.state.GetSnapshot()))
```

- [x] 运行 purchases suite、SaveSystem/SaveJson/旧迁移检查及真实买料→发货→家居→再发货→重读的交错路线；记录 C 阶段证据。

## Task 4: 三结局、最终日与真实词样本

**Files:**
- Create: `scripts/systems/ReleaseEndings.lua`、`ReleaseCoordinator.lua`、`scripts/debug/ReleaseEndingTest.lua`。
- Modify: `scripts/core/GameState.lua`、`GameSession.lua`、`SaveSchema.lua`、`scripts/systems/PlayQueries.lua`、`OrderAudit.lua`。
- Create: `scripts/data/release_endings.lua`；正文由 Task 5 审写接入，业务测试此阶段使用显式测试正文，不能对玩家显示占位文本。

**阶段记录：** `docs/验证/普通剧情首发_Task4验收_2026-10-14.md`。增加ReleaseChapterAudit、ReleaseEndingSaveTest、ReleaseEndingFixtures及ReleaseClosingIntegrationTest；沿用Task 3永久采购重放，不重复改写OrderAudit。按用户要求无子代理。正式正文登记留空，业务验收只注入隔离测试正文。

**Interfaces:**
- `ReleaseEndings.New(content).GetProgress(data)` → Result<{completedCount,threeStarCount,requiredCount,requiredThreeStarCount,homeItemIds,canClose,canApprentice}>。
- `GetWishSamples(data)` → Result<{sourceTokenId,wordId,text,sourceLetterInstanceId,sourceSpanId}[]>；包含可用/已消耗真实来源，来源去重。
- `PlanEnding(data,{kind,expectedRevision,sourceTokenIds?})` → Result<{data,ending}>，kind 为 departure/apprentice/wish，纯候选。
- `state.PurchaseTravelTicket(request)` 沿用已有前端四参数，成功返回 `{departed=true,ending={kind,title,text,wishText?}}`。
- `state.BeginClosing({expectedRevision})`、`state.BeginWish({expectedRevision})`、`state.UpdateWishDraft({sourceTokenIds,expectedRevision})`、`state.ConfirmEnding({kind,expectedRevision})`、`state.RestoreEndingCheckpoint({expectedRevision})`、`state.StartNewPlaythrough({expectedRevision})` 均走统一候选提交。新周目必须在前端明确确认后调用，只用已校验初态替换首发槽，不删除旧槽；保存失败保留原结局。
- `queries.GetReleaseProgress()`、`GetTravelTicketView()`、`GetWishView()`、`GetEndingView()` 分别读真实业务状态；GetTravelTicketView 返回现有 TravelTicketQuote 所需字段。

- [x] 先写边界测试：7/8/11 单三星，10/11 单完成，缺一件家居，资格成立仍选 wish；试做三星不计、跨档/历史记录不计。
- [x] 船票 D10/11、665/666、打开确认后跨天/改 revision、取消、重复请求；结束后禁止 Shop/Receive/Cut/Accept/Preview/Confirm/NextDay 等经营写入（重读与结束前恢复除外）。
- [x] 拼贴已耗实例可引用但 available 保持 false；未获得来源/重复来源拒绝；至少一词、顺序保留；草稿退出恢复；无剪词收尾进入补读准备，正常剪取一词后进入选择。
- [x] 实现纯资格与样本查询：完成统计按 11 个 letterId 去重，读取 confirmedById 的正式 rating；从 wordTokens 联查 letters 的 cutSpans 校验来源。
- [x] NextDay 在 D14 改调用收尾候选，不加天；pending/非空草稿先拒绝。空接单原样保留 currentOrder、acceptedById、序号和永久试做记录，但不计作完成；终局阶段拦截经营写入，结束前恢复后可续做。买票沿用相同空草稿边界，不隐式撤销接单。
- [x] checkpoint 与扣款/结局在同一次 Save 内持久化；checkpoint 移除其自身 checkpoint，完整验证才能恢复。终局正文和原句冻结保存，重读不重新生成。幂等重试先识别已完成同种终局，再检查 stale revision，不能二次扣钱或投瓶。
- [x] 明确保存故障测试至少覆盖购票、BeginClosing、UpdateWishDraft、ConfirmEnding、RestoreEndingCheckpoint、StartNewPlaythrough 六处；不确定保存必须锁定同槽重读。
- [x] 运行 endings suite 和 purchases suite；真实隔离完成离开、学徒、wish 三条路线，记录 D 阶段证据。

## Task 5: 家居、收尾、拼贴界面与终局正文

**Files:**
- Create: `scripts/ui/landscape/ReleaseClosingView.lua`、`WishView.lua`、`EndingView.lua`、`scripts/debug/ReleaseUITest.lua`。
- Modify: `scripts/ui/PlayModel.lua`、`scripts/ui/landscape/AppView.lua`、`ShopView.lua`、`TravelTicket.lua`、`TravelTicketView.lua`、`HomeView.lua`、`LayoutManifest.lua`（案件热区入口）。
- Create: `docs/文案/结局/普通剧情首发_三结局正文_v01.md`；同步 `scripts/data/release_endings.lua`。
- Modify: `scripts/ui/landscape/船票程序接口交接.md`、`人工验收.md`、`scripts/前端接入接口手册.md`，新增首发实际契约。

**Interfaces:**
- 新三 View 统一 `.New(ctx)`，返回 `{root,Refresh,Destroy}`；只调用 Task 4 queries/state 命令，由 PlayModel.Notify 呈现失败。
- Shop 家居卡与原料卡分 kind；原料仍走 model.Buy，家居走 PurchaseHomeItem，船票走专门启程事务。
- 恢复加载后以 GetEndingView 决定展示已保存结局；不依赖 ticketEnding 等仅在内存的布尔值。

- [x] 建立真实隔离业务＋HeadlessUI 的失败用例：买椅子必须走家居命令，不买错原料；取消不扣；按钮无穿透；返回商店保留场景/草稿；已买家居不能再买。
- [x] 收尾页显示订单完成数、三星数和家居清单，学徒不足给具体原因；满足时“留下”与“寄出自己的愿望”并存。不提前在剧情正文解释门槛。
- [x] WishView 使用点选、移除、前后移动完成拼贴，不以新拖拽系统为首发前提；显示真实词和来源。至少一词可预览，取消回编辑；保存失败保留原草稿及明确提示。
- [x] 终局页面展示真实 title/text/wishText，提供“返回结束前”及显式新周目确认。新周目须明确覆盖首发槽并确认；不清理旧试用/旧验收槽。
- [x] 三结局正文沿用旧旅人/学徒/无名者方向，移除案件/土地和缺少身份依据的句子，保留玩家原句与可选全三星认可短句。正文与来源文档同步，避免 UI 写死剧情。
- [x] 隐藏案件热区/菜单的玩家入口，留开发查看能力与源文件；不保留“此版本尚未开放主线”的常驻占位面板。
- [x] 查 API 文档后按现有纸/木材主题完成自适应；44 逻辑像素以上触摸目标，长文独立滚动，横屏安全区/Tap 胶囊保持。无新图需求不主动生成资产。
- [ ] 运行 ui suite、TravelTicketTest/ShopViewTest/HomeEntryTest/MobileSafeAreaTest 相关既有检查（通过现有 runner 模块装配，不另造假命令）；查看实际图再作视觉判断。记录 E 阶段证据。

**Task 5阶段记录：** `docs/验证/普通剧情首发_Task5接入与验收_2026-10-14.md`。已增加ReleaseFrame共享纸面，保存结果不确定的页内重读，以及拼贴按钮／封瓶预览的显示revision校验。正文为首发接入新稿，未标记用户逐句定稿。ui、船票、商店、安全区及保存专项已跑；旧HomeEntry仍被并行词条栏改版移除的投料入口阻断，不能宣称全部回归通过。运行中的本地预览按规则刷新、取logs/check；既有资源／DLL错误与缺少页面截图限制原生视觉结论。未使用子代理。

## Task 6: 完整周目与交付收口

**Files:**
- Create: `scripts/debug/ReleaseFullFlowTest.lua`、`docs/验证/普通剧情首发_完整验收_2026-10-13.md`。
- Modify: `README.md`、`docs/README.md`、`docs/文案/README.md` 的“当前版本”增量；不覆盖旧剧情修改。

- [ ] 完整路线：低成本 D7 离开、正常支出 D8～D10 离开、漏两单仍可购票的见证；11 单 8 三星＋家居学徒；11 全三星学徒额外短句；达学徒条件主动 wish；低星/漏单 D14 wish；零剪词准备后 wish。
- [ ] 顺序验证：先家居后订单、买料/家居交错、四料混合、关窗在 pending、愿望编辑中关闭、确认结束时关闭、返回结束前后再选另一结局。每一步查看现金/库存/采购账/来源/正式记录。
- [ ] 运行最终候选的一次整套自动检查，读输出而非沿用旧 PASS：

```powershell
python -X utf8 scripts/debug/generate_numeric_v02.py --check
python -X utf8 scripts/debug/run_release.py --suite full
python -X utf8 scripts/debug/run_story_content.py
python -X utf8 scripts/debug/check_numeric_runtime.py
python -X utf8 scripts/debug/run_landscape_flow.py --numeric
python -X utf8 scripts/debug/run_story_content.py --content-ref 3dbca09
```

- [ ] 用 Maker Lua LSP 检查本批 Lua；没有工具或失败时明确记录范围，不宣称 0E/0W。
- [ ] 执行项目的官方 preview status 工作流；只有存活时 refresh，取 logs/check。窗口已停止则保持停止；用户明确要求本地预览后才开启新会话。
- [ ] 真人完整体验一条 11 单路线，记录阅读、剪词、试药、商店与收尾的分项时长，以及总时长。超过 90 分钟优先减少重复操作和等待，不擅自删定稿；不足 60 分钟先记录事实，不靠空白等待拖时长。
- [ ] 手机验收横屏、长文滚动、拼贴顺序、胶囊遮挡、购买连点和退出恢复。拿不到窗口/手机证据分别标“未验证”，不把隔离适配器测试替代真人操作。
- [ ] 更新实际交付状态与验证表，复核规格逐条覆盖。记录 final git diff 和未完成项；仅在全部所需检查有证据时称首发闭环完成。远端构建另等用户明确指令。

## 计划自审记录

- 四件事分别对应 Task 1（日程/收入）、Task 2（辅料）、Task 3（商店金额与永久购买）、Task 4～5（三结局）；Task 6 统一验收。
- 三结局闭包覆盖零剪词、低星、漏单、过期票和学徒资格重叠；没有自动增加第四身份。
- 新 schema 涉及入口、投影、业务恢复、账本重放、试做记录与候选基准，不只改保存版本号。
- 配料倍率/副作用步骤、拼贴样本/炼药库存、来源文档/生成物、参考算术/实测证据均明确区分。
- 执行以当前工作区为基线保存已有变更；不自动远端构建、启动停止的预览或修改服务环境。
