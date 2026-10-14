# 词条层第一批：happy 整族整理（首单「快乐→笑」）

## 状态与背景

- 状态：已落盘、三项检查全绿；推送结果见文末。
- 起因：组长确认"她老嫌我脸上没个{{笑}}模样"更好、可以继续；这处换词必须与 `word_happy` 整族一起做（单独改首信会被预算检查的"留存见证"拦下，预演结论见[上一份记录](2026-10-03-style-baseline-word-layer-and-swap-attempt.md)）。
- 依据：[词条属性衍射表提案](../文案/词条属性衍射表_提案_v01.md) §3 退场名单（快乐 →「笑」承担 happy）、《文风基准与润色计划》§5"批次 C 第一步"。
- 边界：属性层（6 类 22 项）不动；只动词条层与承载它的文本、引用与账目。

## 实施措施

1. **正文字面**：首信 `body:2`「没个{{快乐}}样子」→「没个{{笑}}模样」；N04 那句改「我想多{{笑}}一点……」；N19 改「我想带着{{笑}}去玩，答错了也还能{{笑}}」；N22 改「我想带着{{笑}}给它们做三张小牌；字写得不好，也还能{{笑}}」。N19/N22 因此各有两处「笑」——正好补上「快乐」退役后可能缺口，且"同信同词多位置"本来就是设计允许的形状（T2 夹具即此）。
2. **词条退役**：`words.lua` 删除 `word_happy`（词池 30→29，happy 由 `word_smile`「笑」承担；两者同为 happy 1.0、同 profile `daytime_basic`，数值不变）。
3. **引用同步**：`recipes.lua` 两条作者配方（`recipe_n01_parade`、`recipe_pa_fish_choir`）的 `word_happy` → `word_smile`；`contentVersion` 由 `story-v0.3-r3` 升为 **`story-v0.4-r1`**（改动了进入存档的信件正文标记）。
4. **检查脚本与预期**：`check_delivery_budget.py` 的 `NEW_SOURCES`、三张订单的 main（N04/N19/N22：happy→smile）、留存见证表（happy→smile）、前三单去重数（14→13）、路线留存（28→27）、词数（30→29）；`check_single_use_content.py` 的词表比对改为"仅允许 `word_happy` 退役"、版本与 stage1 基线前移到 `story-v0.4-r1`、`letters.lua`/`recipes.lua` 移出逐字节冻结清单并各加一条**定向断言**（letters 只允许那一处换词、recipes 只允许那两处换引用），其余八个文件仍逐字节冻结。
5. **放宽一处旧假设**：预算脚本原要求"每封信的每个词恰有一张卡"（`== 1`）。同信同词多位置是设计允许的形状，改为"至少一张、按正文顺序取第一张"，并注明原因。
6. **账目重算**：三份验算 JSON 用文档记录的命令重新导出：未收模式 22 种／7 类与张数（归案 52、其它两路 54）不变；已剪未确认降为 **27 种／8 类**（归案 59、其它两路 61）；路线留存 **27 种／8 类**；票窗与家居余额全部不变。
7. **文档同步**：文案 README、配置交接 v03、词条与 NPC 覆盖规划（含"可直接剪"旧记录作废的修订说明）、逐日投放（漏单口径 28→27 种）、r3 交接（顶部变更注记 + 两行作废标注）、填写说明（首信顺序、版本、变更记录）、提案与文风基准（标记该步已完成）。

## 影响文件树

```text
scripts/data/  letters.lua · words.lua · recipes.lua · stage1.lua · 填写说明.md
docs/文案/     普通订单/普通订单正文包_N03-N22_v01.md · 三份验算 JSON
               README.md · 配置交接_v03.md · 词条与NPC覆盖规划.md · 逐日投放与经济验算_v01.md
               一次性词条_内容交接_r3.md · 词条属性衍射表_提案_v01.md · 文风基准与润色计划_v01.md
docs/验证/     check_delivery_budget.py · check_single_use_content.py
docs/actions/  本记录
```

未改动：属性层（effects.lua、synthesis.lua、profile 机制）、其它信件正文、首单要求与星级事实、任何数值上限／报酬／槽位。

## 自检结果

- `check_delivery_budget.py`：PASS——`13 acquired definitions (14 cards), 11 retained, 270 coins`；三条路线 `retained words 27 / categories 8`；票窗 D6、家居余 1491／1266 不变；worst 漏单对 N03+N04 等不变。
- `check_single_use_content.py`：PASS——29 词显式一次性、`word_happy` 退役仅此一项、A→A→A 为 14 张卡／13 种、30/64 组合连续可供、旧版本基准仍拒绝。
- `check_delivery_content.py`：PASS——20 包、60 核心结果、14 记忆变体、20 趣味门禁、480 边界、160 组真实配方输入、**217 处变更文档链接**。
- `Data.Load`／`ValidateStage1`：PASS（词条 29、`contentVersion = story-v0.4-r1`）。

## 未验证项（如实保留）

- 全量文风润色（批次 A～E 其余部分）未开始；属性隐藏方案的新 `desc` 未改；图鉴"已观察"记录仍是待程序侧评估的字段提案。
- 附图**未重画**：图中列的是 22 项属性与三个阶段示例，不含词表，本次词条退役不影响其内容（按维护规则复查后判定无需改动）。
- 引擎内运行与真实存档未测（B5 事务、UI 仍属程序侧）。

## 提交与远端验证

- 提交：`908096b`（19 个文件），标题「feat(content): 词条层第一批——happy 整族整理（首单快乐→笑，word_happy 退役）」。
- 已执行 `git push github main`：`877a5f0..908096b`，远端 SHA 已核对。未触发 Maker 提交/构建（内容侧批次由对应负责人按既有流程同步）。
- 三份验算 JSON 为脚本重新导出，可复现：`python -B -X utf8 docs/验证/check_single_use_content.py --export "docs/文案/前三单词卡与组合验算_v01.json"` 与 `python -B -X utf8 docs/验证/check_delivery_budget.py --export-word-ledger "docs/文案/词卡逐张供应账_v01.json" --export-omission-summary "docs/文案/漏单词源与资金验算_v01.json"`。
