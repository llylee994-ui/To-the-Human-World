# B6 接续验收与新稿接口交接

> 2026-10-04 后续授权已扩大到本机 Maker 工具：[隔离候选修复](2026-10-04-maker-preview-persistence-lab.md)通过正常关窗、C/P/F 及重开后重复确认。本文原版环境失败和咨询记录继续保留；候选不等于官方持久支持，P6 内容边界不变。

## 状态与背景

- 状态：Blocked（本轮程序增量、桌面首单操作与布局修复完成；P5/V13 在当前 Maker 预览环境中实测失败，P6 正式实现等待新稿交接）。用户随后确认启动，本记录接续至 2026-10-04；无需再确认本轮启动权限。
- 开工分支 fengyycon@aef9558；已有 B5/B6/一次性代码及文档未提交，逐项保留。已核对 origin 实为 GitHub，fetch 成功；本轮不提交、推送或远端构建。
- 上轮已完成 CancelBrew、ReloadCurrent、失败试做观察、词卡类别和同名来源操作，详见[上轮记录](2026-10-03-r3-b6-review-and-word-contract.md)。不重复实现这些能力，不将历史测试数字作为本轮结果。
- 当前运行内容 story-v0.4-r1；新稿强调和 P6 尚未正式交接。本轮准备程序侧建议契约，不冻结内容侧尚未确认的字段，不新增持久字段，不改 data/docs。
- 开工 preview status 为 stopped；收到用户“确认，继续”后完成真实窗口检查，收尾恢复 stopped。停止限制已不构成本轮阻塞，当前阻塞是已复现的存档缓存清理。

## 实施措施

1. 核对实际 Letter、Narrative、GameState、SaveSchema、PlayView 接口，给出新稿三段文本／强调与收取变体的候选契约，说明现状与新增边界。
2. 运行 B6 按钮回归、一次性和正式内容回归；本轮不改 Lua，只有发现具体失败才进入程序修复。
3. 整理 A1～A19 逐项证据与独立验收槽的 W09/V13 操作步骤；受支持的持久存储以本地文档及实际进程证据为准。
4. 获准启动后再进行真实窗口和三个退出点检查；未获得启动确认则保留未验证状态，不以适配器替代。
5. 更新本机计划的接续入口，记录实际验证结果与剩余交接依赖。

## 实际影响文件树

- `scripts/actions/2026-10-03-b6-acceptance-and-text-contract.md`：本轮事实与验证记录。
- `scripts/新稿阅读与收取变体_程序交接契约.md`：P4 强调、P6 收取时选择与存档来源的程序侧候选接口；供内容负责人共同确认。
- `scripts/B6_窗口与退出恢复验收.md`：现有 A1～A19 状态、W09/V13 具体步骤及证据要求。
- `scripts/本机实施计划_新内容联调与B6_2026-10-03.md`：仅追加本轮记录／契约／验收入口。
- `scripts/main.lua`：显式 B6 启动槽、与 B1/B2 请求互斥、首帧只读证据；保留此前未提交装配代码。
- `scripts/debug/B6RunRequest.lua`、`B6Evidence.lua`：新增开发期开关与真实布局／快照记录；最终开关为 off。
- `scripts/debug/DebugPanel.lua`：允许 b6_* 专用槽并标识，同槽保存／读取。
- `scripts/debug/run_b1.py`：新增 --b6-acceptance 验证真实入口不碰默认槽。
- `scripts/ui/PlayView.lua`：禁止长文本纵向压缩，正文内宽拉伸并留出滚动条。
- `scripts/README.md`：接续真实窗口结果和 V13 环境失败摘要。
- `logs/b6-next-*.log`：忽略目录中的本轮回归输出。
- `logs/b6-window-*.png`、`b6-v13-*-before/`、`b6-startup-evidence.json`、`b6-lua-log-scan.json`、`b6-final-*.log`、`b6-acceptance-lsp-scripts/`：实际窗口、原始存档副本、运行与回归证据；`.tmp/b6-window.ps1` 为本轮临时 Win32 截取／输入辅助，明确验证 Runtime PID，只操作窗口客户区。
- 不删除文件，不修改正式配置、存档 schema 或引擎资料；已有改动保留，只在上述授权程序文件增量编辑。

