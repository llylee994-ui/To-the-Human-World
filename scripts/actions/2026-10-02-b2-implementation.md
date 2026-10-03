# B2 信件与词条实施记录

## 状态与背景

Completed（B2 第一层：模块与隔离联调，P1～P6）；B2 专项 201/201，全 scripts LSP 0 Error / 0 Warning，正式接入层未验收。用户授权执行 [B2 计划](../B2_信件与词条实施计划.md) P1～P6，并追加“执行后 P1 和 P2 后，拉取代码继续”。起点 fengyycon@8d9d2dd，按该顺序已快进至 cf4f1d3；原 docs/actions 未跟踪文件保留。origin 实际为 GitHub。用户后回复“授权确认，继续”，明确允许已准备的 content.lua 两处类型注释；其余 data/docs 未写，未提交、推送或远端构建。

按计划先交模块与隔离联调层：正式 main 仍为 v1；没有其他真实恢复器时拒绝 v2 业务命令。B1 V13 的临时存档限制与 R2 实际键鼠复验继续挂起。已沿用本会话完整 Lua 指南及示例 14/15/17 阅读，并核对 B0、B2、实际 Data 查询和恢复接口。

## 实施措施

1. Letter 解析真实定义，稳定 body:N；实现三段视图、收到/已读/已剪候选与直接归档投影。
2. WordToken 用来源长度编码生成实例，校验来源配置，提供库存、配方引用和 reusable 消耗候选。
3. SaveSchema 接公共接口联合校验每一处缺口与 token；GameState 完整候选只保存一次，提交后安装和通知，锁住嵌套操作及不确定提交。
4. 使用真实 Letter/WordToken/Economy 与显式 debug 替身组成完整 Envelope，验证 T1～T17 和故障边界；默认槽逐文件保护。
5. 显式专项入口先绑定 b2_* 槽；普通启动不运行故障测试。Lua 5.4、B1/R2、LSP 与预览状态分层记录。
6. 按本轮例外授权在 content.lua 两处已通过 string 判断的索引键补类型注释，并标明查询结果可能 nil；仅帮助 LSP 收窄类型，不改配置值或运行逻辑。重建 LSP、重跑 B2 已通过。

授权收尾首轮应用补丁后 B2 201/201；LSP 两个 Error 消除，但字典类型默认每个键必有值，导致保留的缺失引用防护被误判“恒真”。仅完善同两行类型注释，明确索引返回 table|nil / table[]|nil，保留运行时 if 防护。最终 B2 201/201、全目录 LSP 0E/0W，未扩大内容修改范围。

用户追加顺序已执行：P1/P2 45 项通过后 fetch 并快进到 cf4f1d3，9 个本地文件拉取前后 SHA256 一致，无冲突。新增的 T16 内容包只注入 debug 内容副本，未进入正式 Data/版本。

实际发现并修复旧 SaveSchema 假设 synthesisVersion 为字符串的问题：真实 synthesis.version=1，现允许正整数或非空技术版本串，并以类型和值严格比较。未把数字转成字符串，也未改配置。本批基准/待确认门禁包含跨天；Load/候选安装期间均拒绝嵌套命令。

收尾复核曾怀疑普通订单信 cuttable=false 的剪裁门禁不足；技术复验确认既有 ParseDefinition 已拒绝不可剪正文中的标记。新增复验的 Restore 断言失败源于该配置本身非法，不是剪词绕过；撤回冗余门禁及不合法的新夹具，保留既有配置校验，不改规则或正式配置。

## 影响文件树（实际）

