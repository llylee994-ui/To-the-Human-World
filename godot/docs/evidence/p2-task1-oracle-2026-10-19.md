# P2 Task 1 首单 Lua 轨迹冻结回执（2026-10-19）

状态：**完成（首单轨迹与 oracle 测试基础）；Godot 业务重放从 Task 4 开始，当前不宣称 P2 可玩。**

- 基线：`0885ddb08e057e7bd2ef6cc49afa838ae7679eec`；P1 已由 [R01 独立复验](p1-r01-reverify-2026-10-19.md) 放行。
- 执行方式：当前会话串行，未使用子代理；未改动 `scripts/`、`assets/`、Maker 存档。

## 1. 冻结内容

`godot/tools/export_first_order_oracle.py` 通过 Lupa 运行原 Lua 生产会话（`B5Fixtures` 隔离文件介质 + 真实 `GameSession/GameState/OrderTrial`），导出：

- `godot/tests/fixtures/first_order/traces.json`
- `godot/tests/fixtures/first_order/manifest.json`

源哈希覆盖 `scripts/core`、`scripts/systems`、`scripts/data` 及首单夹具共 **60 个文件**：

`d24f4bdc5715218f4f3604a04d023e67976321eef15f9e58b3010bc79d11800f`

共 8 条登记配方、6 条失败/边界轨迹。每条配方 20 个真实步骤：

```text
receive, read, cut:body:1..9, accept, draft, trial, reset,
draft_after_reset, retrial, confirm, duplicate_confirm, reload
```

每个步骤保存：

- 实际 Result；
- 完整业务快照（`live/currentOrder/journal/chapter` 等）；
- 写入次数；
- 事件名列表。

8 条配方最终均为 `deliveredOrders=1`、金币 130（初始 30 + 首单报酬 100）；评分分布为 3/3/2/1/3/3/3/2。

失败/边界轨迹：

| 用例 | 真实结果 |
|---|---|
| empty_main | `INVALID_REQUEST` |
| main_effect_insufficient | `ok=true`，`requirementResult.canShip=false`，不产生 pending |
| duplicate_cut | `ok=true`，`changed=false` |
| stale_transaction | `STALE_TRANSACTION` |
| pending_change | `ORDER_LOCKED` |
| pending_cut | `ORDER_LOCKED` |

## 2. 对照工具与负例

- `--check` 比对 `traces.json`、`manifest.json` 的全部字节；缺夹具或内容陈旧会失败。
- `godot/tools/test_first_order_oracle.py` 验证：
  - 合法 bundle 通过；
  - 缺步骤失败；
  - 非法 recipe ID 失败；
  - source hash 变化失败；
  - 缺 source inventory 失败。
- `godot/tests/parity/test_first_order_oracle.gd` 检查 manifest/traces 版本、源哈希、60 个源文件、8 条必需配方、每条步骤与快照形状、最终发货数和 6 条失败轨迹。

## 3. 执行结果

```text
python godot/tools/export_first_order_oracle.py
first-order oracle written: godot/tests/fixtures/first_order
recipes=8 failures=6 source_hash=d24f4bdc5715218f...

python godot/tools/export_first_order_oracle.py --check
first-order oracle check passed: godot/tests/fixtures/first_order

python godot/tools/test_first_order_oracle.py
[FirstOrderNegative] PASS valid bundle
[FirstOrderNegative] PASS missing steps
[FirstOrderNegative] PASS invalid recipe id
[FirstOrderNegative] PASS source hash changed
[FirstOrderNegative] PASS missing source inventory
[FirstOrderNegative] PASS 4 negative cases

python godot/tools/verify.py --suite p2-oracle
[GODOT] PASS suite=p2-oracle assertions=1512
```

`p2-oracle` 已注册到 `run_tests.gd`；`verify.py` 的 p2-oracle/all 会在 Godot 测试前执行 `--check` 和 Python 负例。输出见 [p2-verify.txt](p2-verify.txt)。

## 4. 已知边界

- `traces.json` 约 4.4MB，包含逐步完整快照；这是 Task 4 逐字段对照的输入，不是运行时资源。
- 当前只验证了 fixture 结构与 Lua 源哈希，没有 Godot 命令重放；Task 4 才比较业务状态。
- Task 2 的 P2 专用初态/账本/P1 存档检查尚未实现。
- 未运行 P0/P1 全量套件之外的新 P2 业务套件；`p2-oracle` 不证明首单可玩。
