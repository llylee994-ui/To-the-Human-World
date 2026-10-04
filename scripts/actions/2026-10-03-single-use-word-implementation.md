# 一次性词条：本机 W-P1/W-P2 实施记录

> 后续已合入正式 r3（50ee7a8），W01～W08 逻辑专项 229/229、正式三单通过，B6 按钮已接入；窗口/V13 未验收。见 [r3 接续记录](2026-10-03-r3-integration-and-b6.md)。本文的“等待正式配置”和 r2 数字仅描述本批历史状态。

## 状态与背景

- Completed（本机 W-P1/W-P2 程序与技术验证）；正式 W01～W08 联合出口仍等待 W-T1/W-T2，不代表一次性配置已经上线。依据 [一次性词条计划](../一次性词条_规则与双人实施计划_2026-10-03.md)，本机负责程序、测试与视图；正式 data、词源供给与 docs 由队友负责。
- 基线 fengyycon@45ed5a9；保留未提交 B5/P1/P2、原 docs/actions/、本轮开始已有的 docs/设计/寄往人间_主线案件角色档案与完整故事线.md 修改。不提交、推送、构建或自动启动已停止预览。
- 已 fetch 并复核 f76de64：N01 的两条遗忘排除修正、强镇静互斥拆分、story-v0.3-r2、T2/T3 文档已交付；没有一次性 words 切换，未把静态检查当联合验收。当前工作区仍 r1。
- WordToken 已按实例消费，PlanConsumption 不修改输入；GetInventory 兼容历史调用者。技术副本全词 false 的通过不代表 W01 正式配置完成。

## 实施措施

1. 扩展 WordToken 只读视图：同名剩余张数、全部来源卡、当前可用定义/类别数，从实例派生，无第二套库存。
2. 独立专项覆盖主/辅精确扣除、重置/重载、同名多来源、重复/过期请求、失败/不确定结果、多单历史篡改及旧版 pending/confirmed 门禁。
3. StoryContentFlowTest 改为 wordId→tokenId[] 并明确选择可用实例；每次候选/确认核对消耗集合与未使用卡，多单不补给。
4. 运行技术专项、正式配置门禁、既有回归、LSP，交付实际支持范围。W-T1/W-T2 到位才通过新版 P3；W-P3 界面和 V13 随 B6 后续实施。

## 影响文件树（实际）

```text
scripts/
├── systems/WordToken.lua                 派生库存视图，保留通用 reusable 策略
├── debug/WordTokenTest.lua               同名来源与可用计数
├── debug/StoryContentFlowTest.lua        多实例选取、消耗与连续经营断言
├── debug/OrderRecoveryTest.lua          允许同套失败检查使用明确技术配置
├── debug/OrderFlowTest.lua              B5 每种成功配方候选/确认的精确扣词检查
├── debug/SingleUseWordTest.lua          W01～W08 专项
├── debug/fixtures/SingleUseFixtures.lua  全词一次性技术副本与独立同名来源
├── debug/run_single_use_words.py         专项执行入口
├── debug/content_test_runtime.py         只读提交中的 data，隔离加载，不合入工作区
├── debug/run_story_content.py            原入口增加内容 SHA 与一次性技术副本选项
├── README.md / 一次性词条_规则与双人实施计划_2026-10-03.md  实际状态交接
├── 本机实施计划_新内容联调与B6_2026-10-03.md / 后端闭环与双人并行开发计划.md  更新依赖状态
├── actions/2026-10-03-story-integration-p1-p6.md  保留历史失败，追加新证据
└── actions/2026-10-03-single-use-word-implementation.md
```

## 自验证方法

- 新专项采用真实 GameSession/SaveSystem/玩法模块和隔离文件介质；技术副本与正式 W01 检查分别输出，不以跳过掩盖配置未交付。
- 相同基准反复重置、独立配方新档、连续三单分别测试；使用真实 Receive/Read/Cut，禁止直接注入词库存。
- B1～B5 及新内容相关回归、Lua LSP、git diff --check、保护文件 SHA256、预览状态。

## 自验证结果

### 命令与实际结果

以下 Python 命令均在项目根目录运行，使用既有 Lua 5.4 隔离 runner 和 File/UI 适配器，不等同真实引擎持久退出。

| 检查 | 结果 | 证据 |
|---|---|---|
| `python -X utf8 scripts/debug/run_single_use_words.py --content-ref f76de64 --technical` | 227/227，退出 0；明确跳过正式 W01，只验技术副本 | [专项](../../logs/wp-single-r2-final.log) |
| `python -X utf8 scripts/debug/run_single_use_words.py --content-ref f76de64` | 229 项中 2 项失败，退出 1；技术 227 通过，正式仍 30 词可复用且版本为旧 r2 | [正式门禁](../../logs/wp-formal-r2.log) |
| `python -X utf8 scripts/debug/run_story_content.py --content-ref f76de64 --single-use-copy` | 1266 项、0 失败；当前 16/16，未来纯计算 9/9，事实矩阵 9/9 | [一次性技术流程](../../logs/wp-story-r2-once.log) |
| `python -X utf8 scripts/debug/run_story_content.py --content-ref f76de64` | 1265 项、0 失败；当前 16/16，未来纯计算 9/9，事实矩阵 9/9 | [原版 r2 流程](../../logs/wp-story-r2-formal.log) |
| `python -X utf8 scripts/debug/run_b1.py` | 130/130，退出 0 | [B1](../../logs/wp-b1.log) |
| `python -X utf8 scripts/debug/run_b2.py` | 212/212，退出 0 | [B2](../../logs/wp-b2-final.log) |
| `python -X utf8 scripts/debug/run_b3.py` | 387/387，退出 0 | [B3](../../logs/wp-b3.log) |
| `python -X utf8 scripts/debug/run_b4.py` | 339/339，退出 0 | [B4](../../logs/wp-b4.log) |
| `python -X utf8 scripts/debug/run_b5.py` | 373/373，退出 0 | [B5](../../logs/wp-b5-final.log) |
| 本地 maker-lua-lsp 全 scripts | 2026-10-03 17:09:05，0 Error / 0 Warning / 0 Hint | [诊断](../../logs/lua_diagnostics.log) |

