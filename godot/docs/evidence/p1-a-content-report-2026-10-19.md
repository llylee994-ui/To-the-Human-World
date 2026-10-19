# P1-A 全量内容迁移对照报告（2026-10-19）

状态：**完成（代码、导出、自动对照）；F01 修复已补入。** 本报告覆盖 P1-A 内容层；正式信件实例、订单和 UI 不在本批范围。修复明细见 [P1 修复回执](p1-fix-2026-10-19.md)。

## 1. 基线与交付物

- 源码基线：`159bd7e7e70500cbcbac09e35c1c7b728e3a1fe8`。
- 内容版本：`ordinary-release-v3`。
- 内容源码：`scripts/data/` 共 20 个 Lua 文件；聚合入口 `scripts/data/content.lua`。
- 内容源码哈希：`e3b557c4d31a772259908bbd2f71731bef4a730e392530ddf9b3961699b412b3`。
- 生成产物：`godot/content/generated/catalog.json`。
- 校验夹具：`godot/tests/fixtures/content_checks.json`。
- 导出工具：`godot/tools/export_content.py`。
- 加载器：`godot/src/content/content_catalog.gd`。
- 自动检查：`godot/tests/unit/test_content.gd`。

## 2. 数量对照

| 集合 | Lua 数量 | Godot catalog | 结果 |
|---|---:|---:|---|
| effects | 22 | 22 | 一致 |
| words | 77 | 77 | 一致 |
| ingredients | 4 | 4 | 一致 |
| equipment | 2 | 2 | 一致 |
| furniture | 4 | 4 | 一致 |
| npcs | 11 | 11 | 一致 |
| letters | 22 | 22 | 一致 |
| attributeProfiles | 6 | 6 | 一致 |
| followupTemplates | 11 | 11 | 一致 |
| fragments | 58 | 58 | 一致 |
| directRules | 196 | 196 | 一致 |
| orderRatings | 58 | 58 | 一致 |
| recipes | 58 | 58 | 一致 |
| wishDecorations | 11 | 11 | 一致 |
| requiredOrders | 11 | 11 | 一致 |
| homeItems | 4 | 4 | 一致 |
| sampleCases | 10 | 10 | 一致 |

`content_schema.json` 中的 `expected_counts` 固定了上述基线；任何数量变化必须显式更新 schema，不能静默改变。

## 3. 正文与引用对照

- 22 封信全部导出；11 封正式订单信保留 `body`、`requirement`、`cutWordIds`、`reward`、`ratingSetId`、`directRuleSetId`、`followupTemplateId`。
- 22 封信的 `title` 和 `body` 在导出时计算 SHA-256，运行时 `test_content.gd` 重算并逐封比对；其中 11 封订单信有正文和剪词跨度，11 封后续回信正文为空但标题参与哈希；正文没有被改写或重新润色。
- 11 封订单信的可剪跨度由 Lua `Letter.ParseDefinition` 解析后导出；每个 `cutWordIds` 词定义都必须出现在该信的 span 中，缺失会使导出失败。
- 11 个必需订单均引用 `kind="order"` 的信件；`release.homeItems` 全部引用家具集合。
- 三结局 `departure`、`apprentice`、`wish` 的标题和正文均非空。
- 11 个愿望装饰的 `path` 在 `assets/` 中存在；P1 只校验源资源存在，Godot `media/` 同步属于 P4/P5。
- 引用校验覆盖：词条效果、原料 mods/addTags、设备槽位、信件寄信人/规则集/评分集/模板/剪词来源、模板与片段互引、规则条件操作符与变更字段、评分事实数组、结局正文、家具和样例配方。

错误输出统一为 `{code, path, message}`；重复 ID、未知引用、计数不符、空表类型未声明和剪词跨度缺失都有独立错误码。`test_content.gd` 用合成 catalog 验证了重复 ID、计数不符和未知 ID 的错误定位。

## 4. 测试结果

在仓库根目录执行：

```text
python godot/tools/export_content.py --check
catalog check passed: godot/content/generated/catalog.json

python godot/tools/verify.py --suite content
[GODOT] PASS suite=content assertions=198
```

| 检查 | 结果 |
|---|---|
| 导出可重复性 `--check` | PASS |
| 内容加载/计数/正文哈希/引用 | PASS，243 项断言（含 5 个类型/引用负例） |
| 全量 Godot 套件中的 content 部分 | PASS，198 项 |
| 旧 Lua 数据加载与 `ValidateStage1` | PASS |

完整输出见 [p1-verify.txt](p1-verify.txt)；运行时间与机器信息以该文件为准。

## 5. 问题清单

| ID | 严重度 | 状态 | 问题 | 下一步 |
|---|---|---|---|---|
| P1-A-01 | 中 | 开放 | `godot/media` 尚未包含 catalog 引用的 4 个愿望装饰资源；P0 媒体快照为 37 个文件。 | P4 拼贴 UI 前运行/扩展 `prepare_media.py --scope all`，并校验内容引用与 Godot 媒体清单一致。 |
| P1-A-02 | 低 | 已修复 F01 | 空容器类型与引用/枚举负例曾未闭环；现由导出器显式类型检查、`ContentValidation` 和 5+5 个负例覆盖。 | 新增空字段时同步更新 schema 并重跑 `--check`。 |
| P1-A-03 | 低 | 已知流程 | 内容仍以 Lua 为权威，修改内容后必须重新导出；目前没有 Git hook 或 CI 强制。 | 构建/提交前统一运行 `verify.py`，其 content/foundation/all 已包含 `--check`。 |
| P1-A-04 | 低 | 已知边界 | 剪词跨度直接使用 Lua 解析结果，GDScript 没有独立解析器。 | 这是刻意的对照策略；Lua 解析器变化时必须重新导出并重跑内容测试。 |
| P1-A-05 | 中 | 开放 | 旧 Lua 完整信件表现回归仍有已知失败 `PaperConsistencyTest.lua:58`（旧 `activePanel` 断言）。 | 使用定向内容/信件套件作为 oracle；在 P2 前修复或归档该测试，避免把整包旧回归当作通过。 |
| P1-A-06 | 低 | 待测量 | catalog 约 740KB，未测真实设备加载耗时。 | P5 记录启动时间；必要时拆分或按组加载。 |

## 6. 未验证

- 没有把 catalog 接到 P0 场景；P1-A 只证明内容可加载、可查询、可对照。
- 没有验证 Godot `media/` 对全部内容资源的实际加载；见 P1-A-01。
- 没有证明 22 封信的排版、换行和可剪标记在 Godot UI 中的表现；这属于 P2。
