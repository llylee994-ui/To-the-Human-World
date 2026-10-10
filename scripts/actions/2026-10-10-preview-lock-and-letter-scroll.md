# 标准预览锁文件与剪词滚动修复、双端交付

## 状态与情况

In Progress。用户明确要求修复编辑器开着时标准Maker预览复制锁文件失败、剪词后滚动跳动，并提交到Maker和GitHub。继续遵守后台测试要求，不启动前台Runtime、不移动鼠标，不关闭编辑器。

起点fengyycon@5c39738；fetch后两端main没有新增提交。工作区保留上一轮移动前端修改、其他窗口的方向核查文档和美术资源。当前Maker全局CLI与活动MCP均0.0.36。隔离工具已有只针对本机绝对路径的绕过，标准工具未修；本轮不引入隔离持久化补丁，不改应用方向或玩法数值。

## 实施措施

1. 使用diagnosing-bugs的可重复验证方法：真实Windows锁下提取并执行标准copyTree；剪词真实按钮回调对内容树/失败路径回归，沿用此前已观察的原生不跳动证据并注明边界。
2. 对标准预览prepare阶段精准排除本工程的scripts/layout-editor/.local，保持取消、符号链接拒绝及其他复制错误；提供版本校验、备份和回退脚本，不编辑编辑器数据。
3. 核对并补齐剪词局部刷新，避免成功或可恢复失败时重建滚动内容；保留现有保存事务、已确认规则与词卡交互。
4. 完整LSP与相关回归；标准CLI仅prepare（不启动Runtime）。复用干净main交付worktree，通过Maker官方入口提交/构建，再同步GitHub同一提交。
5. 仅提交本轮和上一轮尚未交付的程序修复及相关行动记录；保留其他窗口尚在编辑的设计/美术文件。双端SHA、构建结果、未完成验收写入回执。

## 影响文件树

- scripts/debug/maker_preview_lock_fix.py、maker_preview_lock_fix.md：本机标准Maker 0.0.36的可回退兼容补丁与安装/检查说明，不含绑定或凭证。
- scripts/debug/test_maker_preview_lock_fix.py、probe_editor_preview.py：真实锁、排除边界与取消回归；独立真实编辑器保持运行时执行标准prepare。
- scripts/ui/PlayModel.lua、PlayView.lua：沿用上一轮词卡前端，补齐剪词局部刷新。
- scripts/debug/MobileFrontendTest.lua、fixtures/HeadlessUI.lua：剪词连续操作及失败回归。
- scripts/main.lua、debug/DeveloperMode.lua、DebugPanel.lua、PlayFlowTest.lua、run_b1.py：上一轮未提交移动入口与回归随本批交付。
- scripts/actions/2026-10-09-mobile-frontend.md及本记录：状态、证据和交付回执。
- 项目外已安装Maker dist/maker.js：仅安装精确复制过滤补丁；备份位于忽略的.tmp/preview-lock-20261010，不进仓库。

## 自验证方法

补丁前后同一真实锁复制测试；标准preview prepare及编辑器健康接口；连续剪词/写入失败/待确认与确认回归；完整Lua LSP；git diff --check；双端只读SHA核对。后台UI替身不作为视觉或手机验收。

## 自验证结果

### 问题复现与修复

- 标准copyTree在真实Windows字节锁下稳定报EBUSY；原版未排除编辑器工作目录。补丁在prepareProjectCopy传入精确排除路径，在copyTree递归前跳过；其他.local目录仍复制，其他锁错误和取消不被吞掉。路径比较使用平台path.relative，修正了首次测试发现的Windows大小写差异。
- 上轮局部刷新已覆盖成功剪词，但保存失败时仍重建信纸；新按钮回归先实际失败于“剪词失败也保留信纸和按钮”。本轮让可恢复失败也局部刷新；锁定/损坏状态仍走完整错误界面。固定提示区高度，长提示可独立滚动，避免提示换行挤压信纸。未改保存或结算协议。

### 本机检查结果

- `python -B scripts/debug/test_maker_preview_lock_fix.py --original-bundle <原0.0.36 bundle> --node D:/node.js/node.exe`：6项通过；包含原版EBUSY复现、补丁后复制成功且不带.local、其他.local保留、其他锁失败、取消、重复安装/回退/未知版本拒绝。证据`logs/2026-10-10-lock-regression.log`。
- 已安装至活动MCP的`C:/Users/YINGYI/.taptap-maker/mcp-runtime/0.0.36/dist/maker.js`和全局CLI的`C:/Users/YINGYI/AppData/Roaming/npm/node_modules/@taptap/maker/dist/maker.js`。原SHA见安装说明，补丁后两份均为`a8283b077655fff21a940f23a7cd106d4d65911c51d62adfd752212cff087504`。备份`.tmp/preview-lock-20261010/`保留，未提交安装包。
- 标准CLI `preview prepare --target-dir D:/taptap/To-the-Human-World --json`成功，entry main.lua。随后`probe_editor_preview.py`在独立真实编辑器保持运行/持锁时再次prepare通过；编辑器健康身份前后一致，server.py和main.lua完整，准备副本无.local。证据`logs/2026-10-10-editor-open-probe.log`、`2026-10-10-editor-open-prepare.json`。默认18765端口未发现健康服务，因此采用独立随机端口和临时数据验证，没有假称操作了用户当前编辑器。
- `run_b1.main([], 'debug.MobileFrontendTest')`通过：连续剪全部词、可恢复失败重试保留同一内容树与按钮、没有主动滚动复位，主辅槽、待确认、重置/读档、确认保存失败、重复确认均通过。日志`logs/2026-10-10-scroll-green.log`。替身不证明像素坐标；上一轮实际窗口“剪后位置不变”证据继续保留，本轮未重开窗口。
- `run_numeric_v02.py --startup`及`--shop`通过；旧内容快照3dbca09的PlayFlowTest按钮172项/准备104项通过；编辑器存储unittest通过。日志前缀`logs/2026-10-10-`。
- 全scripts LSP：0 Error、15个既有Warning、1 Hint；`logs/2026-10-10-fix-lsp/lua_diagnostics.log`。git diff --check通过。预览status为stopped/process_alive=false，全程无前台窗口或鼠标操作。

### 交付范围与边界

本轮携带上一轮已授权、尚未提交的玩家入口/触屏词卡修复；其他窗口的方向核查、素材及资源删除不纳入本批。代码提交并不把手机方向、最终布局、正式美术和P/R/C真机恢复标为通过。标准Maker资源准备锁问题已修，本机工具升级后需重新检查兼容补丁。

双端提交/构建回执：Pending。
