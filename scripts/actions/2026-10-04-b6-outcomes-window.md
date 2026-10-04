# B6 同主词、星级与字面失败窗口验收

## 状态与背景

Completed（本批窗口对照与存档精度修复，不代表 B6／A1～A19 全部通过）。执行 `2026-10-04-b6-review-and-publish.md` 的下一步；其提交发布已完成，本轮不重复发布。起点及最终 HEAD 为 fengyycon@e3024d5，保留 docs 的并行修改和未跟踪记录。使用现有隔离持久预览候选及新独立槽 `b6_outcomes_20261004_a`，不改默认玩家档、不注入库存、不改玩法及 scripts/data。

## 实施措施

1. 依据 stage1.sampleCases 在真实窗口打捞、剪词、接单；投料前剪齐需要的词卡。
2. 同一「睡」词卡通过重置比较 A（海盐）、G1（海盐+夜露）、G2（灰烬草），验证至少三种结果。
3. 比较 B/C/D 的回信、三星/二星/一星与报酬；E/F 验证字面拒绝。所有预期来自当前配置。
4. 收集截图、原生日志和经过提交标记校验的存档；复核重置不扣卡、不发奖。结束恢复验收选择器 off、正常关窗，记录局限。

## 实际影响文件树

- `scripts/actions/2026-10-04-b6-outcomes-window.md`：行动与证据索引。
- `scripts/core/SaveJson.lua`：新增存档数值精确往返适配；JSON 结构与字符串仍交给引擎 cjson。
- `scripts/core/SaveSystem.lua`：调用上述适配层，保留严格往返／双快照／提交读回校验。
- `scripts/debug/SaveJsonTest.lua`：数值、转义、占位碰撞、旧 JSON、非法语法回归；可在真实引擎运行。
- `scripts/debug/B6NativeSaveProbe.lua`：显式测试入口，使用真实内容／正式模块及内存介质，七组成功配方的待确认／已确认恢复与幂等。最终没有挂到游戏自动启动路径；夹具涉及 GameFlow 单例，应在隔离测试上下文运行。
- `scripts/debug/B6Evidence.lua`：快照日志采用同一精确编码器；临时自动诊断调用已移除。
- `scripts/debug/B6RunRequest.lua`：临时选择独立槽，完成已恢复 off，无最终逻辑差异。
- `scripts/debug/B6FaultEvidence.lua`：精确新槽启用既有只读观察按钮，不启用故障注入。
- `scripts/debug/B6PersistenceProbe.lua`：精确新槽启用原有幂等检查与纯编解码回归，默认 off 时不执行。
- `scripts/debug/maker-preview-lab/fault_evidence.py`：只允许 collect 读取这个额外槽；故障修改仍只针对既有 fault 槽。
- `scripts/debug/maker-preview-lab/verify_outcomes_evidence.py`：读取当前内容预期，对留存的原生证据执行 80 项检查；不代替窗口操作。
- `scripts/B6_窗口与退出恢复验收.md`：追加本轮实际范围。
- `logs/b6-outcomes-*`：忽略的本机截图／存档证据，不提交。
- `.tmp/b6-window.ps1`：忽略的本机输入辅助增加窗口存在／前台检查；运行结束或失焦时拒绝操作和截图。

没有修改业务系统、内容配置、Maker 原版安装、远端或队友文案。无提交／推送／构建。

## 自验证方法

窗口逐项操作并查看截图；检查原生公共状态及磁盘状态相同，重置后基准恢复、已剪词保留，历史槽校验和不变。新增辅助 Lua 运行 LSP；git diff --check；代码批次后核对 preview status。隔离候选的桌面结果不替代官方持久环境、手机或正式美术验收。

## 自验证结果

完成，详见以下实际执行记录与验收结果。

### 原生阻断（17:47）

A/G1 已真实生成 pending 并重置。G2 使用相同主词+灰烬草时显示 SAVE_ENCODE_FAILED「编码往返不一致」，存档仍 generation 12 / brewing / 30 金币；不能将 G2 记为通过。截图与原始日志 `logs/b6-outcomes-g2-*` 留存；正常关闭 PID 42536。追加仅独立槽启动的内存介质原生编码复现，先定位差异，不修改玩法或配置。

追加计划文件：`scripts/debug/B6NativeSaveProbe.lua`（原生 cjson + 内存介质正式存档路径复现）、`scripts/debug/B6Evidence.lua`（仅指定槽调用）。如证实存档问题，修复与回归范围再在此记录。

### 定位与修复范围

原生自动复现 G2 返回同一 SAVE_ENCODE_FAILED；6处末位差异。原生 cjson 只有 encode/decode/null 等接口，没有精度设置。精确数字字面量解码也可偏移，不能只调编码器。严格相等还承担订单审计，不放宽全局相等、不四舍五入玩法数值。

