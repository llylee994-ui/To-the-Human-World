# 追加可剪词位独立验收（2026-10-18）

验收对象：`docs/actions/2026-10-18-add-cuttable-words.md` 及对应工作区改动。对照基线为 `b7e3ae0`，本轮未修改实现、玩家存档，未进行远端构建或手机预览。

## 首次验收结论（修复前）

新增词位、旧档兼容与相关逻辑回归通过，整体验收暂未通过：生成器复现检查失败，测试文件另有类型诊断待清理。未发现新增词导致旧配方、订单、星级或结局规则改变。

## 待解决问题

### P2：当前生成物不能通过源文档复现检查

运行 `python -X utf8 -B scripts/debug/generate_numeric_v02.py --check`，退出码为 1，报 `scripts/data/numeric_v02.lua 已过期`。这与执行文档中该项 PASS 的记录不一致。

独立在内存中重新生成并比较，差异只有 `scripts/data/numeric_v02.lua:17857` 的 `docs/文案/供给验算表_v02.md` 来源哈希：

- 当前生成物：`dbf1ea6e1af0fb64d091d1c2a60ef7c7310bfd95cb660278ae568d26859023b1`
- 当前源文档：`8da8b3e989b9584ab7d4bdd4512608a110922242dd01d5d6c5eb012b686bd41a`

影响是生成一致性检查失败，目前没有词条或规则数据不一致的证据。应以最终源文档重新运行生成器，再执行 `--check`，并更新执行记录。

### 静态检查：ShortWordTest 有 5 条错误级类型诊断

Maker Lua LSP 对 `scripts/debug/ShortWordTest.lua` 返回 5 条 `undefined-field`：第 96 行的 `l.cuttable`，第 97、104、106、108 行的 `l.id`。其中第 104、106、108 行位于本轮新增断言；前两处访问在基线已存在，未证明它们是本轮新增诊断。

该专项运行通过，这些诊断不等同于运行时报错，但需要正确补充类型信息后重新检查。其余三个变更 Lua 文件（运行数据、NumericV02FlowTest、FirstBatchNativeProbe）的错误级诊断为零。

## 独立内容与兼容性检查

- 以 HEAD 中实际的 61 词运行数据为基线，确认原有 61 个词的全部定义不变，新增恰好 16 个。
- 所有来信去除可剪标记后的可见正文不变；旧词位顺序、ID 与原有来源字段不变。规则、配方等其余运行内容不变。
- 在 N02、N05、N06、N07、N09、N10 的真实旧 61 词内容上分别建立隔离存档，再用当前 77 词内容加载。逐一剪取全部 16 个新增来源，确认旧词卡保留、新来源可剪、重复剪取不重复发卡、保存后可重读。
- ShortWordTest 另外验证了 15 个旧档 pending/shipped/reset 案例。

## 本次实际复跑

| 检查 | 结果 |
| --- | --- |
| 生成器 `--check` | FAIL，仅上述来源哈希过期 |
| ShortWordTest | PASS，77 个实际剪词位均不超过 4 字，旧词位原位，15 个旧档案例 |
| 真实旧 61 词内容升级专项 | PASS，6 封信、全部 16 个新增来源，重复操作与保存重读 |
| NumericV02 `--flows` | PASS，58 个登记流程及 11 单连续路线；77 张卡、消耗 17、采购 24、余额 1106；此入口使用 schema 2 |
| 核心 BalanceTest | PASS，无裸主词三星、无单原料策略覆盖 11 单、58 个原有后果可达 |
| Release economy | PASS，schema 4 的四条真实 11 单路线与 45 个预算检查；余额 standard 1106 / craft 1113 / mixed 1106 / expensive 750 |
| Release ingredients | PASS，58 份登记结果 × 15 种原料组合，共 870 项检查 |
| WordTray / FirstBatch / ReaderBounds / LetterDrawer | PASS，64 / 966 / 48 / 98 断言 |
| LetterPresentation / LetterReader / LetterRender 单项 | PASS，8080 / 14 / 129 断言 |
| 变更 Lua 的 LSP 错误级诊断 | ShortWordTest 5 条；其余三个文件 0 条 |
| `git diff --check` | PASS |

界面相关回归使用测试适配器，不代表原生窗口或手机实机验收。本轮没有验证新增词对分支全收集难度的实际改善幅度；既有全三星路线可行也不能代替这项体验判断。执行文档所述的旧入口已知失败未在本轮重新归因。

经济与辅料测试会改写历史 JSON 证据；本轮已将这两个测试前无改动的文件恢复，保留用户原有工作区改动。

## 修复记录（2026-10-18）

- **生成器复现检查**：已重新运行 `generate_numeric_v02.py`，只刷新 `供给验算表_v02.md` 的来源哈希；`--check` 通过，`words=77 orders=11 branches=58 cells=196 recipes=58`。
- **ShortWordTest 类型诊断**：为 `Data.letters` 增加 `---@type table[]`、为 `oldSpans` 增加 `---@type table<string, string[]|nil>`；Maker Lua LSP 复检四个变更 Lua 文件均为 0 Error，`ShortWordTest.lua` 剩余 6 条 Warning 均为改动前已存在项。
- **复跑**：`ShortWordTest` PASS（77 位、旧词位原位、15 个旧档案例）；`git diff --check` PASS。

## 独立复验（2026-10-18，修复后）

- 已独立复跑生成器 `--check`，退出码 0，`words=77 orders=11 branches=58 cells=196 recipes=58`。
- Maker Lua LSP 逐文件复查四个变更 Lua 文件，均返回空错误列表；ShortWordTest 原先的 5 条错误诊断已消除。
- 再次运行 ShortWordTest：77 位长度与旧词位原位检查通过，15 个旧档 pending/shipped/reset 案例通过。
- `git diff --check` 通过。修复内容为来源哈希及测试类型声明，未见玩法数据修改，上次两个待收尾项已关闭。
- 工作区整体 LSP 另有 23 条错误级诊断，均位于本轮未变更文件；不将四个变更文件的零错误表述为整个工作区零错误。

### 本地重启复验

按用户要求刷新存活的原生预览，session `678a9a6e-4e44-43e9-94e6-47a385aa6617`、reload 6、Runtime PID 3624。当前轮日志确认 77 词数据校验通过，`ordinary-release-v3`，并输出“寄往人间 启动完成（第 1 天）”。已读取后台原生窗口截图，标题背景、标题与开始按钮正常显示；未注入操作系统输入。

日志仍有刷新前已存在的 `Cube/Day/DaySpecularHDR.dds` 与 `themis_x64.dll` 提示，未见新增 Lua 运行错误。CLI 的 `ready=false` 仅表示未提供游戏断言能力，不能将它当作玩法通过；本次启动判断来自当前轮日志与已查看的截图。证据位于 `docs/验证/evidence/add-cuttable-words-2026-10-18/`。该检查不代表手机实机或完整游玩验收。
