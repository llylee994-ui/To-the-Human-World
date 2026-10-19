# 《寄往人间》Godot 完整迁移实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 执行状态（2026-10-19）：P0/Task 1、P1-A/Task 2、P1-B/Task 3 已执行；P2/Task 4 及以后未开始。P1 证据见 [P1 基础回执](../../../godot/docs/evidence/p1-foundation-2026-10-19.md)。不自动派发子代理。

**Goal:** 将当前普通发行内容迁移为可独立离线运行的 Android 与 Windows Godot 正式版本。

**Architecture:** GDScript 移植纯业务模块，构建期从正式 Lua 数据导出 JSON；原 Lua 是规则对照基准。UI 经统一命令/查询访问状态，候选状态校验和持久化成功后才安装到内存。正式工程位于 `godot/`，实验工程与 Maker 对照工程保留。

**Tech Stack:** Godot 4.7.2 标准版、Compatibility、GDScript、JSON、Python 构建工具及 Lupa Lua 5.4、Java 21、Android SDK。

## Global Constraints

- 方案依据：[完整迁移方案书](../../设计/寄往人间_Godot完整迁移方案书_v01.md)，其中范围、验收矩阵和风险边界同时适用。
- 冻结源基线：`159bd7e7e70500cbcbac09e35c1c7b728e3a1fe8`，内容版本 `ordinary-release-v3`；执行前记录工作区有效改动及内容哈希，不以 HEAD 代替实际文件版本。
- 11 个必需订单、77 个词条、4 种原料、11 个角色、22 封信件定义、196 条直接规则、58 个片段与 58 条评分定义；信件定义数量不等于订单数。
- 保留离开、愿望、学徒三结局以及留念、回溯和新旅程；不增加历史主线、账号、广告或联网能力。
- 原 `scripts/`、`assets/`、Maker 绑定和现有存档保持完整；本计划不授权发布、远端构建或替换应用。
- 只使用后台检查和自己启动的隐藏进程，不控制用户桌面；真实手机操作与听感由用户反馈记录。
- 所有下列 `godot/` 路径为拟创建文件，本文件不表示它们已存在。任务可逐个评审，不并行修改共享状态。
- 先只执行 P0 并交付双端视觉基准；后续阶段按前一阶段验收结果推进。P0 已于 2026-10-19 执行，Task 2 至 8 仍待用户确认画面后启动。
- 此计划定义阶段成果、接口和代表性验收代码；不把示意测试当成覆盖全部规则的最终测试集。遇到与冻结源码冲突的业务细节，先追加对照用例并修订相应任务。

---

## 文件与测试入口约定

| 路径 | 职责 |
|---|---|
| `godot/AGENTS.md`、`godot/README.md` | 独立 Godot 工作流、离线开发与构建说明 |
| `godot/project.godot`、`godot/export_presets.cfg` | 固定引擎、横屏、设计画布、双端导出；不存密码 |
| `godot/tools/prepare_media.py` | 按实际引用复制资源、生成来源与哈希清单 |
| `godot/tools/export_content.py` | 隔离加载 Lua，按 schema 导出正式内容 |
| `godot/tools/export_oracle.py` | 用原 Lua 执行固定输入，导出规范化期望结果 |
| `godot/tools/verify.py` | 导入、测试和差异报告的统一后台入口 |
| `godot/tools/build.py` | 校验后本地双端导出、检查与交付清单 |
| `godot/tests/run_tests.gd` | 按 suite 运行测试，失败 exit(1)，成功 exit(0) |
| `godot/tests/fixtures/` | 真实内容夹具与原 Lua 期望；保存 source_hash |
| `godot/docs/evidence/` | 文本验收记录；大包、日志、录屏写入被忽略的 build/evidence |

命令统一在仓库根目录执行。`verify.py` 提供 `--suite`、`--godot` 与 `--python-libs` 参数；默认从本机工具配置查找已验证便携版，缺失时直接报工具缺失，不自动下载、改 PATH 或打开窗口。`build.py` 提供 `--target windows|android|all`、`--configuration debug|release` 和 `--output`。release 缺密钥时退出，不降级成调试签名冒充正式包。

计划中测试代码使用各套件内部创建的 fixture；所有 helper 必须与对应套件同一任务实现，不能依赖生产 UI。

## Task 1 / P0：正式骨架、素材尺寸与宽屏基线