追加 `scripts/core/SaveJson.lua`：仍由 cjson 处理 JSON 结构、字符串与语法验证，数字以 Lua 十进制往返格式临时占位，编解码后还原；磁盘仍是普通 JSON，不改业务结构与 schema，旧档继续可读。SaveSystem 调用此适配层，保留严格往返和提交校验。新增专门回归，验证浮点/整数/字符串占位碰撞/转义/数组/非法 JSON；原生 G2 和重载必须通过后才继续窗口操作。该修复属于已发现的存档阻断，不改玩法、配置或工具安装。

### 实际窗口结果

2026-10-04 17:38～18:16（+08:00），同工程、离线用户 0、独立槽 b6_outcomes_20261004_a。真实打捞首信，剪下累／忘记／梦／睡觉后接单；各组共用同一睡觉来源词卡与首次投料基准。窗口客户区 412×734，逐张查看截图，不采用无头图。

| 配置样例 | 实际组合与结果 | 窗口证据 |
| --- | --- | --- |
| A | 睡觉＋海盐：2 小时后生效、持续 8 小时、睡眠 1、三星 | `b6-outcomes-a-top.png`／`a-bottom.png` |
| G1 | 同主词＋海盐＋夜露：1 小时后生效、持续 8 小时、三星 | `b6-outcomes-g1-top.png`／`g1-bottom.png` |
| G2 | 同主词＋灰烬草：睡眠 1.5、梦境 0.4，码头鱼排队领工钱的回信、三星 | `b6-outcomes-g2-fixed-top.png`／`g2-text.png`／`g2-fixed-bottom.png` |
| B | 睡觉＋梦＋海盐：梦到母亲、三星 | `b6-outcomes-b-text.png`／`b-bottom.png` |
| C | 睡觉＋忘记＋海盐：接不上母亲的摇篮曲、二星 | `b6-outcomes-c-text.png`／`c-bottom.png` |
| D | 睡觉＋梦＋忘记＋海盐：认不清熟悉背影、本人难受、一星；没有混入认出母亲的片段 | `b6-outcomes-d-text.png`／`d-bottom.png` |
| E | 睡觉＋干花瓣：10 小时超 6～8，恢复 13 小时超 12，残留 0.6 超 0.4；拒绝发货 | `b6-outcomes-e-failure-details.png` |
| F | 累＋海盐：睡眠强度 0.6 未达 0.8；拒绝发货 | `b6-outcomes-f-failure-details.png` |

以上截图均位于 `logs/`；文件名第二项省略的共同前缀也是 `b6-outcomes-`。一至三星的界面报酬均为订单固定 80 金币。A/G1/G2/B/C 的五次重置均恢复完整 live 基准、保留四张剪词与接单，不正式扣料或发奖。E/F 拒绝前后，提交代数、文件哈希、完整状态和事件相同。

修复后的 G2 关窗重开，generation 13 的完整 pending 与磁盘文件相等，残留 `0.15000000000000002` 精确保留。最终只确认 D：generation 20、金币 110、已确认 1 单、海盐 2，其余材料 3；睡觉／梦／忘记各消耗一次，累仍可用。正式事件各一次。重开后完整状态／文件不变，公开 Confirm 再调用两次均 alreadyConfirmed、0 事件、无额外结算。[最终窗口](../../logs/b6-outcomes-final-cards.png)。

### 验证命令与结果

- `python -X utf8 -B scripts/debug/maker-preview-lab/verify_outcomes_evidence.py`：80 项通过，[核对汇总](../../logs/b6-outcomes-verification.json)。内容预期从当前 Lua 配置读取；药效与纸面小数比较使用微小计算误差容限，存档、恢复、库存、事件比较均为严格相等。
- 最终重新执行 `run_b1.py`／`run_b2.py`／`run_b3.py`／`run_b4.py`／`run_b5.py`／`run_b6.py`：130／212／387／339／373／170 项通过；`run_single_use_words.py` 229 项、`run_story_content.py` 1265 项通过，共 3105 项。日志 `logs/b6-outcomes-final-run_*.log`。这些使用 Lua 5.4 与显式适配器，不计为新的窗口操作。
- `python -X utf8 -B -c "import sys; sys.path.insert(0,'scripts/debug'); import run_b1; raise SystemExit(run_b1.main([],entrypoint='debug.B6NativeSaveProbe'))"`：最终适配器下七组完整存档回归通过，`logs/b6-outcomes-save-regression.log`。
- 原生 `B6NativeSaveProbe` 曾实测 A/B/C/D/G1/G2/G3 的 pending／confirmed 精确重读与幂等，`logs/b6-outcomes-native-regression.log`；当时使用初版精确数字适配。后续补充转义引号边界后，最终原生 `SaveJsonTest` 通过，见 `logs/b6-outcomes-final-reopened-lua.log`。G2 生成用精确数字适配初版，G2 重开以及 B/C/D 生成、最终确认与重开使用补齐转义边界后的最终版本。
- 初版占位替换遇到半边转义引号的字符串时，新增回归确实报 Invalid escape；已改为按完整 JSON 字符串 token 替换，回归通过，没有放宽存档验证。失败日志 `logs/b6-outcomes-json-escape-red.log` 保留。
- 完整 LSP 重新启动后，2026-10-04 21:04:54 为 0 Error／0 Warning／0 Hint，`logs/b6-outcomes-final-lsp/lua_diagnostics.log`。此前长期运行的增量进程报 3 条既有位置告警，重启完整诊断后未复现，没有为清告警改无关业务代码。
- `git diff --check` 通过。B6RunRequest=off；preview status=stopped／process_alive=false。其他原生槽哈希与开始时一致。

