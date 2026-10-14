# Maker 预览持久性隔离修复与 V13 复验

## 状态与背景

- Completed（本轮隔离候选、正常关窗持久性、C/P/F 和重开后重复确认已验证；不代表官方版本或手机验收完成）。用户授权在隔离副本修改本机 Maker 预览工具，制作可回退修复，先验证关窗重开，再复验 C/P/F。原版 Maker 0.0.36 随机缓存退出被清理，历史证据见[前序行动](2026-10-03-b6-acceptance-and-text-contract.md)。
- 本轮仅本地预览工具、验收诊断与记录；不改玩法、data、.project、云存档，不提交/推送/远端构建。保留 fengyycon 的既有未提交及并行文案改动。
- 诊断假设：①缓存生命周期导致物理删除（历史已复现）；②仅保留缓存仍可能因端口/随机 URL 不同而无法恢复；③若稳定存储后仍失败，再以真实文件与入口快照区分提交/恢复逻辑，不能先改玩法。

## 实施措施

1. 从当前已核对 SHA256 的官方 bundle 生成隔离候选，拒绝版本不匹配；原版安装不覆盖。仅显式开关且同一指定单机工程启用。
2. 将实验预览缓存置于短、稳定、项目隔离的本机路径；持久保存随机 URL capability 和 loopback 端口，端口冲突明确失败，不换端口、不删他人进程。保留原资源白名单、Host/Origin 校验；不扩大下载服务暴露范围。
3. 候选关闭仅结束进程/服务，不删实验缓存；原版和未启用分支仍沿原清理行为。禁止复制历史存档回运行环境。回退即停止候选、恢复验收开关 off、改用原版 CLI；实验数据保留供复核，不迁移进正式存档。
4. 对实际 bundle 的资产服务/缓存清理执行红绿回归：URL 稳定、缓存保留、默认分支清理不变、端口冲突失败及访问保护；再验证真实 Native File 关窗重开。
5. 同工程/用户/独立槽完成 C→重开→P→重开→F→重开，复核重复确认及再次重开不重复扣卡/奖励。必要的公共接口诊断只在显式验收入口，不注入库存或绕过保存。

## 实际影响文件树

- `scripts/debug/maker-preview-lab/`：实验工具补丁生成器、持久目录辅助、回归与使用/回退说明；不包含官方大 bundle 或凭证。
- `D:/taptap/.mpv/`：项目外隔离 CLI 副本和实验缓存，不是新 Maker 项目；原始 bundle 校验/副本，候选 bundle，可回退。
- `scripts/debug/B6RunRequest.lua`：验收期间指定唯一槽，结束恢复 off；如需诊断增量单独记录。
- `scripts/debug/B6PersistenceProbe.lua`、`B6Evidence.lua`：只在精确实验槽的已确认启动状态通过公共 OrderCommand 重试同一事务两次，比较完整快照并统计 EventBus 事件；不替换存储、不注入物料。其他槽不执行。
- 本行动记录、`scripts/B6_窗口与退出恢复验收.md`、本机计划：真实结果、限制和接续入口。
- 前序 B6 行动与 `scripts/README.md`：补最新隔离候选入口，保留原版失败的历史事实。
- `logs/b6-persistent-*` 与现有 `.tmp/b6-window.ps1`：忽略的日志、快照和窗口证据。临时辅助如修改需在此记账。

## 自验证方法

- 补丁前后原版 hash 相同；候选 node --check；实际函数红绿回归（不以模拟 File 替代窗口）。
- 真实窗口关闭、进程退出、存档仍在、新进程加载；记录用户/项目/槽及 C/P/F 完整状态比较。
- 开关最终 off；官方预览停止；无 data/.project 改动；diff/link 与必要 Lua LSP 检查。

## 自验证结果

### 工具修复与回退

- 官方原版与 PATH 版 bundle 最终 SHA256 均为 `62deb6cd7adc3975d23ce5750be53116f02ef7b9b5b9d49e5ace44fbbc144652`，没有覆盖安装。候选只在 `D:/taptap/.mpv/cli`；8 处精确补丁与一个辅助模块。`patch.py` 固定哈希和唯一替换边界；初次因 listen 匹配不唯一而中止，收紧到资产服务完整上下文后成功，未误改其他服务。
- 原版 `test.mjs --original` 退出 1，明确失败 `savedata must survive cleanup`；候选 `test.mjs` 11 项通过。实际抽取 bundle 资产服务/清理方法执行，覆盖同 URL/端口重开、保留文件、默认清理、占用端口拒绝、Origin 拒绝、路径白名单和方法限制；仅为工具测试，不替代下面的真实窗口。
- `node --check D:/taptap/.mpv/cli/dist/maker.js` 通过。目录/身份异常失败时保留文件，不偷换端口或删除外部进程。实验缓存含资源和 savedata，目前约 85 MiB；没有单独回收资源缓存机制。
- 回退已落实：最终窗口正常关闭，preview status=stopped/process_alive=false，B6RunRequest 恢复 off。原版入口始终存在，无全局 PATH/MCP 改动。实验文件保留，不复制进原版默认档。命令和回退步骤见[工具说明](../debug/maker-preview-lab/README.md)。

### 原生窗口与逐点证据

