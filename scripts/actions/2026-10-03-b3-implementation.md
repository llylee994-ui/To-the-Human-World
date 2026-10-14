# B3 炼药与字面判定实施记录

## 状态与背景

Completed（B3 程序纯计算与隔离验证；不代表整单闭环或正式验收）。用户要求执行 [复核与下一批交接](2026-10-03-b2-review-and-publish.md) 的本机 B3 分工。基线 fengyycon@6820d25，开工时工作区仅原有未跟踪 docs/actions；origin 实际为 GitHub。B2 已提交，本批增量实现 B3。原文件保留，未提交、推送或远端构建；data/docs 未改，上一轮两行类型注释授权未扩展到本轮内容修改。

本批只实现 Potion 八步、Order 配方解析及 Evaluate 纯判定。正式入口保持 v1，人物后果/回信/星级归 B4，整单确认/重置归 B5。先完整读取 Lua 指南，沿用本会话已读的 API 示例 14/15/17；核对 B0、模块设计、C2 及真实 WordToken/Economy 公共接口。

## 实施措施

1. Order 从 B0 baseline 副本解析 RecipeRequest：核对订单与基准版本、已剪词来源、设备拥有权、槽数、原料聚合/份数和重复策略；通过 Economy.PlanSettlement 的零奖励候选检查库存，不安装结果。
2. Potion.Calculate(resolvedRecipe, content) 只接纯数据；独立重查定义、槽位和重复策略，再按 synthesis.lua 八步生成 effects/mods/分级/副作用/稳定性与八步 trace。时间在八步之后依主词 profile 换算。
3. Potion 的残留输出沿用 B0 三字段条目：effectId、weight、untilAfterDoseHours；每条保存 profile 的明确采样点（结束时刻 + hoursAfterEnd），不插值。SampleResidual 按内容已声明的规则精确采样，表前为完整效果权重、表尾之后为 0、内部缺点报错；被采样标签没有残留表即 CONFIG_MISSING。
4. Order.Evaluate 输出逐条检查和失败原因；标签缺失按 0，附加效果只受明确禁用条件约束，未知条件/缺配置报错误。不把不稳定提示直接当不可发货，不求人物后果或评分。
5. 真实 C2 A～G4 期望驱动测试；增加八步顺序、边界、坏输入、配置缺口和纯度检查，沿用 Lua 5.4 隔离 runner。运行 B2 回归、LSP；查询预览状态，若 stopped 不启动。

## 影响文件树（实际）

```text
scripts/
├─ systems/CalculationGuard.lua        两个纯计算模块共用的字段/有限数值/Result 边界
├─ systems/Potion.lua                  纯计算、结果校验与明确残留采样
├─ systems/Order.lua                   基准配方解析及纯字面判定，无生命周期命令
├─ debug/PotionTest.lua                C2 数值、八步与边界验证
├─ debug/OrderTest.lua                 基准约束、失败明细与无副作用验证
├─ debug/fixtures/B3Fixtures.lua        真实 Letter/WordToken/Economy 的纯基准
├─ debug/run_b3.py                     复用既有 Lua/File/UI 隔离 runner
├─ debug/SelfTest.lua                  显式可调用 B3 专项，不自动触发
├─ README.md                          当前实际能力及下一批入口
├─ 后端闭环与双人并行开发计划.md         回填 B3 状态
└─ actions/2026-10-03-b3-implementation.md 本记录
```

## 自验方法

- `python -X utf8 scripts/debug/run_b3.py`：C2 所有数值/字面期望，失败明细；技术配置副本覆盖边界，不修改正式 data。
- `python -X utf8 scripts/debug/run_b2.py`：现有 B2 回归。
- 全 scripts LSP；git diff --check、data/docs 无差异、原文件 SHA256；实际预览状态。
- 纯计算前后比较基准、配置、正式词条/账本副本、默认槽文件及事件计数；同输入计算一致。

## 自验结果

Maker 状态已核对：现有目录绑定、Python/LSP 可用；无远端操作。首轮 B3 359/359，补齐完整 Envelope 结构兼容、附件拒绝、JSON 往返与来源去重检查后 387/387。第一次 LSP 有新代码的类型声明问题，已按真实返回值与数值类型修正，未删除业务断言。没有修改配置来匹配测试。