**Files:**
- Create: `godot/AGENTS.md`、`godot/README.md`、`godot/.gitignore`、`godot/project.godot`、`godot/export_presets.cfg`
- Create: `godot/tools/prepare_media.py`、`godot/tools/verify.py`、`godot/tools/build.py`
- Create: `godot/scenes/boot.tscn`、`godot/scenes/title.tscn`、`godot/scenes/home.tscn`、`godot/scenes/brew.tscn`
- Create: `godot/src/app/layout_service.gd`、`godot/src/presentation/home_layers.gd`
- Create: `godot/ui/components/paper_panel.tscn`、`godot/ui/components/word_slip.tscn`、`godot/src/presentation/word_slip.gd`
- Test: `godot/tests/run_tests.gd`、`godot/tests/integration/test_layout.gd`
- Read: `scripts/ui/landscape/LayoutManifest.lua`、`scripts/ui/landscape/WordSlip.lua`、`experiments/godot-migration/src/main.gd`。

**Interfaces:**
- `LayoutService.layout(viewport_size: Vector2, safe_rect: Rect2) -> Dictionary`：返回设计区、背景区、内容安全区和物件目标框。
- `HomeLayers.apply_layout(layout: Dictionary) -> void`：节点纹理尺寸不反向撑大目标框。
- `WordSlip.configure(text: String, token_id: String, max_width: float) -> void`：纸面根据实测文本宽高与内边距生成；点击/拖拽使用 token_id。

- [x] 记录当前截图、源布局和每层素材尺寸/alpha 可见框，生成来源清单，不改变素材原件。
- [x] 在测试中固定 1920×1080、2340×1080、2400×1080、2412×1080 与带安全区场景；捕获每个物件的预期框与运行框。验证版失败证据沿用用户截图和原生纹理尺寸对照，本轮未重新启动验证版。
- [x] 建正式工程，先设置 `expand_mode = TextureRect.EXPAND_IGNORE_SIZE`，再设纹理和目标框；核验父级缩放、锚点、可见框，不能只凭设置顺序宣告修复。
- [x] 背景适配宽屏，关键交互留在安全区；保留构图与素材比例，不能横向拉伸文字。超宽屏通过扩展背景/柔和延展及响应侧栏处理。
- [x] 迁移标题、主页和工作台静态视觉；纸条覆盖最长真实词条与换行，验证尺寸、基线、拖拽热区。

```gdscript
# test_layout.gd 中的代表性断言；nodes 与 expected 来自真实场景装配。
for id in expected:
    assert(nodes[id].get_rect().is_equal_approx(expected[id]))
assert(safe_rect.encloses(primary_action.get_global_rect()))
assert(word_slip.size.y >= measured_text_height + padding_top + padding_bottom)
```

- [x] 执行 `python godot/tools/verify.py --suite all`；导出 `python godot/tools/build.py --target all --configuration debug --output godot/build/p0`。
- [x] 双端运行截图与基准并排记录，由用户确认物件比例、宽屏和点击。仅自动测试通过不能放行。用户已确认 `0.1.3-p0fix` 为视觉基线；Android 真机画面、触控与飞行模式仍未单独复验。

**P0 执行结果（2026-10-19，含验收修复轮）：** `verify.py --suite all` 通过 **255** 项断言（布局、真实场景安全区、旋转热区、鼠标拖拽/落锅/取消）。证据见 [P0 证据](../../../godot/docs/evidence/p0.md)、[修复回执](../../../godot/docs/evidence/p0-fix-2026-10-19.md) 与 [p0-layout.json](../../../godot/docs/evidence/p0-layout.json)。关键尺寸：捞网 345.5×518.3、商船 219.2×198.1、药炉 361.2×329.6，均不再使用原生纹理尺寸。宽屏主页改为原始 1920×1080 房间居中，两侧用室内前景的低细节墙带横向延展并加软化渐变，不再使用深色侧栏或放大裁切；门外海面按 `SeaArt.homeSea` 的设计坐标 `(0, -115, 1920, 1080)` 与室内前景一起缩放。词条纸条按文字自动尺寸，工作台和标题页字体放大，标题按钮改为纯文字样式。修复包：Windows 151,190,776 字节 SHA256 `16b9d26a7f2523266fbb2437117af68522cfff1da3e77b4f2d1d5ce2ebd8a493`；Android 79,396,645 字节 SHA256 `fb0867d9b410436eea965395237c8ac2a9308eab50050b2c5bd0a5232d32162a`。Android 包 arm64、无 INTERNET 权限、v2/v3 调试签名、landscape；未连接真机，画面与触控未验证。

