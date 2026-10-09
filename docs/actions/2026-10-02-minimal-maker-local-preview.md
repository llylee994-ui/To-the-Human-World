# 最小 Maker 配置与本地预览验证

## 状态与背景

- 状态：Completed（配置调整与本轮验证已完成；Maker check 失败、正常退出回调未证实，详见结果）。
- 来源：用户要求执行「仅保留 project_id 的一行配置，验证本地预览启动、自检和退出」。
- 工程：`D:\taptap\To-the-Human-World`；项目 ID 为 `76909fb8-3dc3-4adc-8c49-fe56bab4393e`。
- 配置原本已经只有 project_id，为三行无 BOM JSON；本次仅压成一行。
- 使用客户端配置的 Maker 0.0.36 与 Node `D:\node.js\node.exe`，遵循安装包内 taptap-maker-local 技能。
- Runtime 已安装，已有当前工程的存活预览会话。更新后刷新该会话并取本轮日志，再停止。
- 本机存在 Maker 登录信息；本轮不修改凭证，不能把运行成功称为无登录环境隔离测试。官方本地流程说明单机预览无需 PAT。
- 范围：本地配置和运行验证，不修改游戏逻辑，不绑定项目，不提交或远端构建。

## 实施措施

1. 保持项目 ID 不变，将配置改为一行无 BOM JSON。
2. 查询预览状态，刷新存活会话；资源准备可能使用已安装工具链和公共资源缓存。
3. 获取本轮 logs / check，核对启动、自检和布局自检。
4. 使用 preview stop 停止会话，核对退出日志及 process_alive=false。
5. 复查配置及 Git 改动，保留用户原有文件，记录结果及限制。

## 影响文件树

- `.maker-mcp/config.json`：本地项目标识，被 Git 忽略，仅调整 JSON 排版。
- `docs/actions/2026-10-02-minimal-maker-local-preview.md`：本轮措施与验证记录。
- 会话、日志和准备产物由 Maker 在用户目录管理，不属于游戏代码变更。

## 自验方法

- JSON 解析、行数和 BOM 检查：只有 project_id，值不变，物理行数为 1，无 BOM。
- CLI 入口：`& 'D:\node.js\node.exe' 'C:\Users\YINGYI\.taptap-maker\mcp-runtime\0.0.36\dist\maker.js'`。
- 所有预览命令携带 `--target-dir 'D:\taptap\To-the-Human-World' --json`。
- 依次执行 preview status、存活时 preview refresh、preview logs、preview check、preview stop、preview status。
- 期望日志包含启动完成、自检最终累计「通过 12，失败 0」和退出完成；实际核心逻辑自检为 11 项，布局检查再增加 1 项。同时保留引擎错误，不能把进程存活当作游戏验证通过。
- 当前工具不支持有效的纯 UI 截图证据，本轮不声称已完成视觉验收。

## 自验结果

验证日期：2026-10-02（Asia/Singapore）。

- 配置检查通过：物理行数 1，唯一键 project_id，ID 未改变，无 UTF-8 BOM。
- preview status：确认已有当前工程会话存活，按规则刷新；没有另起重复会话。
- preview refresh：退出码 0，资源准备成功，reload_id 从 2 增至 3，新 Runtime PID 为 40980。会话 ID：5c8a5dee-3bb1-4e10-972b-1653802340e7。
- preview logs：限定上述会话及 reload_id=3，退出码 0，最终 cursor=402，truncated=false。
- 游戏启动：16:46:49.412 日志显示「寄往人间 启动完成（第 1 天）」。
- 核心自检：事件总线 4 项、存档系统 4 项、游戏流程 3 项，共 11 项通过、0 失败。
- 界面布局：safeArea / mainPanel / titleLabel / dayLabel 尺寸均非零，布局作为第 12 项通过；16:46:49.906 最终汇总「通过 12，失败 0」。
- preview check：实际退出码 1，result=FAIL，reason="Runtime reported a failure."。两条引擎错误刷新前后均存在：
  - Could not find resource Cube/Day/DaySpecularHDR.dds
  - Can not load themis_x64.dll.
  这两条错误未阻止本轮游戏启动与 12 项自检，但不能因此宣称引擎检查通过或错误无害；本轮未修复共享 Runtime。
- preview stop：退出码 0，state=stopped、process_alive=false；随后 preview status 再次确认已停止。
- 临时缓存 C:\WINDOWS\TEMP\maker-cache-a1vc1Q 已不存在，由 Maker 自行清理。
- 退出验证限制：本轮日志没有「寄往人间 已退出」，最后一条仅为不完整的时间戳；结果 JSON 没有 exit_code/exit_signal。能够证明 CLI 停止成功、进程结束，不能证明游戏 Stop() 回调及正常退出码。按停止规则未自动重新打开窗口。
- 权限验证限制：本机存在 PAT/登录，本轮没有注销或隔离账号。官方本地技能说明单机预览不需要 PAT；本轮 preflight.network_required=false，运行日志 IsNetworkMode=false、userId=0。未单独实测空登录环境，不能将这些证据扩展为任意机器或联机功能均无需权限。
- 网络边界：本轮确实下载公共引擎索引、资源包，因此「不需要项目权限」不等于「完全离线」。
- 视觉验收未运行：screenshots_supported=false，布局测试不等于画面截图验收。
- 无 Lua 代码修改，未重新执行 LSP 诊断；git diff --quiet -- scripts 通过，git diff --check 通过。原有 3 个 scripts/ 未跟踪文件未修改，Git 新增项只有本行动记录。
- 未执行 init、登录、提交、推送或远端构建。

持久证据：

- 本地会话日志：`C:\Users\YINGYI\.taptap-maker\preview\7ec99854c054b7dea8c25d1a7496bd962dc0baeb0e2bcdbed56fea7592fe023b\sessions\5c8a5dee-3bb1-4e10-972b-1653802340e7\3\runtime.log`。
- 停止状态：同目录 `result.json`；准备日志：同目录 `prepare.log`。
- 游戏启动证据 cursor=396，最终自检证据 cursor=401，引擎错误 cursor=38/39。

结论：最小配置可在当前机器启动本地预览，游戏自检 12/12 通过，CLI 停止成功。Maker check 全通过、游戏优雅退出回调及空登录环境不在本轮已证实结果之内。

- 初始沙箱写入被文件系统拒绝，未改配置；通过宿主权限流程重试既有授权范围内的配置和记录写入。
