> 2026-10-12 原生阶段更新：本文件以下为历史核查原件。独立应用绑定与官方现有登录缓存更新均已明确获授权并成功完成，Runtime已运行。当前仅Library参考传递、公共资源错误与人工/手机证据缺口；详见REPORT和NATIVE_ACCEPTANCE。首次Runtime安装目录日志/缓存副作用已记录，后续已改为Lab内运行副本。

# 独立应用绑定授权后的预检 · 2026-10-12 UTC

同一任务 `01a12c24-a725-712b-ba7d-df58430f5098`。已接受新增授权：只为 `D:\taptap\To-the-Human-World-3D-Lab` 配置独立 Maker 应用绑定。**不再把“用户未允许独立绑定”当作阻塞。** 正式工程/绑定保持只读；额外安装、创建持久凭据、发布、远程构建、系统输入及额外执行任务仍未授权。

## 当前实际状态

- CLI 仍为 @taptap/maker 0.0.36；试验目录未绑定，未执行 init，未创建远端试验应用。
- 官方 `apps --json` 查询成功，当前返回 1 个应用“寄往人间”；没有独立试验应用。不会选择或复制正式身份。新建选项为 `0 / new — Create a new Maker project`。
- 现有授权缓存存在，但没有读取或输出其内容。`TAPTAP_MAKER_HOME` 未设置，默认缓存根为 `C:\Users\YINGYI\.taptap-maker`。
- 初次 doctor 报 `spawnSync git EPERM`、Python missing。绝对 Git/Python 路径在沙箱内的 Node 子进程检查也报 EPERM，而 PowerShell 直接调用可用。
- 经自动审批允许的只读检查，在原有 Node 中查询现有程序，Git 2.52.0.windows.1 / Python 3.13.2 均退出 0。之后官方 doctor 使用进程级 `TAPTAP_MAKER_GIT_BIN`、`TAPTAP_MAKER_PYTHON_BIN`，确认 Git、Python、LSP 全部 ready，LSP 0.22.2。**无需安装任何这些软件。** 未改 PATH 或系统配置，未收到自动审批拒绝。
- `maker-doctor-binding-authorized.json` 是新的实际官方 doctor 原件；`binding-preflight-20261012.json` 是脱敏摘要与原绑定哈希。Lab 代码与上一轮 70 项检查的源码哈希仍匹配，本轮未重复跑业务或 LSP 诊断、未修改游戏代码。

## 确定的剩余授权边界

当前官方初始化没有“只写绑定且不保存鉴权”的选项。已经只读核对实际安装文件：

`C:\Users\YINGYI\AppData\Roaming\npm\node_modules\@taptap\maker\dist\maker.js`

`runInit` 约第 77965 行，步骤为：

```javascript
ensureInitPythonReady(ctx, targetDir, env);
const pat = await resolvePat(parsed, ctx);
const tapAuth = await requestTapAuthWithPat(pat, env);
// 之后才列表选择/新建应用、saveProjectConfig、clone、prepareDevKit
```

`requestTapAuthWithPat` 第 33724 行，成功后无条件：

```javascript
const auth2 = normalizeTapAuthResponse(json2);
saveTapAuth(auth2);
return auth2;
```

`saveTapAuth` 第 28605 行通过 `writeJsonFile(getTapAuthPath(), ...)` 写入；`getTapAuthPath` 第 28571 行指向 Maker home 的 **`tap-auth.json`**。因此即使 PAT/tap_auth 已存在，init 仍会换取令牌并把新的鉴权内容写回已有持久缓存：

`C:\Users\YINGYI\.taptap-maker\tap-auth.json`

`--skip-mcp-install` 只跳过后面的 MCP launcher/IDE 配置安装块，不跳过令牌请求或写回；已检查官方 help 与参数处理，未发现 skip-auth/no-save 开关。不能通过改 CLI、假配置、直接调用未暴露的远端 API 或截断初始化来绕过。

技能来源：`C:\Users\YINGYI\AppData\Roaming\npm\node_modules\@taptap\maker\skills\taptap-maker-local\SKILL.md`，Initialization Workflow 原文：

> Run `taptap-maker init` in the user's intended Maker directory. The CLI will request PAT if missing, fetch TapTap token, show a paged app preview, ask the user to choose or create a Maker project, clone the Maker project, prepare the AI dev kit, and install/verify MCP config.

这里的停点来自**用户最新消息明确排除“创建持久凭据”**，以及代码证实必然存在的新令牌持久写回；不是再次请求已经获得的独立应用绑定授权，也不是技能自行增加审批。

## 具体最小追加授权与后续步骤

需要允许：**官方 init 使用现有 PAT 重新换取并写回上述已有 `tap-auth.json` 登录缓存。** 不要求手工提供令牌，不创建新 PAT，不复制凭据到项目，不安装 Git/Python/LSP，不改正式应用身份。

拟用用户任务名 `D3-LAB-20261012` 作为独立试验应用名称，目标严格为 Lab。待上述缓存写回得到明确授权后，在实际执行前再次只读确认依赖 ready，并运行官方路径：

```powershell
$env:TAPTAP_MAKER_GIT_BIN='D:\download\git\Git\cmd\git.exe'
$env:TAPTAP_MAKER_PYTHON_BIN='C:\Python313\python.exe'
taptap-maker init --create --name 'D3-LAB-20261012' --target-dir 'D:\taptap\To-the-Human-World-3D-Lab' --skip-confirm --skip-mcp-install --json
```

上方命令**未执行**。init 会准备项目内官方 dev-kit（当前索引约 29.7 MB）、更新项目内文档/工具库/技能发现目录及 .gitignore；不是远程构建。旧 v01 报告/审查包已归档至 `deliverables/history/2026-10-11-v01`，供随后核对初始化对试验文件的变化。若依赖 readiness 下降，不执行 init，以免它自动安装；若出现新未授权副作用或文件冲突，停在具体步骤，不自动扩权。

绑定完成后仍需官方 prepare 与原生启动实际验证；不能先声称预览已恢复。计划复用现有 Runtime、使用官方支持的进程级 Maker home/TEMP 位置把试验预览产物留在 Lab，验证该准备方式再启动首次试验预览；绝不接管正式预览或重启用户停止的试验会话。

## 独立保留的视觉阻塞与阶段结论

没有发现新的 Library Windows 官方材料化路径，因此本轮没有重新调用失败助手或绕过 xattr。四图仍未在本机查看，文字默认外观仍未验收。

P0 受阻；P1/P3 保留既有离线通过；P2 暂定；P4 无新增原生画面/运行证据。当前没有 init/Runtime/LSP 后台等待，范围内预检已结束；下一步是明确的缓存写回授权或官方无持久写回能力，不能以“仍在实现”掩盖停点。