**交付/门禁：** A02～A05 的基础画面证据、P0 双端包与局限清单；未接入功能明确标记为演示，不能假装可完成正式首单。

## Task 2 / P1-A：完整内容导出与 Lua 对照工具

**Files:**
- Create: `godot/tools/export_content.py`、`godot/tools/export_oracle.py`
- Create: `godot/content/content_schema.json`、`godot/content/generated/catalog.json`
- Create: `godot/src/content/content_catalog.gd`、`godot/tests/fixtures/content_counts.json`
- Test: `godot/tests/unit/test_content.gd`、`godot/tests/parity/test_oracle.gd`
- Read: `scripts/data/content.lua`、`scripts/data/release.lua`、所引用数据及现有隔离测试环境。

**Interfaces:**
- `ContentCatalog.load_catalog(path: String) -> Dictionary`：返回 `{ok, value}` 或 `{ok:false, error:{code,path,message}}`。
- `ContentCatalog.get_entry(collection: String, id: String) -> Dictionary`：返回独立投影，不暴露可变原表。
- 导出文件包含 `content_version`、`source_hash`、`schema_version`、collections；对照夹具包含 `case_id`、`input`、`expected`、`source_hash`。

- [x] 以真实 Lua 加载结果建立字段 schema，明确空表类型、整数、数组顺序、文本与可剪跨度；不以正则抽取源码。
- [x] 添加重复 ID、缺失引用、未知条件枚举和错误空表用例，要求导出/加载失败并指向字段路径。
- [x] 完整导出当前内容与规则；记录全部输入文件哈希。可变正文原样保留，不重新润色。
- [x] 将源 Lua 计算与事务测试入口封装为只读 oracle；规范化无序字典，不对有序词槽/叙事片段排序。

```gdscript
assert(catalog.words.size() == 77)
assert(catalog.ingredients.size() == 4)
assert(catalog.letters.size() == 22)
assert(catalog.release.requiredOrderIds.size() == 11)
assert(catalog.directRules.size() == 196)
```

- [x] 执行 `python godot/tools/export_content.py` 与 `python godot/tools/verify.py --suite content`；检查正文 UTF-8、换行及片段引用。

**交付/门禁：** 全量可加载内容、schema、来源哈希与可执行对照流水线；夹具不使用验证版三个词替代正式内容。

## Task 3 / P1-B：领域边界、正式保存与基础计算

**Files:**
- Create: `godot/src/domain/session_service.gd`、`command_router.gd`、`query_service.gd`、`state_validator.gd`、`potion.gd`、`recipe_draft.gd`、`word_token.gd`
- Create: `godot/src/persistence/snapshot_store.gd`、`save_codec.gd`、`settings_store.gd`
- Test: `godot/tests/unit/test_commands.gd`、`test_save_faults.gd`、`godot/tests/parity/test_potion.gd`
- Read: `scripts/core/GameSession.lua`、`SaveSystem.lua`、`SaveSchema.lua`；`scripts/systems/Potion.lua`、`RecipeDraft.lua`、`WordToken.lua`。

**Interfaces:**
- `SessionService.execute(request: Dictionary) -> Dictionary`：请求 `{request_id,expected_revision,command,payload}`，成功 `{ok:true,revision,value}`，失败 `{ok:false,error:{code,path,message}}`。
- `QueryService.project(state: Dictionary, name: String, args: Dictionary) -> Dictionary`：深复制视图。
- `SnapshotStore.commit(envelope: Dictionary) -> Dictionary`：`status` 只能为 `committed`、`failed`、`uncertain`，带 generation；`load_latest() -> Dictionary` 选有效已提交代。
- `Potion.evaluate(recipe: Dictionary, catalog: Dictionary) -> Dictionary`：纯函数，结果与原 Lua 对照。

- [x] 先建立原 Lua 用例：相同词、不同来源 token、非法槽位、原料短缺、药效阈值两侧、相同请求重放、过期 revision。
- [x] 实现草稿和纯计算，逐字段对照；确定浮点规则后再开放 UI。
- [x] 实现 A/B 快照、checksum、提交记录与新封装格式；使用独立测试目录和独立包名，不读取原生产槽。
- [x] 注入打开失败、短写、读回错误、提交记录写后读失败、最新代损坏；使用新进程恢复验证。