| 检查 | 实际结果与证据 |
|---|---|
| `python -X utf8 scripts/debug/run_b3.py` | 387/387，退出 0；[最终专项日志](../../logs/b3-expanded.log)。沿用 Lua 5.4 / File / cjson / UI 测试适配器，非引擎窗口证据 |
| `python -X utf8 scripts/debug/run_b2.py` | 201/201，退出 0；[回归日志](../../logs/b3-b2-regression.log) |
| 全目录 maker-lua-lsp watch | 完成后重建 LSP 排除增量缓存：2026-10-03 12:14:29，0 Error / 0 Warning；[诊断](../../logs/lua_diagnostics.log) |
| 原子性/纯度边界 | 基准、真实模块库存/词条、配置副本不变；Save 调用 0、事件 0；默认槽五份文件前后字节一致；同输入结果一致，结果与配置/输入无共享可变表 |
| 与既有存档结构交接 | 真实 B3 PotionResult / RequirementResult 放入完整技术 Envelope，经 SaveSchema.ValidateV2 通过。后果/评分仍是显式技术占位，没有跑 B4/B5 |
| JSON 往返 | A～G4 的完整 PotionResult 可序列化、恢复后逐字段一致；不是 OS 退出重进 |
| 预览状态 | 已实际调用当前 0.0.36 Maker CLI `preview status --target-dir D:\taptap\To-the-Human-World --json`，stopped / process_alive=false，未复活；返回的旧会话日志不计作 B3 运行证据 |
| 格式与范围 | `git diff --check` 通过（仅行尾转换提示）；`git diff --numstat -- scripts/data docs` 为空；原未跟踪文档 SHA256 与交接一致，主页图片无差异 |
| 文档与新文件 | 三份更新文档的 28 个本地链接有效；8 个新增文本文件无行尾空白；主页图片 git hash-object 与 HEAD blob 相同 |
| 未重跑项 | B1 130 项、R2 八例与配置门禁三例沿用 B2 复核记录，本批未改其实现，不称为本批新跑 |

专项覆盖：真实 C2 所有 A～G4 药效、等级、时长、延迟、稳定性、副作用、已声明残留采样及字面失败明细；第 2 步后来辅助词的同标签奖励、第 3 步不加该奖励、第 5 步缩放与零/负边界、第 7 步不重新缩放且重定级、闭区间与超出最高档、稳定性只提示。另含主辅同实例/同定义策略、重复原料聚合、原料份数/库存、拥有设备实际槽数、附件来源/可用性/领取、版本/旧基准/已确认订单、未知字段/ID/条件、缺 profile/精确映射/残留点、非有限数/循环请求。

真实窗口、移动端、完整 v2、退出重进及 A1～A19 未因本批通过验收。

## 实际接口与后续交接

所有接口使用 B0 Result。失败含 code/path/message/details；正常字面不合规返回 ok=true、canShip=false。Order.New(content) 只绑定只读内容及公共查询模块，不持有订单生命周期状态；模块默认 Order.ResolveRecipe/Evaluate 绑定统一 data.content，调用前仍须由入口完成 Data.Load / ValidateStage1。