```text
scripts/
├─ data/content.lua                        经用户例外授权仅补两处索引类型注释
├─ systems/Letter.lua / WordToken.lua       新增独占状态模块与纯候选
├─ core/GameState.lua / SaveSchema.lua      统一提交与跨块校验
├─ core/SaveSystem.lua                     读取返回类型/非文本读取防护
├─ debug/LetterTest.lua / WordTokenTest.lua  模块验证
├─ debug/LetterFlowTest.lua                 命令、故障与隔离验证
├─ debug/fixtures/B2Fixtures.lua            明示技术 Envelope/其他模块替身
├─ debug/fixtures/B2Check.lua               独立计数与诊断
├─ debug/run_b2.py                          复用 B1 Lua/File 适配器
├─ debug/run_b1.py                          提取共用测试运行器，不复制生产逻辑
├─ debug/SelfTest.lua / DebugPanel.lua      显式入口与测试槽隔离
├─ debug/SaveSystemTest.lua                 既有检查的局部状态命名/类型修正
├─ debug/DebugIsolationTest.lua             既有读档检查先断言非空，再读取字段
├─ main.lua / debug/B2RunRequest.lua        专项诊断开关，默认 off
├─ B2_信件与词条实施计划.md                 回填本批实际状态
└─ actions/2026-10-02-b2-implementation.md  本记录
```

## 自验方法

运行隔离 Lua 5.4 B2 专项与既有 B1/R2 各场景；测试 real Data、扩展定义、坏快照、保存前后故障、恢复后事件与副本隔离。LSP 使用已安装工具。按当前预览是否活跃决定刷新；实际引擎窗口/持久退出未运行则单列，不把替身或 reader 重建当 OS 重启。

## 自验结果

P1/P2 出口已验证：`python -X utf8 scripts/debug/run_b2.py --letter-only`，45/45，原逻辑自检 11/11；真实首信三段文本、六处 body:N、原换行/UTF-8、重复收到/阅读、非法标记与副本保护通过。仅 Lua 5.4/File/UI 替身，[日志](../../logs/b2-p1-p2.log)。按用户追加顺序保全本批文件、同步远端后，已继续完成 P3～P6 的第一层交付。

P3～P5 已实现；通过 main 的显式 RunB2Checks 路径跑 `python -X utf8 scripts/debug/run_b2.py`，201/201，包括实际 DebugPanel 三个回调，默认槽五份文件字节未变，事件载荷彼此隔离。

P6 完成（第一层）：此前全 scripts 的 2 Error / 1 Warning 均位于新拉取的 content.lua:1401～1403。用户明确授权后，仅修改两行类型注释：键 string、查询结果 table|nil / table[]|nil。2026-10-02 23:19:38 实际全目录 LSP 为 0 Error / 0 Warning；`python -X utf8 scripts/debug/run_b2.py` 最终 201/201，见 [授权后回归](../../logs/b2-authorized-final.log)。旧 `.tmp` 补丁是授权前提案，实际补丁以 git diff 为准。预览维持 stopped，未自动启动；真实 File/窗口、OS 重启与正式 v2 仍未验证。

最后一轮 B1/R2 重跑先遇到沙箱拒绝 `.tmp/b1-files-*` 读写及清理：这是检查基础设施失败，不作为业务失败。保留失败日志后，在获准的沙箱外重跑同一命令：B1 130/130，R2 八种场景全部 PASS。未关闭故障注入或修改程序来绕过检查。

生成的 `debug/__pycache__/run_b1.cpython-313.pyc` 是本轮 Python 导入产物，已仅删除该确切文件及空目录；runner 禁用后续 bytecode 输出，没有删除用户文件。

最终重建 LSP 排除增量缓存：check 模式因本机未安装 emmylua_check 无法启动，改用现有 watch/emmylua_ls；fresh watch 消除了 WordToken 的增量假警告，同时发现 DebugIsolationTest 两处 Load 返回值可能 nil。按真实读档检查补非空断言后重跑 R2，不删除读档条件。

两次本轮 LSP watcher 均在核对进程号、项目命令路径和父子关系后停止；未启动或停止游戏预览。最终 R2 八例重跑通过，最终 B2 201/201 日志已检查。

用户授权收尾这轮的 LSP watcher 也已按确切进程号、项目路径及父子关系停止。专项开关仍为 off，原 docs/actions 文件 SHA256 未变；当前分支 cf4f1d3 未创建提交。

### 本轮证据分层