```gdscript
var before := session.snapshot().duplicate(true)
store.fail_at = "write_snapshot"
assert(not session.execute(command).ok)
assert(session.snapshot() == before)
store.fail_at = "read_commit_after_write"
session.execute(command)
assert(session.is_recovery_locked())
```

- [x] `snapshot() -> Dictionary` 与 `is_recovery_locked() -> bool` 是 SessionService 的独立投影/恢复锁接口；测试 store 实现同任务的故障注入适配器，生产代码不暴露注入开关。
- [x] 执行 `python godot/tools/verify.py --suite foundation`；基础计算、明确失败不安装候选、提交不确定锁定与重读恢复全部通过。

**交付/门禁：** 领域 API、可靠存档及对照报告；未达到提交可靠性不能先接正式发货。

## Task 4 / P2：真实首单完整闭环

**Files:**
- Create: `godot/scenes/seaside.tscn`、`godot/ui/components/letter_reader.tscn`、`word_tray.tscn`、`journal_book.tscn`、`modal_shell.tscn`
- Create: `godot/src/domain/letter.gd`、`order_lifecycle.gd`、`order_trial.gd`、`brew_journal.gd`、`day_flow.gd`
- Create: `godot/src/domain/onboarding.gd`、`godot/src/presentation/onboarding_presenter.gd`
- Create: `godot/src/presentation/seaside_presenter.gd`、`letter_presenter.gd`、`brew_presenter.gd`、`journal_presenter.gd`
- Modify: P0 的主页、工作台与纸条绑定，SessionService 命令分发。
- Test: `godot/tests/integration/test_first_order.gd`、`test_restart.gd`、`test_touch_cancel.gd`、`test_onboarding.gd`
- Read: 当前正式 `Letter/OrderTrial/OrderLifecycle/BrewJournal/ReleaseCoordinator` 及顶部最新前端接口契约。

**Interfaces:**
- 命令动作与 payload 逐一映射冻结 Lua 契约，不按示例自行设计消耗点；统一通过 `SessionService.execute()`。
- `present(view: Dictionary) -> void` 为 presenter 输入；只接收 QueryService 深复制视图。演出完成只能请求下一步骤，不直接增加库存。

- [ ] 用真实首单导出成功、失败、试做、重置、待确认与重复确认轨迹，固定每一步的库存/金币/订单/记录。
- [ ] 迁移捕捞收信与裁词唯一来源，再接词托盘和配方草稿；点击和拖放共用命令路径。
- [ ] 迁移新手引导：开场便签、打捞/读信/剪词/接单、工作台四步、跳过、存档恢复与设置内重读便签；不重复读信、剪词或接单。`onboarding` 作为可选 payload 字段随整档保存，不递增业务 revision。
- [ ] 迁移试做、结果、待确认、发货和记录书；试做与正式结算边界完全按 oracle，不能因播放熬药动画提前扣料。
- [ ] 每个持久化节点退出进程重启，比较恢复投影；弹窗、拖拽取消、切后台不能穿透或提交两次。

```gdscript
var first := session.execute(confirm_request)
var after := session.snapshot()
assert(session.execute(confirm_request) == first)
assert(session.snapshot() == after)
assert(restarted_session.snapshot() == after)
```

- [ ] 执行 `python godot/tools/verify.py --suite first-order` 并交付 P2 双端 debug 包；用户以真实触控完成一单与重启。

**交付/门禁：** A06～A08、A10～A11 首单证据，真实内容可完整离线游玩。

## Task 5 / P3：全部订单、经营与日程

**Files:**
- Create: `godot/src/domain/story_rules.gd`、`narrative.gd`、`world_state.gd`、`economy.gd`、`release_ledger.gd`、`order_audit.gd`
- Create: `godot/ui/components/shop_panel.tscn`、`calendar_panel.tscn`，对应 `godot/src/presentation/shop_presenter.gd`、`calendar_presenter.gd`
- Modify: 已建立的领域、内容和主页模块，增加全量查询与命令。
- Test: `godot/tests/parity/test_all_orders.gd`、`test_schedule.gd`、`test_economy.gd`
- Read: 正式 `StoryRules/Narrative/WorldState/Economy/ReleaseLedger/OrderAudit` 及 `data/release.lua`。

