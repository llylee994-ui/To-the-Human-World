# 埃利亚斯确认稿接入（六个剪词不变）

## 状态与情况

- 状态：Completed（已完成文档与本地代码替换及隔离回归）。用户检查全文并明确“开始”，授权同步文档与代码。
- 来信使用对话确认稿：六个可剪词依次为累、笑、忘记、梦、安静、睡觉；“安安静静”仅剪中间的“安静”。
- 七版后续使用用户供稿，仅按确认修正“帮你”为“帮我”，补三／四／六的段末句号。
- 不修改词库、词条属性、事实生成条件、订单要求、评分条件、星级、报酬或合成公式；不引入别名。不提交或推送。
- 上次接入尝试已完整撤销，历史记录保留为 Superseded；本次为重新确认后的独立修改。
- 已生成的存档回信保留历史文本；新生成结果读取新稿。其他人的修改不处理。

## 实施措施

1. 替换首信自介、正文和地址，在新文中按原顺序标记六个剪词；同步文档中的加粗位置。
2. 用七篇整稿替换对应后续片段，完整正文各自表达睡眠和工作结果，取消旧模板首尾和重复共同段。保留旧片段 ID 以兼容历史归档。
3. 仅对完整后续的显示拼接做必要适配，维持事实和评分判定；更新新文案影响的样例断言。
4. 核对运行输出与文档全文、剪词来源、数值和既有规则；运行相关回归并记录结果。

## 实际影响文件树

- `scripts/data/letters.lua`：首信正文和后续地址。
- `scripts/data/followup.lua`：后续整稿、模板和文本覆盖声明。
- `scripts/data/content.lua`、`scripts/systems/Narrative.lua`：支持空的模板首尾，片段正文仍须非空。
- `scripts/systems/OrderAudit.lua`：新稿存档按相同空首尾规则校验；旧稿仅与显式保留的历史模板逐字比对，保留旧回信，不接受任意文本。
- `scripts/data/stage1.lua`、`scripts/debug/NarrativeTest.lua`：相同规则下的新文本片段期望。
- `scripts/debug/check_elias_copy.py`：文档／运行稿一致性及六个剪词检查。
- `docs/文案/开场与首封来信_定稿_v01.md`、`docs/文案/普通订单/首单_埃利亚斯_后续定稿_v01.md`、`docs/文案/README.md`：确认稿及接入状态。
- 本文件与 `logs/elias-approved-*`：行动记录及验证证据。

## 自检方式

- 与修改前快照比对词库、合成与数值；逐字对比首信解析结果和七版实际后续结果与文档。
- 检查六个 body:N 对应词条与此前相同；后续依旧不可剪。
- 配置 Load／ValidateStage1、B2、B4、B5、内容回归；必要时使用既有隔离运行器，区分权限问题与测试失败。
- 本机 Lua 检查与 Git 差异检查；编辑后查询预览状态，停止状态不自动重启。

## 自检结果

- `python -X utf8 scripts/debug/check_elias_copy.py`：3 项检查通过，覆盖首信全文与六个来源、七篇真实规则生成全文、A/B/C/D/G2 旧待确认与已确认存档的十组读档；旧正文保持原样，伪造正文被拒绝。见 `logs/elias-approved-copy.log`。
- `python -X utf8 scripts/debug/run_b2.py`：212 项通过，剪词及信件流程未回归。见 `logs/elias-approved-b2.log`。
- `python -X utf8 scripts/debug/run_b4.py`：339 项通过，事实、后续和评分回归正常。见 `logs/elias-approved-b4.log`。
- `python -X utf8 scripts/debug/run_b5.py`：373 项通过，预览、确认、保存、恢复和失败处理回归正常。见 `logs/elias-approved-b5.log`。
- `python -X utf8 scripts/debug/run_story_content.py`：1265 项通过；当前可达配方 16/16、未来来源纯计算 9/9、边界矩阵 9/9。见 `logs/elias-approved-story.log`。
- 从 Git 修改前配置加载 Lua 表，与当前表逐字段比对：词库、材料、设备、合成、其他 NPC、事实生成规则、片段匹配条件、评分条件和反馈、星级、报酬、要求数值完全不变；样例只更新移除重复共同段后的片段 ID 清单。见 `logs/elias-approved-contract.log`。
- Lua 单次 check 因本机缺少 emmylua_check 未执行；改用已安装的 watch 完整扫描。最终 2026-10-04 23:24:10 为 0 Error／0 Warning／0 Hint，见 `logs/elias-approved-lsp-final/lua_diagnostics.log`；本轮诊断进程已停止。
- `git diff --check` 通过；词库等未修改文件无差异。本轮仅修改上列范围，没有处理其他人的案件稿修改。
- 本地预览检查为 stopped / process_alive=false，未启动窗口；本轮是隔离 Lua 验证，不声称通过真实窗口排版验收。未提交、未推送、未改写玩家正式存档。

### 接入中发现与处理

- 文案与六词检查通过，B2 为 212/212，B4 为 339/339。
- B5／剧情流程发现存档审计仍拼入空首尾而导致文本不一致；同步相同拼接规则，并补旧回信兼容验证。
- 首轮 LSP 发现移除歌名填充后类型推断缺少 bindings 字段；将新稿无填充值显式声明为空表。
- 七个标准后续逐篇比对；混合效果仍沿用原片段匹配，可拼接多篇，未修改其触发条件或额外编写组合剧情。
- 新增旧稿校验测试最初把拒绝位置限定为正文，C 分支实际因旧歌名绑定差异先拒绝；修正断言为正文或绑定一致性拒绝，仍严格要求 STATE_INVALID。最终十组旧稿读档与防篡改均通过。