| 检查 | 命令/方法 | 实际结果 |
|---|---|---|
| P1/P2 | `python -X utf8 scripts/debug/run_b2.py --letter-only` | 45/45；[日志](../../logs/b2-p1-p2.log) |
| T1～T17 后端 | `python -X utf8 scripts/debug/run_b2.py`，实际 main 专项回调 | 授权收尾后再次 201/201；[日志](../../logs/b2-authorized-final.log)。T13 只重建 reader/真实模块，不是 OS 重启 |
| B1 回归 | `python -X utf8 scripts/debug/run_b1.py` | 130/130；[日志](../../logs/b2-b1-regression.log) |
| R2 隔离 | 上述 runner `--debug-isolation` 依次 existing/missing/flow_missing/v2_corrupt/auto_write/auto_read/auto_read_flow_missing/auto_read_v2_corrupt | 8/8；`logs/b2-r2-*.log`，默认槽逐文件保护 |
| 配置门禁 | 上述 runner `--config-failure` 依次 load/c1/stage1 | 3/3；`logs/b2-gate-*.log` |
| Lua 类型 | 本机 maker-lua-lsp fresh watch，scripts 全目录 | 2026-10-02 23:19:38：全目录 0E/0W；[诊断](../../logs/lua_diagnostics.log) |
| 范围与格式 | `git diff --check`、`git diff -- scripts/data/content.lua`、原用户文件 SHA256 | 无差异空白错误；data 仅授权的两行类型注释，docs 无本轮差异；原文件哈希未变 |
| 实际引擎、窗口、退出重进 | 只查询预览状态 | stopped，未运行 B2 引擎检查；A2/A4/A5/A10/A12 未因此验收 |

编码/写入/读回/提交前失败测试保留旧完整状态；提交后不可读明确 SAVE_COMMIT_UNCERTAIN 并锁定。提交成功而安装失败明确 COMMIT_RECOVERY_REQUIRED（details.committed=true），先回滚内存，再由同槽 Load 对账。通知异常报告成功结果中的 notificationErrors，不把已提交事务冒称可直接重试的写入失败。

## 实际接口交接

均使用 B0 Result：成功 `{ok=true,value=...}`，失败 `{ok=false,error={code,path,message,details?}}`。`GetSnapshot()` 沿用 Economy 约定，直接返回副本或 nil；`Restore/ValidateSnapshot` 返回 Result。纯 Plan、解析和查询不发事件、不保存、不安装其他模块。

| API | 实际 value / 输入边界 |
|---|---|
| Letter.ParseDefinition(letterId) | `{letterId,kind,cuttable,selfIntro?,address,segments,spans}`；segments 含 text/word，word 含 spanId/wordId/text/cut |
| Letter.PlanReceive / PlanMarkRead | `{state,instanceId,changed}`；重复 changed=false；普通收到拒绝直接回信 |
| Letter.ResolveSource(state,instanceId,spanId) | `{wordId,sourceLetterInstanceId,sourceSpanId,sourceNpcId}`；必须收到且已读，位置来自配置 |
| Letter.PlanMarkCut | `{state,instanceId,changed,source}`；只形成缺口候选 |
| Letter.GetView(instanceId) | 上述解析字段加 instanceId/received/read/claimedAttachmentIds；word 片段含 cut/canCut；直接归档按 orderId 查询，返回只读 archive |
| Letter.PlanArchive(state,followup) | 请求含 orderId/transactionId/letterId/renderedText/fragmentIds/rating；结果 `{state,orderId,changed}`，不移出队列或确认订单 |
| WordToken.PlanCut(state,source) | `{state,tokenId,token,source,changed}`；tokenId=`token:<来源ID字节数>:<来源ID>:<位置字节数>:<位置>` |
| WordToken.GetInventory() | 按 tokenId 排序的数组，每项 `{tokenId,definition,source,available,consumedByOrderId}`；首次实例 true/false 均显式保存 |
| WordToken.ResolveRecipe(state,recipe) | 请求至少 orderId/mainTokenId/auxTokenIds，接受 B0 其余配方字段；结果 `{orderId,recipe={orderId,mainTokenId,auxTokenIds},main={tokenId,definition,source},aux=[同型]}`。设备槽/同定义规则、时间属性与药效留给 B3 |
| WordToken.PlanConsumption(state,resolved) | `{state,consumedTokenIds}`；重新解析并比较引用，防定义被改写；reusable=false 才标 consumedByOrderId，正式确认仍由 B5 调用 |
| SaveSchema.ValidateLetterTokens | 参数 letters/tokens/options={letters,wordTokens}；成功返回两块副本，双向核对每处缺口和来源 |
| GameState.ReceiveLetter / ReadLetter / CutWord | 请求分别 `{letterId}` / `{letterInstanceId}` / `{letterInstanceId,spanId}`；成功 `{letterInstanceId,tokenId?,source?,changed,revision,notificationErrors?}` |
| Narrative 接入点 | `options.narrative.FindAvailable(liveSnapshot,conditions)` 返回 Result<letterId[]>；B4 接真实筛选，缺失时拒绝首次收到 |