| 接口 | 输入与实际结果 |
|---|---|
| Order.New(content).ResolveRecipe(request, baseline) | request 为 B0 RecipeRequest；baseline={id,revision,contentVersion,live}，live 提供已接订单、letters/wordTokens/economy 副本。核对本单与基准 ID/内容版本，再经 Letter、WordToken、SaveSchema 联合来源校验和 Economy 零奖励候选检查 |
| resolvedRecipe | `{orderId,baselineId,contentVersion,equipment,main,aux,ingredients,specialItems}`；equipment 为定义副本，main/aux 使用 B2 `{tokenId,definition,source}`，ingredients 行为 `{ingredientId,quantity,definition}`，按 ID 排序；aux 保持传入顺序 |
| Potion.ValidateResolvedRecipe(resolvedRecipe, content) | 独立结构、当前定义、槽位及重复策略检查，返回纯数据副本；不验证正式库存拥有权，调用方应先走 Order.ResolveRecipe |
| Potion.Calculate(resolvedRecipe, content) | content 是统一 Data 或显式技术副本，读取 effects/words/ingredients/equipment/synthesis/attributeProfiles/stage1；返回 B0 PotionResult，不新增顶层存档字段 |
| PotionResult | `{synthesisVersion,contentVersion,effects,intensityByEffect,mods,durationHours,onsetDelayHours,recoveryAfterEndHours,residuals,stability,unstable,sideEffects,trace}`。mods 五项显式数值，sideEffects={ruleId,addTags} 数组 |
| trace | 恰好八行 `{step,inputs,outputs,sourceIds}`；输入/输出均为独立副本，sourceIds 保序去重，便于配置追踪及兼容现有存档结构。时间转换在八步之后，不新增第九步 |
| Potion.ValidateResult(potion, content) | 校验版本、效果/等级、五项 mods、稳定性、非负时间、残留采样点、副作用记录和八步 trace 的结构一致性；不是从历史配方重算或 B5 事务真实性验证 |
| Potion.SampleResidual(potion,effectId,atAfterDoseHours,content) | 返回 weight。residuals 的 untilAfterDoseHours 存配置明确采样点时刻，点前/点后按本包声明规则处理，中间非声明点返回 CONFIG_MISSING；无该标签残留表即使最终标签缺失也不假定 0 |
| Order.New(content).Evaluate(requirement,potion) | 读取 desc/tags/conditions/forbiddenEffects；tags 按 ID 排序、conditions 保序、forbiddenEffects 为效果 ID 数组（禁止出现，权重上限 0）。返回 `{canShip,checks,failures}`，每项为 `{id,kind,passed,expected,actual,unit,message}` |
| SelfTest.RunB3() | 显式纯计算专项，正常启动不执行；命令行 `run_b3.py` 复用现有隔离 runner，不新增正式 UI 或快捷键 |

时间单位为游戏小时，服药时刻为 0；强度/残留单位为 weight。重复请求纯计算不分配新事务、无保存和事件；版本或未知条件等错误不会变成默认成功。B5 还须在真实协调器里复查正式 revision/阶段、原子保存与幂等确认，纯 baseline 参数本身不能证明它仍是当前正式基准。

### C2 实际运行摘要

| 样例 | 关键药效 | 持续 / 延迟（小时） | 字面结果 |
|---|---|---|---|
| A | sleep=1 | 8 / 2 | 通过 |
| B | sleep=1.64、dream=0.6 | 8 / 2 | 通过 |
| C | sleep=1、forget=0.6 | 8 / 2 | 通过 |
| D | sleep=1.64、dream=0.6、forget=0.6 | 8 / 2 | 通过；本人感受/星级待 B4 |
| E | sleep=1 | 10 / 2 | 失败：持续 10>8、恢复 13>12、上工残留 0.6>0.4 |
| F | sleep=0.6、calm=0.6 | 6 / 2 | 失败：sleep 0.6<0.8 |
| G1 | sleep=1 | 8 / 1 | 通过，12 小时残留 0.05 |
| G2 | sleep=1.5、dream=0.4（副作用） | 8 / 2 | 通过，残留 0.15 |
| G3 | 同 G2，稳定性 -1 | 8 / 1 | 通过，不稳定仅提示，残留 0.075 |
| G4 | sleep=1，夜露×2，稳定性 -2 | 8 / 0 | 通过，不稳定仅提示，残留 0 |

### 后续与边界

- 收尾已结束本轮创建的专用 Lua LSP watcher 及其子进程；保留诊断日志，未启动或刷新预览。
- B4 接人物事实、实际来信调度、回信拼装及星级；当前 C2 的 facts/rating/followupFragments 未被拿来直接作为计算输出，尚未证明人物后果。
- B5 实现真正的接单/基准/试做/确认/重置与 Order 状态恢复，再由集成人启用正式 v2。当前 main 仍 v1。
- 阶段 1 没有特殊附件效果配置：已验证非本信/未领取/不可用/超槽的拒绝；合法非空附件缺合成规则返回 CONFIG_MISSING。不默认为零效果或赠送物品。
- 只有配置了时间 profile 的主词可算完整 PotionResult；其余词可剪、可作辅助，作主词缺配置明确失败。调试数值已算术验证，不代表试玩平衡冻结。
- 内容方继续按既定分工写主线及普通订单包，保留首单回归基线；实际 UI 与实机验收在 B6/B7，首单闭环一旦就绪即接简单界面试玩。
