# 3D 接口映射 · schema 3

版本 `D3-LAB-20261012-r3-v01`。以正式工程当前工作树的接口手册顶部 schema 3 增量、`GameSession`、`PlayModel`、`PlayQueries`、`Panels`、`LayoutManifest` 核对。源文件逐一哈希见 evidence；不以历史 schema 2 或旧 Git HEAD 替代当前业务。

## 进程与存储

`scripts/main.lua → lab.Bootstrap.New()` 只建立一套真实 `GameSession.New(content,{saveSystem=SaveSystem.New(storage),targetSchema=3})` 和 `PlayModel.New(session,content)`。唯一 slot 为 `d3_lab_r3`。`MemoryStorage` 只允许该 slot 的五个 SaveSystem 文件名，全部保存在 Lua table，无磁盘回退。

新进程从真实默认状态开始；不自动收信、不虚构余额商品、不发调试奖励。测试准备只用真实 Buy/Receive/Read/Cut。测试中 `File`、`fileSystem` 是拒绝磁盘访问的哨兵；`cjson` 是 Lua/Python JSON 适配，业务代码保持原样。`model.Reload()` 仅证明同一内存对象内 SaveSystem 重读，未证明跨进程恢复。关闭或刷新预览会丢失试验进度。

## 输入及物件映射

UI 实际命中 → 底层 `sceneInput.onClick` → 相机 `GetScreenRay` → 独立代理盒 + 遮挡判定 → `Interaction` → 镜头或真实模型 → 真实结果刷新 UI。固定 ID 沿用当前 LayoutManifest。

| 物件/动作 | 真实查询/命令 | 实现状态与副作用 |
|---|---|---|
| `home.net` 捞网 | `rig.Go("Seaside")` | 仅导航；穿门到同一码头，不 Receive |
| 门洞 | 无点击 ID | 仅真实几何通道，无新增门外入口 |
| 码头“捕捞来信” | `GetSalvageView()`，按钮确认后 `model.Receive(availableLetterIds[1])` | 按当前查询准备可收信；成功由真实命令扣一次；打开面板不扣 |
| `home.merchantShip` | `GetShopView()` → 原 Panels.Shop → `model.Buy(ingredientId)` | 同一船体、真实余额/价格/库存、真实失败反馈 |
| `home.letterPaper` | `GetLetters()` → 单封直接 `model.Read(letterInstanceId)`，多封先选列表 | 显示真实正文、委托要求；不自动 Receive |
| `home.drawer` | `GetLetters()` → 原 Panels.Letters → `model.Read(...)` | 只开列表，不恢复抽屉连续动画 |
| 阅读剪词按钮 | `model.Cut(spanId)` | 原 Panels.Reader；已剪位置禁用，重开保留剪口，更新同一文本控件 |
| `home.stove` | `rig.Go("Brew")` | 仅靠近同一桌面，不 Preview、不投料、不结算 |
| 返回药铺 | `rig.Go("Home")`，`model.ReturnHome()` | 后者只改表现页和 dirty；无状态保存副作用 |
| 词卡面板 | `GetWordTray()` | 只读；本轮未接拖放操作 |

模态、HUD、滚动与镜头过渡由 UI 层先接收输入；`Interaction` 另有 busy/panel/dragging 守卫。关闭模态只改状态，原 blocker 保留至下一次 Update，避免当前事件穿透。物件外观与 AABB 触控代理分离。结构盒遮挡加 native Octree 三角射线检查；离线只验证数学遮挡及 native veto 接线，真实引擎遮挡仍待验收。

## 后续接入点（本轮只映射）

| 后续操作 | 接口与前提 | 当前保留位置 |
|---|---|---|
| 投词 | 锅口有效命中后 `model.Drop("word", tokenId)` | `world.rim` 位于 `{1.8,1.94,1.45}`，半径 0.37m；`CanDropAt` 只认独立圆形锅口，不认整个炉身 |
| 投原料/特殊物 | `model.Drop(kind,id)`，kind 按当前 PlayModel 分派 | 继续沿用原库存与失败结果；未制作拖拽 |
| 熬制 | `model.Preview()` | 原 PlayModel/配方系统；Brew 镜头进入不触发 |
| 重置 | `model.Resolve(false)` | 原事务规则，不以动画修改库存 |
| 发货 | `model.Resolve(true)` | 必须由有效预览/订单状态进入；本轮不自动承接订单 |

试验副本的 `Panels.Reader` 唯一业务面板改动是在剪词区之后 `if ctx.labMinimal then return end`，隐藏后续接单/炼药控件；正式 AppView 与 Panels 未修改。核心、系统、数据和 PlayModel 仍与源快照相同。

## 可核对结果与限制

离线检查证实：初始余额 30；海盐价格 5，购买真实扣 5；未知 ID、库存耗尽、余额不足均失败且快照/写次数不变。`letter_pa_01` 通过真实 Receive 收取；首次 `body:1` 产生一张卡，再剪同位置返回 `changed=false`，卡 ID 相同且不写存储；重开和同内存重载保留剪口。全部 70 项及返回 JSON 见 `docs/evidence/3d-lab-r3/offline-checks.json`。

2026-10-12 原生增量：真实商店按钮购买、三种失败原子性、明确Receive、Read、Cut/重复剪/重开已在实际Runtime程序驱动验证并保存截图。重复剪的PASS断言头完整，其较长结果中的业务tokenId触发Maker脱敏截断，未恢复被遮蔽字段。三比例各31项原生检查完成，包含native拾取、墙体遮挡守卫、三镜头往返和长文滚到底。详见NATIVE_ACCEPTANCE及aspect-*-official/summary。关闭QA后普通入口两个5秒窗口保持Home、memoryWrites=0。

这是程序调用真实适配层及UI回调，不等于人工点击、完整UI事件分发或手机触控验收。人手滚动手感/触控命中面积、复杂遮挡边缘、手机性能与跨进程存档仍未验证。场景/面板成功表现只跟随真实命令结果，默认QA开关已关闭。
