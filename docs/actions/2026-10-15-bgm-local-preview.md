# BGM 分支本地试听启动

## Status and situation

Completed（本地窗口已打开，原生接口误判的无声问题已修复并通过专项回归；重新启动后用户确认“有声音了”，三个页面的完整切换试听未逐项确认）。用户要求本地打开 `feat/scene-bgm`，由用户试听主页、捞漂流瓶和商店 BGM；不合并 main。

- 工作目录：`D:\taptap\To-the-Human-World-bgm`，提交 `ba9b81db4a3e789f118944df2f20f868313cc07d`，启动前工作区干净。
- 官方 Maker CLI 0.0.36 的首次 `preview status` 返回缺少 `.maker-mcp/config.json`，未启动游戏。
- 原项目归档 `To-the-Human-World/.maker-mcp/config.json` 经清单 SHA256 验证，项目标识为 `76909fb8-3dc3-4adc-8c49-fe56bab4393e`；与已有最小预览配置行动记录一致。仅恢复必需的 project_id，不复制凭证或旧存档，不运行 init。
- 初始启动阶段不修改游戏代码；确认无声后仅按下项范围修复。始终不修改音频素材、分支历史或 main，不推送或远程构建，不自动操作捞瓶/购买，不清空玩家存档。按游戏现有本地存档行为运行，不声称官方预览隔离了存档。
- 启动后用户反馈主页没有声音，范围扩展为修复本次 BGM 的原生播放问题。仅允许音乐控制器、其专项回归和本记录的必要调整；保留 main 边界，不自动提交或推送修复。

## Implementation measures

1. 在被 Git 忽略的 `.maker-mcp/config.json` 写入已经核实的原项目标识，查询当前目标的会话状态。
2. 复用已安装官方运行器，通过用户预览 `preview start` 启动，交由控制台持有进程，供用户保持窗口试听。
3. 收集当前会话的 status、logs、check 和可用窗口证据，核对游戏启动与 BGM 资源异常；不以进程存活代替用户听感验收。
4. 保持窗口打开，核对 Git 改动范围，更新本记录。
5. 对用户确认的无声问题，先以引擎全局接口 getter 的隔离场景建立可失败回归，再加一次定点原生日志区分原因；修复并移除临时日志后重跑专项检查并刷新窗口。最多两轮原生刷新，不调整系统音量、不操作游戏业务按钮。

## Affected file tree

- `.maker-mcp/config.json`：新增本机预览项目标识，被 Git 忽略。
- `docs/actions/2026-10-15-bgm-local-preview.md`：本次启动行动与实际结果。
- 官方 Maker 用户目录下的预览准备产物、会话及日志：由 CLI 管理；不属于功能提交。
- `scripts/ui/landscape/SceneMusic.lua`、`scripts/ui/landscape/tests/SceneMusicTest.lua`：追加无声问题的定点诊断、最小修复与回归。

## Self-verification method

使用明确 `--target-dir` 的官方 `preview status/start/logs/check`。检查会话身份、当前 Lua 启动日志、音频资源错误与实际窗口状态；保留引擎警告和未验证边界。最后核对分支、HEAD、原游戏代码及资源无变更。

## Self-verification results

首次 status 的错误为缺少本地预览配置；补齐后官方预览成功启动，session `346ae13b-7243-498e-9b7f-e6ddf2b533fe`、reload 0、PID 708。Windows 已确认可见且未最小化的“寄往人间”窗口，日志有“启动完成（第 1 天）”。用户实际反馈主页没有声音，不能将启动成功计为 BGM 验收通过。`preview check` 因既有 Cube/Day/DaySpecularHDR.dds 与 themis_x64.dll 缺失而 FAIL；没有新增 BGM 报错。

### 无声问题诊断与修复

- 反馈回路：`python -X utf8 -B scripts/ui/landscape/tests/run_scene_music.py`。先将音频接口替身改为通过 `_G.__index` 提供，真实主页导航立即在 `initial homepage plays hearth` 断言失败。随后只保留真实 SceneMusic 模块、getter 绑定与播放调用的最小场景，两次均得到 `played=false`。
- 候选原因按顺序为全局接口被误判不存在、音频资源载入失败、播放后的设备输出问题；用一次定点原生日志区分前两者。
- reload 1（PID 4876）在 2026-10-15 18:57:37（Asia/Singapore）的实际日志为 `Node=table rawNode=table cache=userdata rawCache=nil`。确认 `cache` 是引擎 getter 提供的接口，`rawget(_G,"cache")` 绕开 getter 得到 nil，导致旧 guard 在加载音频前直接返回。
- 最小修复：以正常的 `Node`、`cache` 全局访问判断可用性；保留真正无引擎的隔离环境兼容。没有更改曲目、音量、播放速度或音乐切换规则。
- 修复后音乐专项 93 项断言通过；最小复现场景连续两次得到 `played=true`。`git diff --check` 通过；临时 `[DEBUG-bgm-native]` 日志已从代码移除。
- reload 2（PID 7388）已加载修复源码，日志显示 18:59:21 “启动完成（第 1 天）”；同轮日志未发现 SceneMusic 错误。预览准备副本中的控制器和两份 WAV 与工作目录逐份 SHA256 一致。
- 最终 Windows 核对：PID 7388 的窗口标题为“寄往人间”，窗口句柄 4526024，Responding=true。最终 `preview check` 仍因上述两项既有运行器缺失报 FAIL；不将本轮 BGM 修复说成引擎整体检查通过。
- 本轮共执行两次明确的原生刷新；刷新前均核对会话仍存活，没有关闭后擅自重新启动。最终窗口保持打开，供用户自行测试主页、海边和商店。实际输出听感待用户复核，不以隔离断言替代试听结论。
- 修复仍是 `feat/scene-bgm` 上的本地未提交改动，远端提交仍为此前的 `ba9b81d`；本轮没有提交、推送、合并 main 或 Maker 远程构建。
- 运行证据目录：`C:\Users\YINGYI\.taptap-maker\preview\d9f4dff0b5beffc12d421b30abf88245a3983726351ef993162fae8999eae067\sessions\346ae13b-7243-498e-9b7f-e6ddf2b533fe`；0/1/2 分别保存最初启动、临时诊断和修复后本轮日志。

### 用户要求重新启动

- 用户明确回复“重新启动一次试试”。启动前 status 显示上一会话已停止；按此次授权重新运行官方 preview start，没有新增游戏代码或资源修改。
- 新 session 为 `cb381210-f529-401d-8417-704f97ffcd3c`、reload 0、PID 42500。Windows 已确认运行器窗口存在且 Responding=true；日志于 2026-10-15 19:06:54（Asia/Singapore）显示“寄往人间 启动完成（第 1 天）”。
- 当前会话日志没有 SceneMusic 错误；preview check 仍因前述两项既有运行器缺失报 FAIL。此次仅验证重新启动，实际声音和页面切换仍待用户试听，未重跑代码测试。
- 窗口保持运行；无提交、推送或合并 main。新运行证据在同一 preview 根目录的 `sessions/cb381210-f529-401d-8417-704f97ffcd3c/0`。

### 有声确认与本地提交

- 用户在重新启动后确认“有声音了”；仅记录声音已恢复，不推断三个页面切换都已验收。
- 用户随后要求先在此分支本地提交，再开发音乐设置。提交前再次运行 `python -X utf8 -B scripts/ui/landscape/tests/run_scene_music.py`，93 项断言通过（缺失音频日志来自预期故障夹具）。本次提交只包含控制器修复、getter 回归和本记录，不推送、不合并 main。
