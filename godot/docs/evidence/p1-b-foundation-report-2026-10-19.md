# P1-B 业务与存档基础对照报告（2026-10-19）

状态：**完成（领域模块、统一命令、独立存档、故障注入与双进程恢复）；S01～S04、F02、R01 已修复。** 本报告覆盖 P1-B 基础层；真实信件、订单、商店、日历、三结局、回溯和新手引导不在本批范围。修复明细见 [P1 修复回执](p1-fix-2026-10-19.md)。

## 1. 交付物

| 旧 Lua | Godot |
|---|---|
| `systems/Potion.lua` | `godot/src/domain/potion.gd` |
| `systems/RecipeDraft.lua` | `godot/src/domain/recipe_draft.gd` |
| `systems/WordToken.lua` | `godot/src/domain/word_token.gd` |
| `core/GameState.lua`（P1 子集） | `godot/src/domain/session_service.gd`、`command_router.gd`、`state_validator.gd` |
| `systems/PlayQueries.lua`（P1 子集） | `godot/src/domain/query_service.gd` |
| `core/SaveSystem.lua` | `godot/src/persistence/snapshot_store.gd`、`save_codec.gd` |
| 设置文件 | `godot/src/persistence/settings_store.gd` |

P1 的保存格式是新封装：`format=tthw-godot`、`schema_version=1`、`content_version`、`revision`、`generation`、`checksum`、`payload`。它不是 Lua schema 4 的复刻，也不读取 Maker 存档。

## 2. 计算与业务对照

| 对照项 | Lua 输入/规则 | Godot 输入/规则 | 用例 | 结果 |
|---|---|---|---:|---|
| 药效八步计算 | `Potion.Calculate` | `Potion.evaluate` | 120 | PASS |
| 残留时间语义 | `SampleResidual` / `ValidateResult` | `sample_residual` / `validate_result` | 18 | PASS（严格相等） |
| 药效结果校验 | `Potion.ValidateResult` | `Potion.validate_result` | 命令/预览断言 | PASS |
| 残留采样 | `Potion.SampleResidual` | `Potion.sample_residual` | 18 个采样/修改点 | PASS |
| 配方草稿 | `RecipeDraft.Validate` | `RecipeDraft.validate` | 8（3 成功、5 错误） | PASS |
| 词条来源 | `WordToken.PlanCut` 来源校验 | `WordToken.validate_source` / `token_id` | 80（77 有效、3 非法） | PASS |
| 草稿/词条/预览命令 | `GameState` 事务子集 | `SessionService.execute` | 31 | PASS |
| A/B 存档与故障 | `SaveSystem` 双快照/提交记录 | `SnapshotStore` | 50 | PASS |
| 进程重启恢复 | `GameState.Load` | `SessionService.load_or_new` | 真实双进程 | PASS |

### 2.1 药效用例构成

- 10 个正式 `stage1.sampleCases`（逐项覆盖首单和 G1～G4 等样例）。
- 77 个词条的主词单独计算。
- 4 种原料的 1 份/2 份、两种原料组合、灰烬草两份副作用路径。
- 12 个辅助词及相邻辅助词组合，覆盖同标签加成和辅助词叠加。
- 共 120 个用例、1734 项字段断言。

比较字段：`synthesisVersion`、`contentVersion`、`effects`、`intensityByEffect`、`mods`、`durationHours`、`onsetDelayHours`、`recoveryAfterEndHours`、`residuals`、`stability`、`unstable`、`sideEffects`。字符串、布尔、强度分级和结构精确比较；权重、修正、时间和残留权重使用每字段 `1e-9` 相对容差。残留采样 API 另用 18 个严格用例：已声明点、点两侧、未声明区间、首点前、末点后和修改残留点；时间相等不使用近似。

**浮点说明：** Lua 与 Godot 在同样的双精度运算中可能出现末位差异（例如 `0.05 * 1.15` 的路径），但强度分级仍精确比较，阈值翻转不会被容差掩盖。该容差是明确的逐字段规则，不是全局宽容阈值。

### 2.2 草稿与词条用例

- 草稿成功路径：空草稿、仅主词、主词+辅助词。
- 草稿错误路径：同一 token 重复占槽 `DUPLICATE_TOKEN`、未知 token `TOKEN_UNAVAILABLE`、原料短缺 `INVENTORY_SHORT`、辅助词超槽 `SLOT_OVERFLOW`、同原料重复行 `DUPLICATE_NOT_ALLOWED`。
- 词条来源有效路径覆盖 11 封订单信的 77 个可剪跨度；非法路径覆盖错误词定义、错误寄信人、错误信实例，结果均为 `SOURCE_INVALID`。
- `cut_word` 同一来源重复切取返回 `changed=false`，不新增 token、不保存；相同 `request_id` 直接返回已提交结果。

## 3. 命令与存档对照

### 3.1 命令语义

| 场景 | 结果 |
|---|---|
| 新会话首次切词 | `revision` 0→1，保存成功后才安装 token |
| 同一请求 ID 重放 | 返回原结果，`revision` 不变 |
| 新请求 ID 重复切同一来源 | `changed=false`，不保存，`revision` 不变 |
| 草稿提交 | `revision` +1，保存成功后安装 |
| 相同草稿再次提交 | `changed=false`，不保存 |
| 预览 | 返回药效，不修改状态、不保存、不递增 revision |
| 过期 `expected_revision` | `STALE_REVISION`，状态不变 |
| 保存明确失败 | 返回错误，不安装候选，不递增 revision |
| 提交结果不确定 | `SAVE_COMMIT_UNCERTAIN`，会话锁定，后续命令返回 `RECOVERY_LOCKED` |

### 3.2 存档状态