本轮初始在工作区 r1 运行专项，技术 214/214，正式门禁同样失败 2 项；随后扩展至上述 227 项并用 r2 重跑。实现期曾因 B2 检查助手按引用比较表而出现 4 个测试失败，改为既有深比较后通过；LSP 发现的局部变量遮蔽、字面量类型推断与注释语法问题已修正。这些是测试实现问题，不报告为业务缺陷。

### 已验证能力与接口

- Preview 正式库存不变，候选消费集合严格等于实际主/辅卡，未投入卡及来源全量不变；A/B/C/D、E/F 失败、缺评分、反复 Reset、成功/重复/过期确认及 pending/confirmed 重载均覆盖。
- 同名两来源通过真实收/读/剪获取，消费 A 留 B；A 重剪和再次投料失败，B 可在下一单使用；第二单重置不复活 A；伪造跨单重用同一 token 的存档被拒绝且不部分安装。
- 复用编码/写入/回读/提交前失败注入以及结果不确定、安装/通知异常与重入检查；三张一次性卡的不确定提交恢复精确安装已保存候选。
- 旧可复用版本 pending/confirmed 进入新技术版本均明确 `migration_required / CONTENT_VERSION_MISMATCH`，原文件不变，无事件/安装；读写与推进门禁保留，旧版本仍可读。没有迁移、清档或补卡。
- 连续首单 A→N01 A→N02 A：三单确认、270 金币，海盐 0、夜露 1、灰烬草 3、干花瓣 3；一次性技术副本剩 11 种可用词，未注入库存。首单 C 用掉“忘记”后 N01 无法复用同卡。未来 9 条仅纯计算，不代表当前词源可达。
- 新 `WordToken.GetInventoryView()` 返回只读副本：`cards` 保留全部来源与消费历史，`groups` 按 wordId 排列，含 definition、collectedCount、availableCount、availableTokenIds；顶层 availableCount / availableDefinitionCount / availableCategoryCount 仅数当前可用。未初始化沿用 STATE_NOT_READY；旧 GetInventory 不变。派生计数不是第二本库存账，也未实现无名者结局判定。
- B6 可用 cards 的 tokenId 查来源，明确选择实例；待确认消耗沿用 Order.GetView 的 pending.consumption（consumedTokenIds 与 ingredients）。测试排序选卡仅是夹具策略，不是新增生产自动消耗规则。

### 范围、剩余依赖与交接

- 没有发现需要重写事务或存档结构的真实缺陷。本轮未新增对 OrderLifecycle / OrderAudit / GameState / SaveSchema 的修改；这些文件中的既有 B5 工作保留。保留通用 reusable 能力和 schema=2。
- 实际远端为 GitHub；fetch 后 origin/main=`f76de64791c4c6887a29d27c3545385ec595de6e`。r2 的 data 通过 `git show` 只读加载，**没有合入/部署**；工作区仍 story-v0.3-r1。T1 的旧六失败已在 r2 流程验证消除，T2/T3 文档已见于提交；未实施 P6 或冻结其存档契约。
- W01 正式门禁明确失败；W02～W06/W08 有技术运行证据，W07 仅技术副本连续路线通过。队友仍须交 W-T1 正式全词 false 与新 contentVersion、W-T2 逐来源词账和资源互斥说明。到位后合入并用默认正式检查重新通过 W01～W08/P3，才进入 W-P3/B6。
- W09 界面、V13 三个真实退出点及 A1～A19 实机尚未验收；W10 完整版路线属于后续内容阶段。没有用纯逻辑结果替代这些验收。
- 最终差异、链接、保护文件和预览状态检查结果见下方收尾；没有提交、推送、远端构建或改写正式 data/docs。

### 收尾检查

- `git -c core.safecrlf=false diff --check` 通过；`git diff --name-only -- scripts/data` 为空。分支仍 fengyycon@45ed5a9，origin 实际为 GitHub。
- 6 份本轮交接文档共 69 个本地链接检查全部有效；10 个本轮相关程序/测试文件无行尾空白，Lua 文件均未超过 1500 行。
- 原用户修改的主线故事档案、原预览记录与主页图 SHA256 均与开工保护值一致：分别为 `AF046D731535357A82176D46585B0DD594AF217FE32877F08FFD235BC84B6D74`、`DC65A8CE5F31DD2D51456657E8BE74C2A63A03DB8B87BA59D4496A0BED906306`、`541EFC5052131534A35673FBBC6ADAE645A073245BD2C3B8CD7DDD249C096625`。没有清理原未跟踪文件或覆盖已有 B5/P1/P2 工作。
- 修改后通过本机 Maker 0.0.36 的 `dist/maker.js preview status --target-dir D:/taptap/To-the-Human-World --json` 核对：stopped / process_alive=false，session=98eb3697-9d20-4786-ba98-325c4e18a42a；未启动或刷新。LSP 诊断完成后核对命令、启动时间和父子关系，仅关闭本轮诊断进程树。