**Interfaces:**
- `StoryRules.evaluate(context: Dictionary, catalog: Dictionary) -> Dictionary` 返回原契约的规则/片段/事实变化。
- 商店报价包含业务 revision 和商品身份；购买经统一命令验证报价，拒绝陈旧报价。
- 结束当天、补货与来信资格由领域模块决定；UI 不计算“下一天”。

- [ ] 为全部 11 个 requiredOrderIds 建 oracle 轨迹，覆盖现有可触发片段、评分和人物事实条件；覆盖缺口逐条列出，不能只测一条成功路径。
- [ ] 迁移全规则、回信、评分、试做历史投影；确认未触发文本不提前展示。
- [ ] 迁移原料、家居、船票、库存报价和日程；验证购票窗口与重复购买按当前配置，金币不足和过期报价不安装候选。
- [ ] 长信、长词、低库存和跨天弹窗逐一检查；全量重放结果按字段比较，阈值差异必须定位。

```gdscript
assert(godot_trace.required_order_ids == lua_trace.required_order_ids)
assert(godot_trace.fragments == lua_trace.fragments)
assert(godot_trace.ratings == lua_trace.ratings)
assert(godot_trace.final_state == lua_trace.final_state)
```

- [ ] 执行 `python godot/tools/verify.py --suite full-game`；输出零未解释差异的报告和 P3 双端包。

**交付/门禁：** 11 单全量经营与 A07/A09 对照；22 封定义不被误实现为额外必需订单。

## Task 6 / P4：三结局、拼贴、回溯与留念

**Files:**
- Create: `godot/src/domain/release_endings.gd`、`release_epilogue.gd`、`wish_collage.gd`、`rewind_history.gd`、`journey_record.gd`
- Create: `godot/scenes/ending_departure.tscn`、`ending_apprentice.tscn`、`ending_wish.tscn`
- Create: `godot/src/presentation/ending_presenter.gd`、`collage_presenter.gd`、`memories_presenter.gd`
- Modify: 标题、导航、统一命令入口与保存 schema 的领域 payload。
- Test: `godot/tests/parity/test_endings.gd`、`godot/tests/integration/test_ending_restart.gd`
- Read: 正式 `ReleaseEndings/ReleaseEpilogue/WishCollage/RewindHistory/JourneyRecord` 与前端接口手册顶部契约。

**Interfaces:**
- 统一命令封装原 `StartJourney(expectedRevision)`、`AdvanceEpilogue(expectedRevision,expectedStep)`、`ConfirmEnding(expectedRevision,kind)` 契约。
- `kind` 仅 `departure/wish/apprentice`；离开结局由正式购票事务路径触发，不能用普通确认接口绕过。
- 拼贴保存归一化放置、sourceTokenId 和冻结正文；回顾只读冻结结果，不重新跑结算。

- [ ] 导出三条路线的触发、演出、确认、回溯和新旅程轨迹，包含不符合资格时的拒绝结果。
- [ ] 学徒以旁白接来信并展开纸面，离开按既定演出，愿望保留桌面托盘、纸条布局、封瓶及回顾；复用已确认美术方案，不生成新图替代缺失逻辑。
- [ ] 每个结局步骤与拼贴编辑/封瓶前后重启，验证恢复步骤、文字、布局及库存冻结。
- [ ] 验证同一步重复点击、旧 expectedStep、新旅程保留留念、回溯不覆盖历史冻结结局。

```gdscript
assert(restarted_ending_view.phase == saved_ending_view.phase)
assert(restarted_ending_view.memories == saved_ending_view.memories)
assert(restarted_collage.placements == saved_collage.placements)
assert(replay_confirmation_state == once_confirmation_state)
```

- [ ] 执行 `python godot/tools/verify.py --suite endings`；双端人工完成三结局与回顾，记录 A12～A13。

**交付/门禁：** 三结局和留念可恢复，不能用三张静态展示图宣告玩法完成。

## Task 7 / P5：预加载、全音频与设备收敛

