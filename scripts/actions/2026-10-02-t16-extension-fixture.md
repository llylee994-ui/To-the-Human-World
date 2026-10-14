# T16 内容侧扩展配置交付记录（技术扩展测试包）

## 状态与背景

- 状态：Completed（技术扩展包已落盘并通过本地组合校验；推送结果见文末）。
- 用户要求：拉取代码、读 [B2 计划](../B2_信件与词条实施计划.md)，完成 **T16 的内容侧部分**——即 §5 中「准备 A12 扩展测试的一封技术订单信与可追溯词条」（配合 T16 提供配置）。
- 基线：分支 main，HEAD `56cbd2c`（含已合并的 fengyycon PR #2：B1 程序基础 + B2 计划）；拉取后工作区干净。
- 边界：只改 `scripts/data/` 与状态文档；不实现 Letter/WordToken（那是程序侧 P1～P6），不改 `content.lua` 的正式内容版本，不触发 Maker 构建。

## T16 要求与本批对应

| T16 / §5 要求 | 本批做法 |
|---|---|
| 技术新增订单信 / 词定义 | 新增 `letter_pa_ext_01`（1 封）与 2 个词定义；只使用现有效果标签，不新增标签 |
| 模块不改代码即可解析 / 接收 | 配置放在独立文件 `data/extension_test.lua`，按 B0/B2 约定注入内容副本，不需要任何系统改动 |
| 改变可用信输入 | `appearCondition.dayMin = 2`：第 1 天不可用、第 2 天起可用（测试适配器按 dayMin/dayMax 产生输入；真实调度在 B4） |
| 不拿直接回信冒充「第二封可打捞首信」 | 技术信是 `kind=order`、可剪、进普通队列；另配的 `letter_pa_ext_followup` 是独立直接回信 |
| 技术增信标明非正式剧情 | 文件头、`marker`、标题「【技术测试】…（非正式剧情）」、人物 notes 与全部夹具文本均显式标注 |
| 保留原首单配置；不改名不重排 | 只新增 ID；`letter_pa_01` 的 ID、正文与 `body:N` 位置未动（回归校验见下） |
| 可追溯词条 | 两个新词出现在技术信正文中，剪下来源为「技术信实例 + body:N」，与既有机制一致 |
| 重复词夹具（P1 出口 / T2） | 正文含两处「灯」：`body:1`、`body:2` 指向同一词定义、位置独立 |

## 实施措施

1. **新增 `data/extension_test.lua`**：技术人物 `npc_ext_test`、词 `word_ext_lamp`（灯）/ `word_ext_nightwatch`（守夜）、
   技术订单信与直接回信各 1 封、事实规则 1 条、片段 2 个、模板 1 个、评分规则 3 条（一至三星齐全）；
   附 `marker`、`suggestedContentVersion`（组合内容用，避免与正式版本混淆）与用法边界注释。
2. **修正 `data/content.lua` 的 `ValidateStage1` 覆盖检查**：原来「重要事实必须有片段 covers」按全局事实检查，
   加入第二封信后会要求每个模板覆盖第一单的事实而误报；改为按「订单信 → 其规则集的事实」对「该订单的模板片段」配对检查，
   并去重报错。这是支持多封信（A12/T16）的必要修正，不改变首单任何判定。
3. **文档**：`data/填写说明.md` 新增 §7.5（技术包清单、注入用法、注入边界）与文件表行；
   §3.2 明确「改动已进入存档的信件正文必须递增 contentVersion」；§8 的「第二封订单信示例」缺口标记为已交付；
   变更记录登记。B2 计划 §5 表后补内容侧交付说明。
4. 首单内容（`stage1.lua`/`followup.lua`/`letters.lua`/`npcs.lua`/`words.lua`/`synthesis.lua`）零改动。

## 影响文件树