## 自验证方法

- 只读核对实际接口与计划；检查本轮 Markdown 本地链接及 `git diff --check`。
- 运行 `python -B scripts/debug/run_b6.py`、`run_single_use_words.py`、`run_story_content.py`，检查退出码和结果；这些是真实 Lua 的隔离存储/UI 适配器检查。
- 核对 preview status 和实际窗口授权；仅真实引擎进程的退出重开可产生 V13 证据。
- 检查本轮变更范围、data 差异、暂存区以及开工时已有文件的保留情况。

## 自验证结果

| 本轮检查 | 实际结果 |
|---|---|
| `git fetch origin`；HEAD 与 origin/main | 成功，均为 aef9558；没有新提交需要合入 |
| `python -B scripts/debug/run_b6.py` | 退出 0，170/170；含准备阶段专项 104 项；[日志](../../logs/b6-next-buttons.log) |
| `python -B scripts/debug/run_single_use_words.py` | 退出 0，229/229；正式 story-v0.4-r1 的 29 定义全部一次性；[日志](../../logs/b6-next-single-use.log) |
| `python -B scripts/debug/run_story_content.py` | 退出 0，1265/1265；当前来源 16/16，未来纯计算 9/9，矩阵 9/9；[日志](../../logs/b6-next-story.log) |
| 本轮四份 Markdown 本地链接 | 24 个全部存在 |
| `git -c core.safecrlf=false diff --check` | 通过；仅本机计划有 Git 的 LF→CRLF 提示，不是内容错误 |
| data／暂存区 | `git diff --name-only -- scripts/data`、`git diff --cached --name-only` 均空 |
| 既有主页图与未跟踪文档 | SHA256 仍为 541EFC50…6625／DC65A8CE…6306，与交接记录相同；未删除或覆盖 |

测试日志由 PowerShell 重定向，部分中文启动提示存在编码显示问题；英文汇总、计数及退出码可读，不能把字符显示问题解释成游戏中文渲染失败。本轮未改 Lua，未重复 LSP；上轮 0E/0W 属历史证据。

## 本轮交付与剩余工作

### 用户确认后的接续

- 用户已明确“确认，继续”，授权启动本地预览，继续窗口与真实退出验证；不再等待启动答复。
- 接续先按已有 B1/B2 开发请求模式新增 `debug/B6RunRequest.lua`（正常为 off，验收期间显式 b6_* 槽），main 启动即选择独立槽，DebugPanel 绑定同槽，避免默认档及旧隔离协调器混用。
- 新增 `debug/B6Evidence.lua`：只读快照、真实控件布局，F9 显式输出诊断证据；不注入玩法、不写正式状态。补 main、DebugPanel 及隔离入口回归，必要时修复实际窗口问题。
- 验收后恢复请求为 off；记录实际文件写入位置、进程重开、截图和限制。相关 Lua 修改后检查 LSP 与入口隔离回归。
- 已出现真实窗口问题：长正文部分行贴右边缘，炼药要求部分行裁切。以实际窗口截图复现；优先区分 Label 默认 flexShrink、百分比宽度／padding、滚动裁剪三项原因。如证据支持，在 `ui/PlayView.lua` 作小范围布局修正，最多两轮自动修复后明确剩余问题；不改引擎库。
- 00:06 前实际证据：首次进程 PID 44868 收取／已读／剪“睡觉”并写入相对路径；真实路径在 `C:/Windows/Temp/maker-cache-Nd60N8/.../savedata/0`。正常停止后目录消失。第二进程 PID 27496 同槽启动 `status=new, revision=0`，缺口与卡丢失；窗口内仍可正常试做失败、返回准备及生成合规 pending。第二次退出前 pending 证据在 `logs/b6-v13-pending-before`，停止后 `maker-cache-IUuu2x` 同样消失。第三次以相同程序重开核对 pending。