**Files:**
- Create: `godot/src/app/resource_loader.gd`、`input_lifecycle.gd`、`godot/src/audio/audio_service.gd`
- Create: `godot/content/generated/resource_groups.json`、`audio_catalog.json`
- Modify: boot、各 presenter、SettingsStore 与资源准备脚本。
- Test: `godot/tests/integration/test_resources.gd`、`test_audio_policy.gd`、`test_lifecycle.gd`
- Read: `scripts/ui/landscape/AudioCatalog.lua`、现有加载页和设置契约。

**Interfaces:**
- `ResourceLoader.load_group(group_id: String) -> void`，信号 `progress(group_id,completed,total)`、`ready(group_id)`、`failed(group_id,path,code)`。
- `AudioService.play_bgm(id: String) -> void`、`play_sfx(id: String) -> void`、`apply_settings(settings: Dictionary) -> void`；BGM/SFX 分总线。
- `ready` 仅表示资源组就绪；允许交互还需目标场景装配、布局及首帧门禁。

- [ ] 全部资源路径校验为本地 res://；测试缺资源必须失败并可重试，不能静默进入缺图页面。
- [ ] 接真实加载进度和场景内存释放；首击音效提前准备，BGM 淡入淡出和切后台策略明确且不叠播。
- [ ] 设置面板的“回顾新手便签”随引导迁移；只重开便签，不改变当前旅程步骤或业务状态。
- [ ] 在用户手机记录型号、系统和包版本，执行首次安装飞行模式启动、系统返回、触控取消、后台恢复、一小时稳定性和声音测试。
- [ ] 记录进入时间、帧时间和内存峰值；按方案目标定位超标项，不以“测试机不够好”跳过。

```gdscript
assert(resource_manifest.remote_urls.is_empty())
assert(audio_service.active_bgm_count() <= 1)
assert(settings_after_restart == settings_before_exit)
```

- [ ] `active_bgm_count() -> int` 为 AudioService 的诊断查询；执行 `python godot/tools/verify.py --suite presentation`。真人听感与安卓设备记录另外归档，不能由诊断值替代。

**交付/门禁：** A01/A04/A14/A15 证据及发布候选问题清单。

## Task 8 / P6：签名、干净交付与切换档案

**Files:**
- Modify: `godot/tools/build.py`、`godot/export_presets.cfg`、`godot/README.md`
- Create: `godot/docs/RELEASE.md`、`godot/docs/ACCEPTANCE.md`、`godot/media/LICENSES.md`
- Output (ignored): `godot/build/<version>/delivery.json`、APK、Windows ZIP、校验报告。
- Test: `godot/tests/integration/test_build_manifest.gd`，以及 APK/ZIP 的平台工具检查。

**Interfaces:**
- delivery.json 包含源码 revision/工作区哈希、内容哈希、Godot/模板版本、包名、版本、架构、权限、签名摘要、包体 SHA256、验收报告位置。
- 正式签名从用户持有的密钥安全配置读取；不得输出密码或把密钥放进包、源码和日志。

- [ ] 逐项检查 A01～A16，未验项目保留“未验”；未通过项列明影响并作明确发行判断，不改成通过。
- [ ] 运行全套 `python godot/tools/verify.py --suite all`；检查资源来源与许可、导出排除规则、无私人存档/测试夹具/工具混入。
- [ ] 本地导出 `python godot/tools/build.py --target all --configuration release --output godot/build/release-candidate`；验证 APK 权限、证书、版本、CRC、对齐，Windows 干净目录与无开发工具运行。
- [ ] 用同签名旧候选更新安装验证进度保持；首次安装与更新测试分开记录。
- [ ] 保留 Maker 冻结基线和上一可运行 Godot 包，写清恢复方法。交付正式候选后，上传或替换应用另按用户指令执行。

**交付/门禁：** 可追溯 APK 与 Windows ZIP、源码、构建说明、验收报告、已知限制和回退档案；调试包不能充当正式签名交付。

---

## 自检与进度口径

- P0 对应画面与输入基线；P1 对应内容/业务/保存；P2 对应真实首单；P3 对应全部经营；P4 对应结局/回溯；P5 对应离线/音频/设备；P6 对应最终交付。
- 每任务只在可重复的测试与证据通过后勾选；这份方案的存在不代表任何迁移任务已完成。
- 基础接口在本文件中统一命名；细化业务命令 payload 时同步更新本计划与冻结对照用例。
- P0～P2 后根据实际耗时估算剩余排期，不以实验包导出耗时推算完整移植。