全部为同一个原项目、离线用户目录 `savedata/0`、同一槽 `b6_persist_20261004_a`。原生 File 直接使用稳定实验目录，文件路径及哈希跨关窗保留；没有备份回填。直接调用已核验 Runtime 进程的 CloseMainWindow，确认旧进程结束后才重开。

| 检查 | 原生进程与结果 |
|---|---|
| 冒烟 | PID 53004 打捞后关窗；文件仍在。PID 47944 启动 loaded，快照与退出后 revision 1 完全一致 |
| C 剪词后 | PID 47944 剪睡觉后正常关窗；PID 35828 恢复原缺口、1 张原来源卡、金币 30；相同位置已剪禁用，未新增卡 |
| P 待确认后 | PID 35828 睡觉+海盐生成 pending，第 6 代提交后关窗；PID 70748 恢复原完整 pending，包括 transactionId/基准/药效/事实/后续/星级/消费/奖励；正式金币仍 30、海盐 3、卡可用 |
| F 确认后 | PID 70748 点击确认，第 7 代提交后关窗；PID 66396 恢复金币 110、海盐 2、已确认 1 单、同一 token 已由 order:1 消耗；完整世界/归档与原记录相等 |
| 再次重开与幂等 | PID 66396、58212 两次启动各对原事务重复确认 2 次：4 次均 alreadyConfirmed=true、完整快照不变、0 个 EventBus 通知；第 7 代和全部存档文件哈希不变 |

- [机器核对汇总](../../logs/b6-persistent-verification.json)：smoke/C/P/F/reopen_after_retry 全部 PASS；由 `python -X utf8 -B scripts/debug/maker-preview-lab/verify_evidence.py` 对原文件哈希、完整启动快照、会话变化及事件探针复核。
- 真实截图：[冒烟重开](../../logs/b6-persistent-smoke-reopened.png)、[C 词卡](../../logs/b6-persistent-c-reopened.png)、[已剪按钮](../../logs/b6-persistent-cut-gap.png)、[P 回信](../../logs/b6-persistent-p-reopened.png)、[P 评分与确认](../../logs/b6-persistent-p-buttons.png)、[F 已消耗卡与账本](../../logs/b6-persistent-f-reopened.png)、[第二次确认后重开](../../logs/b6-persistent-retry-reopened.png)。截图来自真实 412×734 客户区；桌面宠物叠层不计为游戏界面。
- 每个点的 before/closed/reopened JSON 与 native Lua JSONL 在 logs/b6-persistent-*；`evidence.py` 只读，不写入 Runtime。原生用户身份是本机 skip_login 的 0，未验证实际登录账号切换。

### 中间失败与检查方法修正

- 首次重开 prepare 在 official-res 下载失败，Runtime 未创建；独立记录 `b6-persistent-prepare-failure.json`。已知准备失败后只重试一次，成功启动；没有用旧 dist 或改变网络/凭证/构建配置。
- 最初采证脚本错误按业务 revision 选银行。第 5/6 代业务 revision 均为 4，导致采证显示 brewing，但实际 UI 已恢复 pending。修正为校验 commit generation、side、字节长度及摘要选取，与游戏 SaveSystem 一致。原 p-before/p-closed 的全部原文件哈希与修正时完全相同，才补正记录中的 snapshot，且在 JSON 写明 evidence_correction；没有改存档或掩盖失败。
- CLI 脱敏把游戏 tokenId 当敏感文本处理，长启动 JSON 被截断。改读当前会话唯一原生 Lua JSONL 的 m 字段，要求精确槽名匹配，解析完整快照；这些日志只在本地保留，不发送公开工单。
- 部分 shell 检查受沙箱限制：窗口句柄不可见、隔离测试临时目录 PermissionError；在当前授权下以受审查的本机执行完成，未扩大游戏读写目录。最初受限 LSP 的 0 警告不作为最终依据；完整扫描曾发现探针布尔类型警告，改为显式 `== true`，最终 2026-10-04 12:34:34 为 0 Error/0 Warning/0 Hint，见[诊断](../../logs/b6-persistent-final-lsp/lua_diagnostics.log)。诊断进程已停止。
- `run_b1.py --b6-acceptance` 最终通过：真实入口/跨天/调试读写/ReloadCurrent 同槽、默认槽 canary 不变，见[日志](../../logs/b6-persistent-entry-test.log)。该项是隔离适配器检查，与真实 V13 分开。
- 8 份留存 native Lua 日志扫描无 ERROR/stack traceback。引擎启动仍报已知 Cube/Day/DaySpecularHDR.dds、themis_x64.dll 资源消息，因此 CLI check/run 最终 result=FAIL，**不宣称整个引擎日志或全部预览检查通过**；本轮存档结论来自实际窗口、提交文件与完整状态比较。

### 边界

玩法系统与正式配置未改，project/settings/resources 及验收开关最终哈希与之前相同；原版安装未变。未提交、推送、远端构建，也未更新公开工单。正式官方持久支持仍待回复；本机候选只通过正常关窗路径，不代表强杀/断电、跨用户/机器、移动端、并发与缓存长期回收。P 重开后的 Reset 另分支及 A1～A19 全量仍未重验。

最终六份交接文档的 102 个本地文件链接有效，git diff --check 通过；data/.project 差异和暂存区为空。既有主页图与 2026-10-02 未跟踪预览文档哈希保持原值；并行文案文件保留。窗口与本轮 LSP watcher 已结束，未保留本轮后台服务。