```text
scripts/data/
├─ extension_test.lua        [新增] T16/A12 技术扩展测试包
├─ content.lua               [修改] ValidateStage1 覆盖检查改为按订单配对（支持多封信）
└─ 填写说明.md               [修改] 技术包章节、版本递增规则、文件表与变更记录
scripts/
├─ B2_信件与词条实施计划.md   [修改] §5 补内容侧交付说明
└─ actions/2026-10-02-t16-extension-fixture.md  [新增] 本记录
```

## 自检方法与结果

本地无引擎解释器，沿用 `npx -p fengari-node-cli fengari`（Lua 5.3）执行内容层校验（运行时为 Lua 5.4，
本批未用 5.4 专有语法；引擎内运行仍属程序侧验证范围）：

1. **真实内容回归**：`Data.Load()` 与 `Data.ValidateStage1()` 通过（效果 8 / 词条 8 / 原料 4 / 设备 2 / 人物 1 / 信件 2）。
   `letter_pa_01` 可剪词顺序仍为 累、快乐、忘记、梦、安静、睡觉。
2. **组合内容（真实 + 技术包）**：`Data.Load()` 与 `Data.ValidateStage1()` 通过
   （词条 10 / 人物 2 / 信件 4 / 规则 6 / 片段 9 / 评分 8）——证明「只加 data、不改代码」路径在内容层成立。
3. **解析检查**：技术信三段齐备（selfIntro / body / address）；寄信人可解析；`kind=order`、`cuttable=true`、`dayMin=2`；
   三个标记按正文顺序解析为 `body:1 → word_ext_lamp`、`body:2 → word_ext_lamp`、`body:3 → word_ext_nightwatch`
   （两处「灯」位置独立，可直接作为 T2 夹具）。
4. **负向检查**：故意去掉技术包片段的覆盖声明后，`ValidateStage1` 精确报出
   「订单 letter_pa_ext_01 的模板 tpl_pa_ext：重要事实 fx_ext_test_done 没有任何片段 covers」，且不牵连首单模板
   ——确认配对检查生效且作用域正确。
5. **LSP 实测（如实记录）**：`logs/lua_diagnostics.log` 在本会话内**没有刷新**——目录时间戳停在
   19:41:02，内容仍是上一批（B1 内容包）最后一次刷新的结果：**Errors 0 / Warnings 1**（唯一告警为
   DebugPanel 既有基线）。尝试确认编辑器侧 LSP 集成状态未果（进程在，但不再写诊断；本机也没有可
   直接调用的 maker-lua-lsp / lua-language-server）。因此本批**不能声称新的 LSP 全绿结论**：
   - 已做：改动后的 Lua 由 fengari 实际执行通过（语法与运行路径）；对照上一批修过的 LSP 易报点
     （对推理出精确类型的局部补 `---@type table`、索引键补 `string[]`、可空参数标注）逐处自查了新代码。
   - 待做：在编辑器侧刷新 LSP（或由队友在本机运行诊断）确认 Errors 仍为 0、无新增 Warning，之后再进入构建。

## 未验证项（如实保留）

- Letter / WordToken 的真实解析与接收（B2 P1～P6 尚未实施）：本包是**预先准备**的夹具，程序实现后由 T16 使用。
- 真实调度下的「可用信输入」筛选（Narrative/B4 未实现）；正式 A12（内容现场改配置、真实出信）仍需内容方与程序现场验证。
- 引擎内运行与真实存档（V13/A10）；本地预览当前没有运行中的会话，按规范未启动。

## 提交与远端验证

- 内容包提交：`f523ffa`（5 个文件，363 插入 / 20 删除），标题「feat(data): 交付 T16/A12
  技术扩展测试包（新增订单信与词定义，含重复词夹具）」；暂存使用显式文件清单。
- 已执行 `git push github main`：`56cbd2c..f523ffa`；推送后 `git ls-remote github refs/heads/main`
  返回与本地 HEAD 一致的完整 SHA（本节随后续提交同步，不把记录自身的哈希写入正文）。
- 未触发 Maker 提交/远端构建；未改动程序文件（`main.lua`、`core/`、`systems/`、`debug/`）；
  `.tmp/` 下的验证脚本按忽略规则不入库。
