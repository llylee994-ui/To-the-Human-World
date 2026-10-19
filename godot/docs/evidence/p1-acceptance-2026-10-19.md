# P1 独立验收记录（2026-10-19）

**结论：暂不放行 P1。现有套件通过，但新增边界探针复现 6 项需要修复的问题。先完成 P1 修复与复验，再进入 P2。**

本次只做验收和问题记录，未修复生产代码、未启动 P2、未修改旧 Maker 工程或玩家存档、未导出或上传安装包。用户确认的 P0 完成状态不在本次重新评审范围内。

## 基线、范围与证据

- P0 基线：`a2878d9`；验收 HEAD：`e889555`，范围为 `40da9c1`、`e889555` 的 P1 内容与基础业务/保存改动。
- 对照依据：[完整迁移方案书](../../../docs/设计/寄往人间_Godot完整迁移方案书_v01.md) §5、§7、§10；[实施计划](../../../docs/superpowers/plans/2026-10-19-godot-full-migration.md) Task 2 / Task 3。
- 已阅读 [P1-A 报告](p1-a-content-report-2026-10-19.md)、[P1-B 报告](p1-b-foundation-report-2026-10-19.md)、[总回执](p1-foundation-2026-10-19.md)，并独立检查实现；下文问题不是对原 18 项清单的重复计数。
- Standards（实现约束与存档可靠性）和 Spec（计划符合性与 Lua 对照）分别检查；最终探针由主验收进程重新执行。
- 新输出：[完整复验命令输出](p1-acceptance-2026-10-19/verify.txt)、[边界探针原始输出](p1-acceptance-2026-10-19/probes.txt)。原 `p0-layout.json` 和 `p1-verify.txt` 已恢复验收前内容，避免把新运行结果冒充原交付证据。

| 本次重新执行 | 结果 | 结论边界 |
|---|---|---|
| `python godot/tools/verify.py --suite foundation` | exit 0，2113 项断言；双进程恢复通过 | 已有 P1 套件通过 |
| `python godot/tools/verify.py --suite all` | exit 0，2676 项断言；双进程恢复通过 | 包含 P0 自动回归；不重复宣称双端人工验收 |
| 内容与 oracle 的 `--check` | 均通过 | 当前正式导出与 Lua 相符，不证明所有非法输入被拒绝 |
| A/B、版本、恢复缓存探针 | 运行完成，复现 S01～S04 | 测试 IO 适配器，不是物理断电实测 |
| 内容负例与 Lua/Godot 残留采样探针 | 运行完成，复现 F01～F02 | 探针 exit 0 表示执行结束，输出记录的是缺陷，不能计为验收通过 |

## Standards：实现约束与存档可靠性

### S01 / 高：从旧侧恢复后，下次保存可能破坏唯一可用备份

