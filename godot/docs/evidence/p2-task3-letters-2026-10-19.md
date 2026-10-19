# P2 Task 3 打捞、真实信件与裁词回执（2026-10-19）

状态：**Task 3 完成（真实首信收到/已读/逐 span 裁词、每日次数与四个重启状态）；订单/试做/后果/发货仍为 Task 4，当前不宣称首单可玩。**

- 基线：Task 2 提交 `97ee08c`。
- 本批未改动 Lua 源、P1 存档或 Maker 绑定。

## 1. 实现范围

- `Letter`：定义解析、实例校验、`receive_letter`、`read_letter`、`cut_word`。
  - 收信从 `DayFlow` 资格取信，不能由 UI 任意指定未开放信件。
  - 读信保存真实已读；重复读幂等。
  - 裁词 payload 只接受 `{letterInstanceId, spanId}`；source 的 wordId/sender/span 全部由已读信定义推导，不接受 UI 自报。
- `DayFlow`：P2 只开放 `release.requiredOrderIds[0]`（`letter_pa_01`），按 `appearCondition.dayMin` 和是否已收判断；每日次数来自 catalog `salvageDailyLimit`。
- 收信成功提交后才消耗当日次数；保存明确失败不安装信件、不扣次数，同一 request_id 可在恢复后重试。
- 内容导出补充 `Letter.ParseDefinition` 的有序 `segments`；阅读页可以按文本/词段顺序渲染，不再用全局替换重建。
- `QueryService` 增加 `salvage`、`letters`、`letter`；`word_tray` 在 P2 读取 `currentOrder.draft`（Task 4 接入前为空）。
- `StateAudit` 对信件实例做深校验：实例 ID、寄信人、已读、cutSpans、附件归属和 bottleQueue。

## 2. 对照与门禁

| 场景 | 结果 |
|---|---|
| 未开始旅程就收信 | `JOURNEY_NOT_STARTED` |
| 未收到先读/剪 | `LETTER_NOT_RECEIVED` |
| 未读先剪 | `LETTER_NOT_READ` |
| 未知剪词位置 | `UNKNOWN_ID/spanId` |
| 重复收信（同信新 request id） | `LETTER_NOT_AVAILABLE`，不再消耗次数 |
| 重复读信/剪词 | `changed=false`，不新增 token |
| 保存失败后重试同 request_id | 不安装信件、次数为 0；恢复后成功且只消耗一次 |
| 九个词段 | 九个独立 token，来源 span 不合并 |
| 重启四状态 | 未读、已读未剪、部分裁词、全部裁词均恢复 read、token 数和捕捞次数 |

## 3. 测试结果

```text
python godot/tools/verify.py --suite p2-letters
[GODOT] PASS suite=p2-letters assertions=67

python godot/tools/verify.py --suite all
[GODOT] PASS suite=all assertions=4431
```

`all` 包含 P1 foundation、p2-oracle、p2-state、p2-letters 和双进程恢复。内容 catalog 已重新导出并带 `letterSpans.segments`；`export_content.py --check` 通过。

## 4. 已知边界

- 只开放 `letter_pa_01`；其余订单和日程在 P3。
- 尚未实现接单/草稿/试做/发货；`currentOrder` 仍只支持 `false`。
- 附件领取、直接回信归档未接；Task 4 处理订单后续。
- 打捞演出、阅读/托盘 UI 属于 Task 5；本批只验证业务状态。
- 真机画面与触控未验。
