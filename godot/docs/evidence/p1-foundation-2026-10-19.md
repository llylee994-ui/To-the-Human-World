# P1-A / P1-B 基础迁移回执（2026-10-19）

> **独立验收更新：P1 暂未放行。** 已有自动套件复跑通过，但边界探针复现 6 项问题；具体影响、复现与下一步见 [P1 独立验收记录](p1-acceptance-2026-10-19.md)。下文保留原批次交付与验证口径，不代表这些新增问题已修复。

状态：**代码与自动检查完成；未进入 P2，未接正式 UI，未做真机验收。** 本回执覆盖实施计划 Task 2（P1-A）与 Task 3（P1-B），不把自动检查当作完整游戏验收。

## 分批复核

- [P1-A 全量内容对照报告](p1-a-content-report-2026-10-19.md)：数量、正文哈希、引用校验、120 个药效/80 个词条/8 个草稿 oracle 用例与问题清单。
- [P1-B 业务与存档对照报告](p1-b-foundation-report-2026-10-19.md)：命令语义、A/B 存档、故障注入、双进程恢复与问题清单。
- [P1 修复回执](p1-fix-2026-10-19.md)：验收 S01～S04、F01～F02 的修复、探针复跑与新增回归。

## 基线与范围

- 源码基线：`159bd7e7e70500cbcbac09e35c1c7b728e3a1fe8`；P0 视觉基线为 `0.1.3-p0fix`，已先提交到 `feat/godot-p1`。
- 内容版本：`ordinary-release-v3`；内容源码哈希：`e3b557c4d31a772259908bbd2f71731bef4a730e392530ddf9b3961699b412b3`。
- 本批只实现内容导出/加载、词条来源、配方草稿、药效计算、统一命令边界和本地 A/B 存档。信件收发、订单、商店、日历、三结局、新手引导和回退仍属于 P2 及以后。

## P1-A：全量内容

`godot/tools/export_content.py` 通过 Lupa 加载真实 `data.content`，调用 `Data.Load()` 与 `Data.ValidateStage1()`，按 `godot/content/content_schema.json` 导出 `godot/content/generated/catalog.json`，并生成 `godot/tests/fixtures/content_checks.json`。

导出数量：

| 集合 | 数量 |
|---|---:|
| effects | 22 |
| words | 77 |
| ingredients | 4 |
| equipment | 2 |
| furniture | 4 |
| npcs | 11 |
| letters | 22 |
| attributeProfiles | 6 |
| followupTemplates | 11 |
| fragments | 58 |
| directRules | 196 |
| orderRatings | 58 |
| recipes | 58 |
| wishDecorations | 11 |
| requiredOrders | 11 |
| homeItems | 4 |
| sampleCases | 10 |

空表数组/对象边界在 `content_schema.json` 中显式声明；未声明的空表会让导出失败，避免把 `[]` 静默写成 `{}`。引用校验覆盖词条效果、原料修正、设备槽位、信件寄信人/规则集/模板/剪词来源、模板与片段互相引用、结局正文、家具、愿望装饰资源路径和 196 条规则的字段形状；错误输出包含 `code`、`path`、`message`。

`godot/src/content/content_catalog.gd` 加载 catalog 时再校验 schema 版本、必需集合、重复 ID 和声明计数；`get_entry`/`entries` 返回深复制投影。

`godot/tools/export_oracle.py` 生成 `godot/tests/fixtures/oracle_cases.json`：120 个药效用例、80 个词条来源用例、8 个草稿校验用例，均由原 Lua 计算。`export_content.py --check` 与 `export_oracle.py --check` 已接入 `verify.py` 的 `content`/`foundation`/`all` 套件，内容或 oracle 陈旧会阻止测试。

`godot/tests/unit/test_content.gd` 检查数量、版本、来源哈希、22 封正式信件的标题/正文哈希、每封信的剪词跨度数量、必需订单、三结局正文、未知 ID、重复 ID 和计数不一致，共 243 项断言（22 封信标题/正文哈希与 5 个类型/引用负例）。

