# P1 第二次独立验收（2026-10-19）

**结论：暂不放行 P1。上轮 6 项问题的对应复现已通过，但本轮发现 1 项仍会丢失已提交进度的存档恢复问题。**

本轮由主验收代理独立完成，没有使用子代理。只检查、运行隔离测试并记录问题；没有修改生产代码、启动 P2、操作玩家存档或重新构建双端包。

## 基线与重新执行结果

- 验收 HEAD：`2800a6d`；重点检查修复提交 `6910254` 和报告更正提交 `2800a6d`。
- 对照：[上轮独立验收](p1-acceptance-2026-10-19.md)、[修复回执](p1-fix-2026-10-19.md)、完整方案 §7.2 与实施计划 Task 3 的存档/恢复门禁。
- 原 `p0-layout.json`、`p1-verify.txt` 保留验收前字节；本轮证据单独保存。

| 检查 | 本次结果 |
|---|---|
| `verify.py --suite foundation` | exit 0，2235 项断言，双进程恢复通过 |
| `verify.py --suite all` | exit 0，2798 项断言，双进程恢复通过 |
| 内容与 oracle `--check` | 均通过，包含在上述命令中 |
| Python 内容负例 | 5 个通过，包含在上述命令中 |
| 上轮原始探针 | 原对应失败不再复现，见下表 |
| A/B 对称实际部分写入探针 | 两侧均保留原有效快照字节并成功恢复 |
| 新增暂时读失败探针 | **复现 R01：旧状态被安装，后续提交遗漏已保存词条** |
| 信件哈希覆盖 | `content_checks.json.text_hashes` 已为 22 封 |

完整输出：[foundation](p1-reacceptance-2026-10-19/verify-foundation.txt)、[all](p1-reacceptance-2026-10-19/verify-all.txt)、[探针原始输出](p1-reacceptance-2026-10-19/probes.txt)。探针 exit 0 仅表示运行结束，不表示它输出的问题已解决。

## 上轮 6 项的复验

| 编号 | 本次核对 | 判定 |
|---|---|---|
| S01 唯一有效备份被覆盖 | 当前写入有效侧的对侧；另用实际截断目标字节的探针，分别验证 A/B 为唯一有效侧时旧字节不变、可恢复 | 原问题修复确认 |
| S02 未来 schema 静默降级 | 原始探针返回 `unsupported/SAVE_UNSUPPORTED`；SessionService 拒绝加载；正式套件覆盖有旧侧和仅未来侧 | 原问题修复确认 |
| S03 单侧 marker 损坏阻断另一侧 | 原截断 marker 探针成功加载另一侧；正式套件区分 marker 缺失、截断和无法读取 | 原问题修复确认；快照读取失败另见 R01 |
| S04 不确定请求缓存无法纠正 | marker 已提交后重读，同请求返回成功且解锁；正式套件也覆盖未提交后允许重试 | 原对应复现通过 |
| F01 内容负例门禁 | 原未知 profile、未知 op、错误 addTags 类型均被 Godot 拒绝；Python 也拒绝三类空容器错误且输出字段路径 | 原问题修复确认 |
| F02 残留时间语义不同 | `10.000001` 采样返回与 Lua 相同的 `CONFIG_MISSING/residuals.sleep`；修改残留点被拒绝；新增 18 个采样 oracle 已执行 | 原问题修复确认 |

22 封信逐封标题/正文哈希已补齐，之前的证据口径问题也已纠正。跨进程 request_id 持久重放仍为已知 P2 前置，不在本轮重复计作新问题。

## R01 / 高：最新快照暂时读失败，会静默安装旧进度并允许覆盖提交