GameState 只在提交并安装后发 LetterReceived、LetterRead 或 WordCut/WordStored，每个载荷是上述 value 的独立副本；恢复只发 SaveLoaded。重复操作不保存、不加 revision、不通知。基准已建/待确认禁止收信、读信、剪词和跨天；查看允许。

### 首信来源与正常/失败样例

以下为实际配置解析结果，非系统硬编码：统一 `sourceLetterInstanceId=letter:letter_pa_01`，`sourceNpcId=npc_passerby_a`。

| sourceSpanId | 显示词 | wordId |
|---|---|---|
| body:1 | 累 | word_tired |
| body:2 | 快乐 | word_happy |
| body:3 | 忘记 | word_forget |
| body:4 | 梦 | word_dream |
| body:5 | 安静 | word_quiet |
| body:6 | 睡觉 | word_sleep |

完整隔离 v2 已 Load 且筛选允许时，ReceiveLetter({letterId="letter_pa_01"}) → ReadLetter({letterInstanceId="letter:letter_pa_01"}) → CutWord({letterInstanceId="letter:letter_pa_01",spanId="body:1"})：来源 word_tired，tokenId=`token:19:letter:letter_pa_01:6:body:1`；缺口与词在同一完整候选落盘，每步首次变化各增一次 revision。

未读剪词返回 LETTER_NOT_READ；未知位置 UNKNOWN_ID；正文标记错误 CONFIG_INVALID；错来源 SOURCE_INVALID；同实例重复配方槽 DUPLICATE_TOKEN；已耗引用 TOKEN_UNAVAILABLE；归档事务冲突 ARCHIVE_CONFLICT。失败均带 path/message。正式 v1 返回 V2_REQUIRED；缺筛选器 RESTORER_MISSING；未出现 LETTER_NOT_AVAILABLE；打捞禁用 SALVAGE_DISABLED；基准后 ORDER_LOCKED；嵌套 COMMAND_BUSY；未知提交后 STATE_LOCKED，须同槽 Load 对账。

## 后续依赖与未完成项

- P6 内容类型问题已按用户例外授权修正，不再阻塞第一层交付。日常范围仍依 [fyyAGENT §1](../fyyAGENT.md)：“可以读取，不自行修改”；本次仅两行类型注释例外，不扩大其他配置写入权限。
- B3 调用 ResolveRecipe 获取引用副本，按 synthesis.lua 八步求药效与字面判定，不能把本轮配方引用成功当炼药成功。
- B4 实现真实 Narrative.FindAvailable、WorldState 和回信；当前 dayMin/dayMax 筛选只在 debug 中，其他出现条件未知时拒绝，不默认满足。
- B5 接真实 Order/确认/重置，消费候选与归档投影不等于结算实现；集成人待真实恢复器及完整初态齐备再启用 v2。
- 实际 File、实际窗口键鼠、持久退出重进与 A1～A19 继续按既定阶段验收；本轮不启动已停止预览、不部署、不提交。