### 执行偏差与边界

- 一次隔离 Python 测试在沙箱内清理自身临时目录被拒绝：测试断言已过，但进程未完整结束；采用已授权的本机测试方式重跑退出 0，不把第一次当完整通过。
- 证据比较器首次运行缺少 Lua package.path，补上当前 scripts 路径后 80 项通过；属于检查工具问题，不是游戏失败。
- 原生内存夹具涉及共享 GameFlow，临时自动调用曾影响当前窗口的已确认单数显示；没有写真实槽。已撤掉自动调用并重启原生进程，确认真实槽恢复 0 单后才继续操作。最终代码中该七配方夹具只保留显式入口；启动仅执行无业务副作用的 SaveJsonTest 与现有确认幂等探针。
- 一次预览达到十分钟时限，D 的未保存投料草稿丢失，随后同槽重新选择并完成 D；已保存的基准和结果不变。失焦截图不作为游戏证据，本机辅助现已校验前台窗口。
- 本轮补齐 A13 的同主词不同原料三种结果、A14 两类失败、A15 本次直接回信因果和 A19 一至三星固定报酬的桌面证据；不把这几个样例扩大为所有剧情／全文边界通过。A12 现场扩配置、正式美术、手机触控／性能、官方持久环境、强杀／断电等仍分别待验收。
- 隔离候选仍不是 Maker 官方支持的持久方案。原版引擎既有 Cube/Day/DaySpecularHDR.dds 与 themis_x64.dll 告警仍在，CLI 总结果退出 1；本轮不宣称全局 Runtime 检查通过。数值适配增加 JSON 扫描开销，手机性能未测。

## 下一步

程序侧复核本批 SaveJson 精度修复与证据，按当前剩余清单继续正式环境／手机及全文边界验收；内容侧继续未冻结字段与 A12 配置扩展交付。不重问已接受的规则，不自行发布；本批改动保持未提交供复核。

## 2026-10-04 提交前复核

复核 Completed，未发现阻断问题。用户已授权“没问题提交推送”，本节替代上节“保持未提交供复核”的后续安排：通过既有 main 提交目录执行 Maker 官方提交／构建，再同步 GitHub main 与 fengyycon；不发布工作区未提交的队友文案。最终提交与构建回执单独核对后在会话交付。

- 核对 SaveJson 的完整字符串扫描、占位冲突规避、精确浮点／整数往返、旧 JSON 解码及非法输入拒绝；SaveSystem 仍先校验可保存结构，保留严格相等、双快照、提交标记与读回检查。没有发现需要放宽校验或修改业务数值的理由。
- 本轮重新执行 B1～B6／一次性／内容回归共 3105 项全部通过，日志 `logs/outcomes-review-run_*.log`；七组配方 pending／confirmed 精确恢复及重复确认再次通过（Lua＋显式适配器，不计为新窗口操作）。
- `verify_outcomes_evidence.py` 重新执行 80 项通过；抽查 G2 回信与 E 字面失败真实截图符合记录。没有启动新的预览、没有写实际玩家存档。
- 沿用并检查 21:04:54 的完整 LSP 结果：0 Error／0 Warning／0 Hint，该结果晚于本批 Lua 最后修改。本轮复核没有再改 Lua，不重复诊断无变化代码。
- 原生窗口、隔离逻辑与远端构建的证据边界保持原文；官方持久环境、手机及完整文本／交互边界仍待验收。
- 提交范围：上述实际影响树中有内容差异的 scripts 文件；B6RunRequest 最终 off、仅换行差异，不另作业务变更。队友新增开发日志 `761dadd` 为既有远端父提交继承，未修改其内容；未提交 docs 逐文件备份保留。