位置：[snapshot_store.gd:120](../../src/persistence/snapshot_store.gd#L120)～129。

依据：方案 §7.2 要求“写非活动快照”，写入明确失败不得破坏已提交进度；Task 3 要覆盖短写、最新代损坏与新进程恢复。

复现：先提交 A/gen1、B/gen2；破坏 B 快照；`load_latest()` 成功回退 A/gen1。随后提交新状态并模拟 `state_a.json` 短写。

```text
FALLBACK_BEFORE status=loaded generation=1 side=a recovered_from=b
FALLBACK_SAVE status=failed SAVE_WRITE_FAILED state_a.json
FALLBACK_AFTER status=corrupt
```

原因：`commit()` 仍按最高的 B marker 选择 A 写入，没有依据实际通过验证并恢复的 A 快照选择非活动侧。B 已坏，A 被截断后没有任何完整快照。

修复与复验：写入目标必须保留当前唯一有效提交；在 A/B 对称情况、打开失败、部分写入和读回失败下验证旧进度仍可加载。故障用例必须真的改坏目标字节，不能只返回 false 而保留旧文件。

### S02 / 高：未来版本存档被当作损坏并静默回退

位置：[snapshot_store.gd:189](../../src/persistence/snapshot_store.gd#L189)～200；识别版本的代码在 [save_codec.gd:61](../../src/persistence/save_codec.gd#L61)。

依据：方案 §7.2 要求坏档、版本不兼容与更新迁移分别提示；P1 存档必须识别版本并保留原档。

复现：保留 A/gen1；将 B/gen2 改为 `schema_version=2`，同时重算合法的外层长度与 hash，B 不是截断文件。`SaveCodec` 能返回 `SAVE_UNSUPPORTED`，但 `load_latest()` 将其与损坏混为一类并回退 A。

```text
FUTURE_LOAD status=loaded generation=1 recovered_from=b
FUTURE_SESSION_LOAD status=loaded revision=1
```

影响：旧程序把较新存档静默解释成旧进度，并允许继续保存；版本保护失效。

修复与复验：区分内容损坏、读失败、格式/版本不支持；遇到完整的未来版本提交时保留现场并锁写，不以旧快照恢复成功掩盖版本问题。覆盖有/无旧侧两种情况。

### S03 / 高：一侧提交标记短写，完整的另一侧也无法恢复

位置：[snapshot_store.gd:99](../../src/persistence/snapshot_store.gd#L99)～104。

依据：方案 §7.2 要求按最高有效已提交代恢复；Task 3 要覆盖提交记录写入故障、最新代损坏。

复现：A/gen1 的 marker、快照均完整；B marker 截断为 `tthw-godot|2|b|`。加载直接返回：

```text
TRUNCATED_MARKER status=corrupt SAVE_CORRUPT state_b.commit
```

原因：`_current_marker()` 只要一侧 marker 解析失败就提前返回，尚未验证另一侧完整提交。现有“最新快照坏了可以回退”测试没有覆盖 marker 本身短写。

修复与复验：独立检查两侧的标记与对应快照，恢复可判定的有效提交并记录回退原因；两侧都不可判定时保持锁定。需同时覆盖 A/B 标记短写、缺失、读失败，明确各错误的恢复策略。

### S04 / 中：同槽重读成功后，同一请求仍永久返回不确定

位置：[session_service.gd:91](../../src/domain/session_service.gd#L91)～92、136～142、154～155。

依据：方案 §7.2、Task 3 的提交不确定锁定与同槽重读恢复契约。

复现：marker 实际写成，但第一次读回失败；执行返回 uncertain 并锁定。介质恢复后 `reload()` 成功，状态已是 revision1，重试原请求却仍命中旧缓存。

```text
UNCERTAIN_EXEC SAVE_COMMIT_UNCERTAIN
UNCERTAIN_RELOAD ok=true revision=1
UNCERTAIN_RETRY SAVE_COMMIT_UNCERTAIN locked=false actual_revision=1
```

影响：恢复结果与命令返回互相矛盾，调用方可陷入反复要求重读的流程。并未观察到该探针重复扣资源，不能将其表述为已发生重复结算。

修复与复验：恢复时对该请求进行对账并纠正结果；不能把 uncertain 作为永不过期的最终缓存。覆盖 marker 最终已提交和最终未提交两条路径，验证响应、锁、revision 和状态一致。

Standards 合计：4 项；本轴最严重的是 S01 的唯一有效备份丢失风险。未以命名、文件长度等代码风格偏好阻断验收。

## Spec：计划符合性与 Lua 对照

### F01 / 中：内容负例门禁未闭环，部分非法类型也被导出校验放过

位置：[content_catalog.gd:42](../../src/content/content_catalog.gd#L42)～90；[export_content.py:325](../../tools/export_content.py#L325)～329、408～413。

依据：Task 2 已勾选“添加重复 ID、缺失引用、未知条件枚举和错误空表用例，要求导出/加载失败并指向字段路径”；方案 §5.1 要求明确数组/字典类型并校验引用与枚举。

分别注入以下错误，Godot `load_data()` 均返回 `ok=true`：

- `collections.words[0].attributeProfileId = "missing_profile"`；
- `collections.directRules[0].when[0].op = "unknown_operator"`；
- `collections.ingredients[0].addTags = []`（应为对象）。

Python `validate_catalog()` 对 `addTags=[]`、`unless={}`、`forbiddenEffects={}` 也均返回 `errors=[]`。其中 `or {}` / `or []` 吞掉了空容器类型差异；当前 `content_schema.json` 主要是空 Lua 表转换声明，不是完整的字段类型校验。

修复与复验：让导出和加载边界落实声明的类型、引用与枚举契约；为以上负例加入自动测试并断言字段路径。当前正式 catalog 的 `--check` 是通过的，本问题不表示已有正式内容丢失或被改写。

### F02 / 中：残留药效采样改变了 Lua 的严格时间语义

位置：[potion.gd:523](../../src/domain/potion.gd#L523)、[potion.gd:651](../../src/domain/potion.gd#L651)；对照 `scripts/systems/Potion.lua:245,306`。

依据：方案 §5.3 与 Task 3 要求基础计算、非法输入、错误码和阈值边界与 Lua 一致，不能用宽容比较掩盖语义不同。

正式 `word_candidate_elias_sleep`、初始设备、无辅词与原料的配方，声明的首个 sleep 残留点为 10 小时。实测：

| 操作 | Lua | Godot |
|---|---|---|
| 采样 `10.000001` 小时 | `CONFIG_MISSING/residuals.sleep` | `ok=true, value=0.6` |
| 将第一个残留点改为 `10.000001`，校验结果 | `INVALID_REQUEST/potion.residuals` | `ok=true` |

原因是 `is_equal_approx` 把未声明时刻当作已声明点，也允许不连续的残留点通过。现有 oracle 对比了计算产出的残留数组，但 `test_potion.gd` 没有调用 `sample_residual`，不能证明公开采样 API 的行为一致。这也不是报告所声明的逐字段 `1e-9` 对照容差。

修复与复验：按原 Lua 复现采样与校验语义；补每个已声明点、点两侧、区间内未声明时刻、首点前与末点后、残留点被修改的对照用例。不能只放宽预期使测试通过。

Spec 合计：2 项；本轴最直接的业务差异是 F02。F01 属于已勾选的负例验收尚未落实。

## 证据口径更正（不另计阻断项）

P1-A 报告称 22 封信的标题/正文逐封 SHA256 比对，实际 [export_content.py:628](../../tools/export_content.py#L628)～630 跳过非订单信，`content_checks.json.text_hashes` 只有 **11 封**。

全 catalog 的 `--check` 仍覆盖所有导出文本，因此没有证据表明另外 11 封内容遗失。应补齐 22 封的逐封哈希检查，或将原报告准确改成“11 封订单信逐封哈希 + 22 封全量 catalog 对照”。P1-B 的 `SampleResidual` 对照通过声明也应同步更正，直至 F02 的专项测试通过。

## 原有 18 条问题的处置

| 原编号 | 本次判定 |
|---|---|
| P1-A-01 | 愿望装饰 Godot 资源未齐：允许列为 P4/P5 前置，不以 P1 无 UI 为缺陷 |
| P1-A-02 | 显式声明空表类型的原则正确；“负例失败保护完整”尚未成立，见 F01 |
| P1-A-03 | Lua 为权威、需重新导出：维护约束；本次两个 `--check` 通过 |
| P1-A-04 | 复用 Lua 解析剪词跨度：允许的转换策略；P2 仍须验正文与位置绑定 |
| P1-A-05 | 旧 PaperConsistency 失败：旧工程问题，独立归档；不能将旧整套回归写成通过，不要求为迁移修改只读基线 |
| P1-A-06 | catalog 真机加载耗时：P5 设备测量项 |
| P1-B-01 | 逐字段容差不能替代公开 API 语义对照；F02 修复前不接受“残留采样通过” |
| P1-B-02 | 顶层 draft 是 P1 过渡结构；P2 必须定义升级或明确测试档处理，不静默丢弃 |
| P1-B-03 | 正式信件/订单尚未接入属于阶段边界；新手引导已明确纳入 P2 |
| P1-B-04 | 非空信件/订单等深校验是 P2 前置；不将尚未接正式状态本身重复记为 P1 缺陷 |
| P1-B-05 | P1 未接 UI、无新双端包：符合本阶段范围，不独立阻断 |
| P1-B-06 | 物理断电未验可保留边界；但适配器已能复现 S01/S03，不能把这两项推迟到设备优化 |
| P1-B-07 | 内存缓存无上限可在 P5 优化；恢复后的错误缓存是 S04 的正确性问题，应先修 |
| P1-B-08 | all 会重写 P0 证据：已确认工具行为，本次保留新输出并恢复原证据；建议后续改为独立输出路径 |
| P1-B-09 | 字符长度在当前写读内部一致：暂不阻断；外部格式变更需版本化 |
| P1-B-10 | 真机保存位置/提示/恢复：P2 及设备阶段必验，不用桌面无头代替 |
| P1-B-11 | SettingsStore 专项测试：应在声音/设置接入前完成，不阻断未使用设置的 P1 |
| P1-B-12 | 大历史深复制性能：P5 用真实会话测量 |

跨会话重建后，同一已提交 `request_id` 目前返回 `STALE_REVISION`，不能恢复原成功响应。当前切词还具有来源幂等，因此不把它另计为已发生重复消耗；**P2 接发货等正式结算前必须补持久事务记录与跨进程请求重放对照**，不能只给内存缓存加淘汰策略。

## 复验与下一阶段门禁

1. 修复 S01～S04、F01～F02，把本次隔离探针固化为相关正式套件的回归用例；更正报告中的实际覆盖范围。
2. 重跑 `export_content.py --check`、`export_oracle.py --check`、`verify.py --suite foundation`、`verify.py --suite all`；保留新结果和双进程恢复证据。复验时确认新用例确实执行，断言总数变化本身不是完成证明。
3. 满足“保存明确失败仍有原有效提交可恢复；不确定结果可正确对账；未来版本不静默降级；内容负例拒绝且定位；残留 API 与 Lua 一致”后，再放行 P1。
4. 放行后的下一步是 **P2 / Task 4：真实埃利亚斯首单闭环与新手引导**。先建立 Lua 成功/失败/重置/重复确认轨迹，再接打捞、收信、剪词、草稿、试做、确认发货、记录书和步骤恢复；同步处理 draft 升级、正式状态深校验与跨进程幂等，最后交付双端 debug 包验收。

## 复现材料

探针已归档为文本，避免被误计为正式测试或自动导入脚本。将 `.txt` 副本还原到 `godot/build/` 对应文件名后，在仓库根目录执行；仅使用隔离 IO 或只读 Lua 配方计算。

- [存档与恢复探针](p1-acceptance-2026-10-19/p1_standards_probe.gd.txt)
- [Godot 内容与残留探针](p1-acceptance-2026-10-19/spec_probe.gd.txt)
- [Lua 残留对照](p1-acceptance-2026-10-19/spec_probe_lua.py.txt)
- [Python 导出类型负例](p1-acceptance-2026-10-19/spec_probe_schema.py.txt)

```powershell
& "$env:USERPROFILE/.codex/tools/godot/4.7.2-stable/editor/Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://build/p1_standards_probe.gd
& "$env:USERPROFILE/.codex/tools/godot/4.7.2-stable/editor/Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://build/spec_probe.gd
python godot/build/spec_probe_lua.py
python godot/build/spec_probe_schema.py
```
