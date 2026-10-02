# 首单内容包（C1~C3）交付记录

## 状态与背景

- 状态：Completed（内容包已落盘并本地验证；推送结果见文末）。
- 用户要求：组长身份，完成 [B1 实施计划](../B1_存档恢复与最小账本实施计划.md) 中队友交付 **C1 开局配置、C2 首单数值与投料边界、C3 人物初态/事实/回信/评分**。
- 基线：分支 main，HEAD 5ebe269（含已合并的 fengyycon PR #1）；拉取后工作区干净。
- 范围：只改 `scripts/data/`（内容负责人范围）与状态文档；不改 `main.lua`、`core/`、`systems/` 等程序文件。
  B0 的联合冻结（程序用同一份配置跑通完整输出）不因本批自动完成；B5 的真实订单幂等仍在后续。

## 实施措施

1. **C1 开局配置**（新增 `data/stage1.lua`）：`contentVersion = "stage1-b0v0.2-r1"`；
   初始金币 30（非演算示例值）；四种原料各 3 份；特殊物品显式空集合；`initialEquipmentId = kit_old_cauldron`；
   七条错误样例（缺金币/负金币/小数或负库存/缺一种原料/未知材料/未知设备）供 Economy 初始化校验断言。
2. **C2 首单数值**：`letter_pa_01` 固定报酬 80（复算：漏 2 单下界 10×(80−40)=400 ≥ 票价 300）；
   重复策略 `repeatIngredient=true`、`repeatWordDefinition=false`；
   时间属性 `sleep_basic`（8 小时基础、+1h/点）与 `tired_basic`（6 小时调试值）；
   speed→延迟精确映射 0/2/4 → 2/1/0 小时；残留衰减表（含「药效未结束时按 1.0、超表尾按 0」两条显式边界）；
   首单条件补齐 duration 6~8、onset ≤3、workReady 12、residualAt sleep@12h ≤0.4；
   八步边界（同标签奖励作用域、副作用叠加与重定级、闭区间端点与负权重处理）写入 `synthesis.lua` 注释与填写说明；
   A~F 样例与 G1~G4「同主词不同原料」样例（覆盖 A13、speed=4、副作用 dream 交叉、重复投料）。
3. **C3 人物与回信**：统一 `npc_passerby_a` 的「独居」矛盾（改为与妹妹同住、母亲已故）；
   新增 `initialState`（睡眠/工作/私人记忆 `mem_mother`，含歌名「摇橹调」）与 `initialStateSchema`（类型与允许值）；
   新增 `data/followup.lua`：5 条事实规则、7 个事实、1 个互斥组、7 个片段（含 D 组合覆盖 B/C 的 overrides 与
   「认不清 + 本人难受」内容依据）、模板与 5 条评分规则（三星→二星→一星，一星兜底）；新增直接回信 `letter_pa_01_followup`。
4. **校验入口**：`data/content.lua` 扩展 `Data.Load()`（信件按 kind 分支校验、条件 kind 白名单、
   规则集/模板/评分集引用解析、词条 profile 引用）；新增 `Data.ValidateStage1() -> boolean, string[]`
   （C1/C2/C3 全量检查，含样例齐全、同主词不同原料 ≥3、重要事实覆盖、三星级覆盖、互斥组冲突）。
5. **文档**：新增 `data/填写说明.md`（字段、单位、边界语义、A~G 速查、自查步骤与已知缺口）。

## 影响文件树

```text
scripts/data/
├─ stage1.lua                 [新增] C1 账本与版本 + C2 策略/时间属性/A~G 样例/错误样例
├─ followup.lua               [新增] C3 事实规则/片段/模板/评分/互斥组
├─ 填写说明.md                 [新增] 内容填写与边界说明
├─ content.lua                [修改] 新表暴露、Load 扩展、ValidateStage1
├─ letters.lua                [修改] 首信补 kind/cuttable/reward/conditions/引用；新增直接回信
├─ npcs.lua                   [修改] 统一家庭矛盾；新增 initialState / initialStateSchema
├─ words.lua                  [修改] word_sleep / word_tired 补 attributeProfileId
└─ synthesis.lua              [修改] 副作用规则加 id；写入八步边界说明
```

无程序文件（`main.lua`、`core/`、`systems/`、`ui/`、`debug/`）改动；`.tmp/` 下的复算脚本为本地验证用，不入库。

## 自检方法与结果

1. **Lua 语法与逻辑执行**：本机无 lua/engine 解释器，使用 `npx -p fengari-node-cli fengari`（Lua 5.3）
   直接执行 `data/content.lua`：`Data.Load()` 通过（效果 8 / 词条 8 / 原料 4 / 设备 2 / 人物 1 / 信件 2 /
   时间属性 2 / 规则 5 / 片段 7 / 评分 5）；`Data.ValidateStage1()` 通过。
   说明：游戏运行时为 Lua 5.4；本批数据与校验代码未使用 5.4 专有语法，5.3 执行结果作为本地证据，
   引擎内运行仍属程序侧 P6 验证范围。
2. **独立复算**：另写独立八步计算脚本（不入库）重算 A~G 的标签、分级、时长、延迟、稳定性、
   残留采样、字面判定、事实、片段选择与评分，与 `sampleCases` 声明值逐项比对——全部一致。
   同时渲染了 A~G 每个样例的完整回信文本，检查片段互斥（D 不出现「认出母亲」）、填充值（《摇橹调》）与文案连贯。
3. **可剪词回归**：`GetCuttableWordsOf("letter_pa_01")` 返回顺序仍为 累、快乐、忘记、梦、安静、睡觉（6 个）。
4. **LSP**：改动后 `logs/lua_diagnostics.log` 刷新为 **Errors 0 / Warnings 1 / Hints 0**，
   唯一告警是既有基线（DebugPanel 断言）。中途出现的 2 个 Error 通过补类型标注修复，未删改正确判断。
5. **未验证项**（如实保留）：引擎 File 上的真实存档/退出重进（属于程序侧 P1~P6）；UI 走查（A1~A19）；
   程序侧对样例的独立计算实现（B3）；Economy 初始化对错误样例的实际断言（B1 P4）；
   移动端持久性（B1 §5 平台范围说明）。

## 与 B0/B1 条款的对应

| 交付 | 落点 | 状态 |
|---|---|---|
| C1 内容版本 / 开局金币 / 四原料各 3 / 空附件 / 旧锅 / 错误样例 | `data/stage1.lua` | 已交付并通过校验 |
| C2 固定报酬 / 重复策略 / 时间换算 / 残留条件 / 八步边界 / A~F 与三组同主词不同原料 | `data/stage1.lua`、`letters.lua`、`synthesis.lua` | 已交付并通过校验 |
| C3 人物初态与矛盾统一 / 第二封逻辑信 / A~D 事实 / 单效果与组合片段 / 互斥与兜底 / 评分覆盖 / kind 校验 / ValidateStage1 / 填写说明 | `data/npcs.lua`、`data/followup.lua`、`data/letters.lua`、`data/content.lua`、`data/填写说明.md` | 已交付并通过校验 |

## 提交与远端验证

- 提交：见文末「推送结果同步」；推送使用 `git push github main`，不触发 Maker 构建。