## P1-B：业务与存档

新增领域模块：

- `potion.gd`：八步计算、药效分级、原料修正、副作用、残留采样、时间换算与结果校验。
- `recipe_draft.gd`：主词可空、槽位、同实例/同定义重复策略、库存和原料合并校验。
- `word_token.gd`：按 `letter:<id>` 与 span 生成唯一 token，校验来源信/寄信人/词定义/跨度，支持幂等切词和配方解析。
- `state_validator.gd`：P1 完整状态结构、人物初态 schema、经济、词条、草稿和章节校验。
- `command_router.gd`：`cut_word`、`update_draft`、`preview` 三个命令；候选状态由调用方提交，预览不改变状态。
- `session_service.gd`：统一请求 `{request_id, expected_revision, command, payload}`；请求 ID 幂等、`STALE_REVISION` 拒绝、提交成功后才安装内存状态；不确定提交锁定并要求重读。
- `query_service.gd`：会话状态、库存、词条托盘、草稿、药效预览和内容计数投影，全部返回深复制。

存档：

- `save_codec.gd`：`format=tthw-godot`、`schema_version=1`、`content_version`、`revision`、`generation`、`checksum`、`payload`；规范化 JSON 计算校验和，整数浮点在规范化和校验时统一为整数。
- `snapshot_store.gd`：A/B 快照、提交标记、写入后读回、标记写后读回；状态只能是 `committed`、`failed`、`uncertain`；最高有效提交代加载，最新快照损坏时回退另一侧。
- `settings_store.gd`：独立设置文件，不进入业务快照。

## 自动检查结果

在仓库根目录执行：

```text
python godot/tools/verify.py --suite foundation
[GODOT] PASS suite=foundation assertions=2235

python godot/tools/verify.py --suite all
[GODOT] PASS suite=all assertions=2798
```

分项：

| 套件 | 断言 | 结果 |
|---|---:|---|
| content | 243 | PASS |
| potion | 1734 | PASS |
| oracle | 177 | PASS |
| commands | 31 | PASS |
| faults | 50 | PASS |
| P0 layout/scenes/drag/readability | 563（合计） | PASS |

`potion` 套件按字段比较：字符串、布尔、强度分级和结构字段精确比较；药效权重、修正值、时间与残留权重使用每字段 `1e-9` 相对容差。容差只用于已知的 IEEE 浮点运算差异，强度分级仍精确比较，阈值翻转不会被容差掩盖。

`commands` 套件覆盖：切词提交、同一请求 ID 重放不重复保存、重复切同一来源幂等、草稿提交/重放、预览不写入、过期 revision 拒绝、重启后词条与草稿恢复。`faults` 还覆盖 S01～S04：恢复后写非活动侧、未来版本锁写、单侧 marker 损坏、uncertain 重读对账。

`faults` 套件覆盖：快照写失败不提交、标记写失败为不确定、标记读回失败为不确定、最新快照损坏回退上一代、校验和篡改检测、保存失败不安装候选、不确定提交锁定后续命令。

## 未验证与已知边界

- 没有真实 Windows/Android 画面、触控或真机存档目录验收；P1 自动检查只证明领域与存档逻辑。
- 没有把 P1 命令接到 P0 场景按钮；当前 UI 仍只导航和演示。
- `currentOrder` 只支持 `false`；信件实例、订单生命周期、商店、日历、结局、回溯和新手引导未迁移。
- 存档目录为 Godot 侧独立 `user://godot_save`，不复用 Maker 存档；旧档导入未实现。
- P1 的包名沿用 P0 调试包 `cn.tothehumanworld.godotp0`，正式包名/签名在 P6 冻结。
- 迁移后内容仍以原 Lua 数据为权威；任何内容改动必须重新运行导出工具并让 `--check` 通过。