位置：[snapshot_store.gd:165](../../src/persistence/snapshot_store.gd#L165)～198、202～203；关联 [session_service.gd:93](../../src/domain/session_service.gd#L93)～104。

依据：方案 §7.2 要区分读取/损坏/版本问题，保护已提交状态；Task 3 要求保存故障、提交结果不确定和同槽恢复可靠。暂时读取不到一份已提交快照，不能证明其内容损坏或授权丢弃其中进度。

### 复现（真实 P1 命令 + 隔离 IO，不改任何存档字节）

1. 新会话连续执行两次不同来源的 `cut_word`，两次都成功：A/gen1/revision1 含词条 1，B/gen2/revision2 含词条 1、2。
2. 仅让 IO 对 `state_b.json` 返回临时 read failure；marker 仍可读取，B 文件字节完全没有变化。
3. 新建会话并加载。实际返回 `ok=true, revision=1, generation=1, recovery_locked=false`；词条 2 已不在内存状态，返回的 `recovered_from` 还是空字符串。
4. 清除 IO 故障。直接读取存档可再次得到完整 B/gen2/revision2，确认词条 2 仍在且原文件并未损坏。
5. 在步骤 3 的会话执行第三次不同来源切词，`expected_revision=1`。命令成功，提交 A/gen3/revision2，内容只有词条 1、3。再新建会话，最高代中已经没有之前成功提交的词条 2。

关键输出：

```text
NEWEST_SNAPSHOT_READ_FAILED
  open.ok=true revision=1 generation=1 locked=false second_token_present=false

LATEST_SNAPSHOT_READABLE_AGAIN
  generation=2 revision=2 second_token_present=true

AFTER_READ_RECOVERS_AND_NEW_COMMAND
  third_command=true generation=3 revision=2 second_committed_token_preserved=false
```

当前旧 B 快照还保留原词条，故不能称为所有备份已被永久擦除；但正式加载选择的新最高代已经丢失成功提交的业务结果，继续保存还可能覆盖剩余备份。

### 原因

`_inspect_side()` 已正确区分 `snapshot_read_failed`，但 `_select_valid()` 在有任意可读有效侧时，先进入 `valid` 分支返回 `loaded`，把无法读取的更高代放入 `ignored`。处理 `snapshot_read_failed` 的分支位于此返回之后，只有完全没有有效侧才触发。

SessionService 随后安装旧状态、解除锁定，也没有透传新格式的 `ignored` 诊断。下一次提交虽然重新看到了更高代，但并未验证调用方候选状态仍基于那一代，于是把旧候选状态写成了新最高代。

### 修复与复验要求

- 至少对 marker 已知为更新（或相同）代、但快照读取失败的情况返回 `read_failed` 并锁定；不要沿用损坏快照的自动回退策略。
- 若允许忽略旧代快照的读失败，应根据已读取 marker 的代数明确区分，保留诊断。更高代不可判定时不能放行业务写入。
- 故障消失后，同槽重读必须恢复原最新 revision 与全部已提交词条，再允许后续命令。
- 将本次用例加入正式故障套件，覆盖 A/B 对称情况；验证读失败期间命令被拒绝且磁盘字节不变、读恢复后词条 2 仍在、之后词条 3 能正常追加而不是替代词条 2。

本轮只记录，不自动修复。

## 下一步

先修复 **R01** 并运行新增回归及 foundation/all、双进程恢复。该问题解决后再判断 P1 放行；随后才进入 **P2 / Task 4：真实埃利亚斯首单闭环与新手引导**。

P2 仍需在正式发货前落实持久事务幂等、draft 升级、真实信件/订单深校验及各中间阶段重启恢复。无需把 P4/P5 的装饰资源、听感和性能任务提前混入本次修复。

## 新增探针

[review_probe.gd 文本副本](p1-reacceptance-2026-10-19/review_probe.gd.txt)。复制为 `godot/build/p1-reacceptance/review_probe.gd` 后在仓库根目录运行：

```powershell
& "$env:USERPROFILE/.codex/tools/godot/4.7.2-stable/editor/Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://build/p1-reacceptance/review_probe.gd
```

上轮四个探针仍使用原归档文本，本次没有修改它们的输入和判断以迎合修复结果。
