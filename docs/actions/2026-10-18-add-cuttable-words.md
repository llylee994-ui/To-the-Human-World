# 为后期三星与分支收集追加可剪词位

## Status and situation

Completed（内容追加与本地回归）。用户反馈后期可剪词条偏少，全三星与分支全收集困难，要求优先在字数较多的来信增加可剪词。本轮在 N02、N05、N06、N07、N09、N10 共追加16个词位，词库由61位变为77位；未改既有词位、旧词义、旧配方、订单条件、星级与结局规则，未执行远端构建。

## Implementation measures

1. 只从每封信已有最后一个词位之后的正文追加，保证旧 `body:N` 的 spanId 不移动；旧存档中的 `cutSpans`、词卡来源与待确认基准继续对得上。
2. 追加词按“主属性1.0＋0～3个副属性、副项≤0.2、全部≤4字、连续非加粗原文”的既有口径配置，优先补充会卡后期发货门槛或分支判定的属性：稳定、安心、放松、勇敢、食欲、理性、忆起、温暖、镇静、茫然、愉悦。
3. `contentVersion` 保持 `ordinary-release-v3`：本轮只做追加，不改变既有词位与已保存解释；旧档继续读取。若后续需要移动或替换旧词位，必须递增版本并另做迁移。
4. 更新生成器的词位总数断言，重新生成 `scripts/data/numeric_v02.lua`；同步更新短词专项与登记流程专项的词卡总数。
5. 保留既有历史文档中的61位记录为历史口径；在当前词表、供给表与本文记录77位状态。

## Affected file tree

- `docs/文案/词条数值表_v02.md`：新增16行追加词位、更新口径与总数说明。
- `scripts/data/numeric_v02.lua`：由生成器重新生成的运行数据，新增词定义、正文 `{{词}}` 标记与 `cutWordIds`。
- `scripts/debug/generate_numeric_v02.py`：词位总数断言由61改为77。
- `scripts/debug/ShortWordTest.lua`：77位短词检查；新增旧词位原位断言；旧档为 N02/N03/N04/N06 的真实 pending/shipped/reset 案例。
- `scripts/debug/NumericV02FlowTest.lua`：词卡总数断言与输出由61改为77。
- `scripts/ui/landscape/tests/FirstBatchNativeProbe.lua`：原生日志的词卡数量改为按真实托盘卡数输出，不再写死61。
- `docs/文案/供给验算表_v02.md`：注明追加词位不改变58份登记配方与成本。
- 本文档：本轮执行与验证记录。

## Self-verification method

- 生成器 `--check` 复现，确认词表与生成物一致。
- 真实 `Data.Load` 与 `Letter.ParseDefinition`：77位、每封旧 span 顺序不变、新词均在旧词位之后。
- 旧存档：用旧正文/旧词名构造 N02/N03/N04/N06 的 pending、shipped、reset 存档，再用当前77位内容读取、确认、重读。
- 登记流程：58份真实配方、11单连续经营、词卡来源与金币余额。
- 平衡：无裸主词三星、无单原料套路覆盖11单、58个原有后果可达。
- 界面：词条托盘、第一批界面、阅读边界、来信抽屉。

## Self-verification results

| 检查 | 结果 |
| --- | --- |
| `python scripts/debug/generate_numeric_v02.py --check` | PASS，`words=77 orders=11 branches=58 cells=196 recipes=58` |
| `python -c "... content_test_runtime.run('debug.ShortWordTest')"` | PASS，77个实际剪词位均≤4字；旧词位 `body:1..N` 原位；15个旧档 pending/shipped/reset 案例可读、可确认、可重读 |
| `python scripts/debug/run_numeric_v02.py --flows` | PASS，58份登记流程；11单连续路线 77 张卡、消耗17、采购24、余额1106 |
| `python -c "... content_test_runtime.run('debug.BalanceTest')"` | PASS，无裸主词三星、无单原料套路覆盖11单、58个原有后果可达 |
| `python scripts/debug/run_release.py --suite economy` | PASS，standard/craft/mixed/expensive 四条真实11单路线与45个预算检查 |
| `python scripts/debug/run_release.py --suite ingredients` | PASS，58份登记结果、15种零/一/二槽组合、870项检查 |
| `python scripts/ui/landscape/tests/run_word_tray.py` | PASS，64断言 |
| `python scripts/ui/landscape/tests/run_first_batch.py` | PASS，966断言 |
| `python scripts/ui/landscape/tests/run_reader_bounds.py` | PASS，48断言 |
| `python scripts/ui/landscape/tests/run_letter_drawer.py` | PASS，98断言 |
| `ui.landscape.tests.LetterPresentationTest / LetterReaderTest / LetterRenderTest` | PASS，8080 / 14 / 129断言；新增可剪位后信纸布局、剪词与渲染未回退 |
| Maker Lua LSP（四个变更 Lua 文件） | 0 Error；`ShortWordTest.lua` 保留6条既有 Warning（含 `Data.GetEffect` 可能为 nil），无新增 Warning |

### 已知非本轮失败

- `run_letter_presentation.py` 仍在 `PaperConsistencyTest.lua:58` 因找不到旧 `activePanel` 失败；该测试未按 case/day/result 独立面板更新，折叠分支上同样复现。
- `run_balance.py` 在可选的经济证据复核处触发 `DAY_ORDER_UNFINISHED`：`BalanceTest.VerifyEconomicRecipes` 仍按“未发货直接跨天”的旧夹具推进，而日结门禁已在 `20feb45` 接入；未改动 HEAD 上同样失败。核心 BalanceTest 通过。
- `run_numeric_v02.py --startup` 在 `state.NextDay()` 处失败；未改动 HEAD 上同样复现。该启动检查仍是旧口径（新档第一天直接跨天），与当前“先打捞并完成来信再结束当天”的门禁不一致。

## 修复记录（2026-10-18 验收后）

1. 生成器 `--check` 曾报“已过期”。原因是生成后又给 `供给验算表_v02.md` 补了 77 位注记，`sourceHashes` 未随最终源文档刷新。已重新运行生成器；本次变化仅 `docs/文案/供给验算表_v02.md` 的来源哈希，词条、规则、配方数据未变，`--check` 现已通过。
2. `ShortWordTest.lua` 的 5 条 `undefined-field` 已消除：给 `Data.letters` 增加 `---@type table[]`，给 `oldSpans` 增加 `---@type table<string, string[]|nil>`。Maker Lua LSP 复检 0 Error；剩余 6 条 Warning 均为改动前已存在的 `unnecessary-if` 与 `Data.GetEffect` 可空提示，本轮未新增。
3. 修复后复跑：`generate_numeric_v02.py --check` PASS；`ShortWordTest` PASS（77 位、旧词位原位、15 个旧档案例）；`git diff --check` PASS。

## 说明

本轮未提交、未推送、未触发 Maker 远端构建。新增词位不改变已有订单门槛与星级；是否进一步补充梦境、遗忘、痛感、睡眠等稀有主属性，需要先决定是否接受移动旧 spanId 并配套内容版本迁移。