| 状态 | 触发条件 | 行为 |
|---|---|---|
| `committed` | 快照写入/读回一致，提交标记写入/读回一致 | 安装内存状态，返回成功 |
| `failed` | 快照写入失败或读回不一致 | 不安装候选，不推进 revision |
| `uncertain` | 快照已写，提交标记写入/读回失败 | 锁定会话，要求同槽重读 |
| `loaded` | 最高有效提交代通过长度/哈希/校验和 | 安装并校验内容版本 |
| `new` | 没有提交标记 | 创建初态，不读取未提交快照 |
| `unsupported` | 完整未来版本/未知格式 | 返回 `SAVE_UNSUPPORTED`，锁定，不回退旧侧 |
| `read_failed` | marker 读失败，无法判定该侧代数 | 返回 `SAVE_READ_FAILED`，锁定 |
| `corrupt` | 标记/快照损坏且另一侧不可用 | 锁定，保留现场 |

最高提交代损坏时回退另一侧，并在 `ignored` 中记录该侧状态；单侧 marker 截断/缺失不影响另一侧有效提交，marker 读失败保持锁定。未来版本返回 `SAVE_UNSUPPORTED` 并锁定，不覆盖原档；内容版本不匹配返回 `CONTENT_VERSION_MISMATCH`。

## 4. 测试结果

```text
python godot/tools/verify.py --suite foundation
[GODOT] PASS suite=foundation assertions=2251
[Restart] PASS separate Godot processes preserve revision, token and draft

python godot/tools/verify.py --suite all
[GODOT] PASS suite=all assertions=2814
```

分项：

| 套件 | 断言/结果 |
|---|---:|
| content | 243 PASS |
| potion | 1734 PASS |
| oracle（词条+草稿） | 177 PASS |
| commands | 31 PASS |
| faults | 66 PASS（含 S01～S04、R01） |
| foundation | 2251 PASS |
| 双进程 restart | PASS |
| P0 layout/scenes/drag/readability | 563 PASS |
| all | 2814 PASS |

双进程检查由 `godot/tools/restart_check.py` 执行：第一个 Godot 进程写入 `user://p1_process_restart`，退出；第二个进程重新启动并验证 `revision=2`、token 和主词草稿。它不是同进程重建对象的替代。

完整输出见 [p1-verify.txt](p1-verify.txt)；P1-A 内容对照见 [P1-A 报告](p1-a-content-report-2026-10-19.md)。

## 5. 问题清单

| ID | 严重度 | 状态 | 问题 | 下一步 |
|---|---|---|---|---|
| P1-B-01 | 中 | 已修复 F02 | 残留采样曾用近似时间比较；现改为严格相等，18 个采样/修改点覆盖。计算权重/时间仍保留逐字段 `1e-9` 对照容差，强度分级精确。 | 公式或内容变化后重跑 potion oracle。 |
| P1-B-02 | 高 | P2 必做 | 草稿暂存顶层 `draft`，Lua 正式状态在 `currentOrder.draft`。 | P2 接订单时迁移字段并定义保存升级路径，不能静默丢草稿。 |
| P1-B-03 | 高 | P2 必做 | `currentOrder` 只支持 `false`；信件实例、订单、商店、日历、结局、回溯、新手引导未实现。 | 按 P2/P4 任务扩展状态与命令；新手引导已在实施计划 Task 4 中明确。 |
| P1-B-04 | 中 | P2 必做 | `StateValidator` 只做 P1 子集校验，未深验证非空 `letters`、`orders`、`world.flags`、叙事事件。 | P2 在接受真实首单状态前补齐逐字段校验。 |
| P1-B-05 | 中 | 开放 | P1 命令未接入 UI；没有 P1 双端包，P0 包仍是 `0.1.3-p0fix`。 | P2 接 UI 后重建双端 debug 包；P6 再冻结正式签名。 |
| P1-B-06 | 中 | 部分修复 | S01/S03、R01 已用测试 IO 复现并修复；真实磁盘断电/短写和写入中的进程崩溃仍未覆盖。 | P2/P5 增加真实文件故障与崩溃恢复证据；保留“不承诺抵抗所有物理磁盘故障”的边界。 |
| P1-B-07 | 低 | 部分修复 | S04 已修复 uncertain 结果的永久缓存；请求 ID 缓存本身仍无上限。 | 长会话或 P5 加容量上限/淘汰策略。 |
| P1-B-08 | 低 | 开放 | `test_layout.gd` 在 `--suite all` 时重写 `p0-layout.json`，造成 P0 证据文件漂移。 | 让证据写入只在 P0 套件执行，或在验收后恢复；当前提交前已手动恢复。 |
| P1-B-09 | 低 | 待确认 | 快照标记的长度使用字符数而非字节数；内部读写一致，不影响校验。 | 若有外部工具解析标记，改为字节长度并版本化。 |
| P1-B-10 | 中 | 未验证 | 没有真实 Windows/Android 上的 `user://godot_save` 目录、重启和损坏提示验收。 | P2/T7 在真机记录目录、重启、保存失败提示和恢复流程。 |
| P1-B-11 | 低 | 未验证 | `SettingsStore` 已实现但没有专项测试；P1 不读写设置。 | P2 音量/设置接入时补测试。 |
| P1-B-12 | 低 | 未测量 | 查询投影使用深复制，未测大量历史记录下的性能。 | P5 用真实长会话测量并按需优化。 |

## 6. 未验证与边界

- 自动检查不替代真实设备上的画面、触控、听感和系统生命周期验收。
- 没有接 P0 场景；P1 的 `cut_word`/`update_draft`/`preview` 只能通过 `SessionService` 调用。
- 没有实现旧档导入；Godot 存档与 Maker 存档完全隔离。
- 没有宣称完整迁移完成；P2 及以后仍按实施计划推进。
