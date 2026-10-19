# P2 Task 2 正式状态与跨进程幂等回执（2026-10-19）

状态：**Task 2 完成（P2 初态、独立槽、持久命令账本、start_journey 与双进程重放）；Task 3 尚未开始，当前不宣称首单可玩。**

- 代码基线：`d5355bc`（Task 1 提交）。
- P1 放行：`p1-r01-reverify-2026-10-19.md`。
- 本批只实现 P2 状态边界与 `start_journey`，没有开放收信、裁词、订单或 UI。

## 1. P2 状态与独立槽

- `P2State.initial` 在 P1 初态上移除顶层 `draft`，增加 `payload_version=2`、`commandLedger.byRequestId={}`、`chapter.started=false`，可带 `onboarding` 初态。
- `StateAudit` 校验 P2 顶层字段、`payload_version=2`、`commandLedger`、`chapter.started`；live/economy/world/tokens 继续复用 P1 验证。
- P2 目前只允许 `currentOrder=false`；accepted/pending 在 Task 4 实现，当前返回可定位错误。
- `P2Fixture` 使用独立目录 `user://godot_save_p2_<name>`；`open` 只清理该测试槽，`resume` 不清理。
- `project.godot` 用户目录改为 `ToTheHumanWorld-Godot-P2`；P1/P0 原包与存档不迁移、不覆盖。
- `inspect_p1_save.py` 只读检查 P1 双快照/legacy 文件，输出 schema、revision、来源 token、顶层/订单草稿和保存现状；不写文件。

## 2. 命令账本

`CommandLedger`：

- `fingerprint` 绑定 `command + 规范化 payload` 的 SHA-256。
- `lookup` 返回 `missing`、`matched`（原响应）或 `conflict`（`REQUEST_ID_CONFLICT`）。
- `install` 把 `{fingerprint,response}` 写进候选状态的 `commandLedger.byRequestId`；响应必须是可持久化 JSON 值。
- 账本随业务候选同一次 A/B 提交落盘，不另写第二个账本文件。
- P2 `execute` 先查账本再查会话内缓存；同 ID 换命令/payload 返回冲突。
- 同 ID 重放不增加 revision 或 generation、不再派发事件。
- 明确保存失败不写入账本、不安装候选；同一 ID 可在故障恢复后安全重试。
- uncertain 重读优先按账本对账，而不是只比较 revision。

`start_journey`：

- 空 payload。
- 未开始时设置 `chapter.started=true`、revision +1，提交成功后才安装。
- 已开始时返回 `changed=false`，但仍记录请求账本。

## 3. 测试结果

```text
python godot/tools/verify.py --suite p2-state
[GODOT] PASS suite=p2-state assertions=38
[Restart] PASS P2 cross-process committed request replay

python godot/tools/verify.py --suite foundation
[GODOT] PASS suite=foundation assertions=2251

python godot/tools/verify.py --suite all
[GODOT] PASS suite=all assertions=4364
```

覆盖：

- P2 初态合法；未知 payload_version、accepted/pending 空壳、伪造来源词和不可持久化 ledger response 均被拒绝并给出路径。
- `start_journey` 首次提交 revision 1；同会话重放响应一致且快照不变。
- 同 ID 换 payload 返回 `REQUEST_ID_CONFLICT`，状态不变。
- 新会话读取同一槽，账本重放原响应，不增加 generation。
- 双进程：seed 进程提交 `start_journey`，verify 进程重启后重放同一 request_id，revision/generation 不变。
- 保存写失败不安装候选或账本；同一 request_id 在故障清除后重试成功。
- 原有 P1 foundation 2251 与 full `all` 回归仍通过。

## 4. 已知边界

- `currentOrder` 只支持 false；Task 3 实现 letters/receive/read/cut，Task 4 实现 accepted/pending 与试做/发货。
- `start_journey` 只改变章节开始状态，不创建首信或订单。
- 未接 P2 UI；P0 场景仍使用演示绑定。
- P1 原测试档未被读取或迁移；`inspect_p1_save.py` 仅提供只读报告。
- 真实双端包、手机触控和听感未验。