- [候选契约](../新稿阅读与收取变体_程序交接契约.md)对照当前实际接口，明确强调码点、与剪词重叠、独立要求栏、收取选择时机、完整正文／词源保存及旧档边界。字段是程序侧建议，尚未共同冻结，未进入 B0 正式接口或 data。
- [验收表](../B6_窗口与退出恢复验收.md)逐项列出 A1～A19 支持证据和缺口，以及 W09／三个真实退出点。正式实机条款均未勾通过。
- 当前缺少 B6 专属槽的开发期启动／选择入口：main 默认 LoadProgress(nil)，旧 DebugPanel.SetTestSlot 仅 B1/B2，不能直接拿来验证正式 B6。启动窗口验收前需小批次补这个入口，使用真实 EngineStorage，不能替换介质或清默认档。
- 已查本机官方存储与预览说明：原生 File 相对路径按项目／用户隔离；prepare 模式清理每轮下载缓存，但当前 savedata 实际位置及是否随缓存删除尚未运行证明。没有把旧环境推测写成已复现失败。
- 未收到本次启动确认，未启动／刷新停止的窗口，未取得新窗口、手机或 V13 证据。启动限制来自本机计划 P5 和本地预览技能；待确认后续执行，不反复询问既定玩法规则。
- 新稿要求、剪词、变体及条件仍待内容侧交接。本轮没有通知其他人，没有改正式内容、Lua 或存档字段，没有提交推送和远端构建。

以上“未启动／未改 Lua”是收到确认前的历史小结，以下为最终接续结果，不再作为当前状态。

## 2026-10-04 最终接续结果

### 真实窗口与存档

- 窗口实际 412×734；已操作打捞→阅读→剪睡觉→投料→不合规药效观察→清料→返回准备→合规后续→重置→换成两种原料→确认。确认前 30 金币，确认后 110、发货 1 次；同一来源卡被 order:1 消耗，界面显示 0 张。详情及截图见[验收表第 6 节](../B6_窗口与退出恢复验收.md#6-2026-10-04-实际窗口与退出结果)。
- C/P/F 三个真实进程退出点全部失败于存储环境：原生相对 File 实际位于每轮 `maker-cache-*` 中，Maker 正常结束会删掉整个目录；同槽重开全部为 new／revision=0。三个退出前原文件与解码副本保存在 logs，只读留证，从未拷回 Runtime。P 的前后程序完全相同；C/F 期间只有诊断／UI 增量，无存档结构或规则修改。
- 官方本地文档明确每轮缓存清理，CLI 帮助未发现持久目录参数；没有通过绝对路径、外部介质或重写 Maker 配置绕过隔离。V13 不能勾完成，A10/A18 的当前预览测试为环境失败，手机仍未验证。
- 五个本轮 Runtime Lua 日志已扫描，未发现 ERROR／stack traceback。引擎启动日志仍有 Cube/Day/DaySpecularHDR.dds、themis_x64.dll、空 project.json 的资源消息，但随后实际加载并操作成功；不声称全部引擎日志干净，不把这些消息猜成存档根因。

### 布局修正与检查方法

- 原始复现：实际窗口读信／炼药，长要求第一行上部裁切，文字贴近右侧滚动条；截图 `b6-window-brew.png`。不能用 HeadlessUI 断言视觉，因此以固定页面、真实 Win32 客户区截图和引擎尺寸作反馈。
- 第一轮只禁止滚动正文／Label flexShrink，首行恢复；第二轮将正文及 Label 的百分比宽改为 alignSelf=stretch，并预留右边距，长句在滚动条左侧换行。最终[来信](../../logs/b6-window-final-letter.png)、[炼药要求](../../logs/b6-window-final-brew.png)已实际查看；没有改引擎参考库，也没有继续第三轮自动修正。
- 最初截图进程未声明 DPI aware，坐标不一致；修正临时辅助后仅采集真实 412×734 客户区。小幅滚轮／键盘注入没有稳定到达预期位置，改用可见滚动条拖动及按钮；最终删除未实测成功的 F9 入口，只保留显式验收启动首帧输出。桌面宠物叠层不计入游戏 UI。
- LSP 首次 check 因缺 emmylua_check 未运行；随后错误地把工程根作为 watch 范围，包含引擎示例导致大量无关诊断，已结束该进程。scripts 增量 watch 收尾曾对未改的 SaveSystemTest 报 2 个可空警告；未改测试或屏蔽诊断，重新开启完整扫描复核。最终 2026-10-04 00:19:41 为 0 Error／0 Warning／0 Hint，见 [最终完整诊断](../../logs/b6-final-lsp/lua_diagnostics.log)，不引用之前的增量报告作为最终结论。

### 最终回归与边界

| 命令 | 结果 |
|---|---|
| `python -X utf8 -B scripts/debug/run_b1.py --b6-acceptance` | 通过：真实入口、跨天、调试保存／读取、ReloadCurrent 均绑定同一个 B6 槽；默认槽 canary 不变；[日志](../../logs/b6-final-b6-entry.log) |
| `python -X utf8 -B scripts/debug/run_b1.py` | 130/130；[日志](../../logs/b6-final-b1.log) |
| `python -X utf8 -B scripts/debug/run_b2.py` | 212/212；[日志](../../logs/b6-final-b2.log) |
| `python -X utf8 -B scripts/debug/run_b6.py` | 170/170，含准备专项 104；[日志](../../logs/b6-final-b6.log) |

最终验证开关已恢复 off，本轮预览正常停止。原独立槽会随正常关闭被 Maker 清理，证据副本保留；未触碰默认玩家存档。未提交／推送／远端构建，data/docs 没有本轮编辑。当前最小后续是取得适用于本项目的官方持久运行环境，再补 V13 和完整 W09／手机条款；不把当前桌面局部结果升级成 A1～A19 全过。无需重新确认既定玩法；新稿契约仍待内容交接。

最终五份交接文档的 77 个本地链接均有效，`git -c core.safecrlf=false diff --check` 通过；data 差异及暂存区为空。诊断进程已结束，没有保留本轮后台 watcher。当前 `fengyycon` 保留此前及本轮未提交工作。

收尾 status 还发现本机并行新增／修改的开场首信定稿、文案 README 与文风计划及其行动记录；这些不是本助手写入，已保留。当前正式 data 未变，本轮运行证据仍对应 story-v0.4-r1，不把新文案定稿当作已进入运行配置。

## 2026-10-04 运行环境专项接续（用户三项指令）

### 状态与范围

- Blocked（等待官方支持路径）：已完成直读资格核对，已向官方提交最小反馈 #568；当前没有可证明持久化的受支持运行入口。当前代码、配置与玩家数据不改。沿用上轮 C/P/F 的真实失败证据，不把它们算成本轮新测试。
- 用户明确授权：核查并实测受支持的运行环境；若仍需临时预览，向 Maker 确认持久存档方式或安排正式原生测试；环境确定后同项目、同用户、同独立槽重验三个退出点及结算幂等。暂不改玩法、不引入云存档。
- 本轮已核对 fengyycon、工作区及 GitHub origin；既有未提交和并行文案改动保留。Maker 状态为 ready/0.0.36；预览 stopped。

### 措施与完成条件

1. 只读比对安装包官方预览说明、实际分流函数、当前 .project 配置及 CLI preflight；不能删配置或 .meta 来制造直读资格。
2. 找到受支持路径才启动；同槽写入→正常退出→确认文件保留→新进程恢复，不能用备份拷回或 UI 读档替代进程重开。
3. 当前配置若必须 manifest，使用用户已授权的官方反馈入口发送最小脱敏问题，询问稳定项目/用户身份与存储生命周期；记录是否真正提交及回复状态，不把反馈已发送当作环境解决。
4. 环境获证后才重验 C/P/F，以及确认后重复操作、再次重开时卡/库存/货币/世界状态不重复变化。若官方路径仍未知，则明确标记未运行，并留下正式原生验收的前置条件。

### 本轮实际影响文件树

- 本行动记录：环境诊断、官方反馈和验证事实。
- scripts/B6_窗口与退出恢复验收.md：当前分流限制与续验条件；不改历史结果。
- scripts/本机实施计划_新内容联调与B6_2026-10-03.md：追加环境接续入口。
- logs/b6-environment-classification.json：配置字段、preflight、安装包一致性及配置保留哈希，本地证据。
- logs/b6-environment-report-context.json、logs/b6-environment-report-result.json、logs/b6-environment-support-report.md：官方 CLI 的脱敏报告与 manual_required 结果；含本机诊断元数据，仅本地留存，未发布。
- logs/b6-environment-public-report.md：实际发布的最小报告，无项目名称、本机路径、配置附件、代理信息或环境哈希。
- 不修改 Lua、data、docs、.project、Maker 安装包或用户 MCP 配置；不提交、推送、远端构建。

### 自验证方法与结果

- 当前 CLI preview status/help、官方包分流源码、配置字段交叉核对；本地证据和反馈结果落盘后检查脱敏、链接及 diff。
- 未运行：持久性冒烟、C/P/F 新运行、确认幂等的新环境证据。没有符合当前工程的官方直读路径，因此不手动强制 Runtime 直读，不重复同环境失败试验，不以历史逻辑用例代替新验收。未改 Lua，未重跑 LSP/玩法回归。
- 已证实当前配置触发 resource_manifest：settings.sources/build、resources.preload_groups/groups、scripts 中的 .meta 任一类即足以触发；无直接读取的 CLI 强制参数。直读持久性尚未测试，不能宣称通过。
- 当前 scripts 有 57 个 .meta，无 dist/latest.json，无 server.lua/server_main.lua，multiplayer.enabled=false；所以不是联机或旧 dist 导致。当前调用 preflight 与官方安装包 classifyPreviewProject 结论一致。两份本机 CLI bundle SHA256 相同，排除 PATH 版本与活动 MCP 版本不同造成的文档对照问题。证据见[分类结果](../../logs/b6-environment-classification.json)。
- 官方线上文档读取失败（web 无有效内容，GitHub 文件入口 404），不推断官方没有该功能；结论限定当前已安装 0.0.36 的官方包说明、源码和本机配置。检索到的第三方结果未用作依据。
- 已按用户“向 Maker 确认”授权执行官方 mcp report。返回 manual_required，未创建 Issue；附带的 mcp_verify 出现 spawn EPERM，这是受限子进程检查失败，不能解释游戏存档问题；当前 Maker status MCP 实际成功。
- 随后用 GitHub 连接器提交官方 CLI 报告，被自动审批拒绝：本机路径、配置路径、代理状态和环境哈希不宜按当前授权公开。原报告未发布，未换渠道绕过；删除上述全部元数据，仅保留产品版本、通用现象、复现与支持问题，再用同一工具成功创建[官方 Issue #568](https://github.com/taptap/instant-games-open-mcp/issues/568)。创建时间 2026-10-04 11:55:55 +08:00；实际正文见[最小报告](../../logs/b6-environment-public-report.md)。未提交源码或原始存档。随后独立读取 Issue，确认 open、comments=0，正文与最小报告一致。
- 当前询问已送达，不等于已获官方答复或运行环境已解决。正式原生测试条件及同项目/用户/槽的复验安排见[验收表第 7 节](../B6_窗口与退出恢复验收.md#7-2026-10-04-运行环境专项核对与续验)。
- 最终复核：提取安装包未改动的 classifyPreviewProject 及只读辅助函数，在 Node vm 中对当前工程实际执行，返回 single_player、network_required=false、preparation_required=true、reason=resource_manifest；没有启动 Runtime 或更改分流。结果补入分类证据，不仅引用旧 session 的 preflight。
- 三份本轮交接文档的 59 个本地文件链接有效；project/settings/resources 配置与 B6 开关的 SHA256 前后相同；公开最小正文未含本机标识/路径/代理/哈希；git diff --check 通过，data 差异及暂存区为空。未修改 Lua，预览未启动，保留原停止状态；本轮无需 LSP/玩法回归。新环境验收尚未运行。
