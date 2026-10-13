> 2026-10-12 原生阶段更新：本文件以下为历史核查原件。独立应用绑定与官方现有登录缓存更新均已明确获授权并成功完成，Runtime已运行。当前仅Library参考传递、公共资源错误与人工/手机证据缺口；详见REPORT和NATIVE_ACCEPTANCE。首次Runtime安装目录日志/缓存副作用已记录，后续已改为Lab内运行副本。

# 官方支持路径核查

版本：D3-LAB-20261012-r3-v01。执行环境为用户 Windows 本机，非云端 D 盘映射。全部试验输出在独立目录。

## B1：Library 直接解析引用的 Windows 材料化

使用当前 Library 技能的 `references/materialization.md`，不是搜索结果下载路线。调用 `prepare_materialize`，指定用户给出的五个 `library_file_id`，目标 `D:\taptap\To-the-Human-World-3D-Lab\references\incoming`。返回五个完整 transfer，`workspace_path:null`，带 `download_url`、版本 0 和 `user.library-file-version` 元数据。没有把云路径当作本机路径。

技能原文：

> Otherwise choose an absolute destination under the workspace or at the path the user requested. Pass the complete transfer object—not the outer transfers object, a content block, or the URL alone—to the helper.

> The helper uses returned headers, downloads the bytes, applies and verifies all xattrs, persists `library_file_id` as `user.library-file-id`, and atomically installs the destination. Invoke it once per signed-URL transfer. Never use raw `curl`.

当前官方助手从技能同包 `scripts/library_file_transfer.py` 读取并原样保存；没有改助手、检查其实现、构造 URL、手工下载、补假元数据或重新上传输入。调用方式为每个完整 transfer 通过 JSON stdin 传入：

```powershell
$transferItem | ConvertTo-Json -Depth 30 -Compress |
  python D:\taptap\To-the-Human-World-3D-Lab\tools\library-current\library_file_transfer.py materialize <对应本机绝对目标文件>
```

先调用任务文本；随后为明确图片字节状态，四张 PNG 各调用一次。四张图均在助手 `materialize -> apply_xattrs -> xattr.apply -> os.setxattr` 失败：

```text
AttributeError: module 'os' has no attribute 'setxattr'
```

完整未截断 traceback 分别保存在 `materialize-libfile_*.log`。事后实际枚举 `references/incoming`，目录为空；各目标文件不存在，无可读 PNG 字节或残留临时文件可供查看。不能仅凭 xattr 错误推断网络没有传字节；本记录只确认调用结束后没有可使用的本机文件。`reference-map.json` 保存每个附件的真实名称、ID、版本、期望本机路径和存在性检查。

Library `read` 的 image_file 返回的是图像指针和描述，不是本机可查看的图像内容。本执行者未查看四张图的像素。主会话转述不替代本机验收。此次没有返回不存在的 workspace_path，故未触发“明确本机路径重试一次”的分支；对已证实的同一兼容性故障没有盲目重试。

需要的最小修复：Library 提供支持此 Windows 环境的官方材料化/元数据写入路径。修复后仍使用这五个现有 ID，不重传输入，材料化后逐张查看、记录哈希并修正外观。

## B2：Maker 0.0.36 要求绑定，受管理准备不免除绑定

实际命令：

```powershell
taptap-maker preview status --target-dir D:\taptap\To-the-Human-World-3D-Lab --json
taptap-maker preview prepare --target-dir D:\taptap\To-the-Human-World-3D-Lab --json
```

二者返回的完整错误（prepare 原件为 `preview-prepare-initial.json`）：

```json
{"ok":false,"protocol_version":1,"result":"FAIL","error":"Error: Preview requires a bound Maker project with .maker-mcp/config.json.","artifacts":[]}
```

实际安装技能：`C:\Users\YINGYI\AppData\Roaming\npm\node_modules\@taptap\maker\skills\taptap-maker-local\SKILL.md`，Local Window Preview 原文：

> Use the active distribution's Maker CLI and the current real Maker project absolute path as `--target-dir`; never guess a business project from the dialogue directory.

> Start/refresh prepare a managed copy automatically; `preview prepare` diagnoses preparation alone. Platform support, installation recovery and cache behavior are documented in `docs/MAKER_LOCAL_PREVIEW.md`.

技能没有声明未绑定独立目录可直接运行。其引用的本地官方文档 `docs/MAKER_LOCAL_PREVIEW.md` 第 24 行：

> `<PROJECT>` 为已绑定 Maker 游戏的绝对目录。插件用户使用当前插件内 CLI。

同文档第 40–44 行：

> 新项目缺少 `.project` 配置时，prepare 仅在受管理副本补齐 project/resources/settings，
> 无需先远端构建或生成二维码。入口缺省 `scripts/main.lua`，不存在时明确提示；
> 缺省版本 `1.0.0`，资源扫描 scripts/assets，公共来源使用官方 stable 配置。
> 临时项目标识优先使用本地绑定 ID，临时作者标识为 `local-preview`，不代表 TapTap 平台身份。
> 已有配置及资源元数据保持优先；配置损坏不以默认值掩盖。

只读核对当前已安装 `dist/maker.js` 的 `previewProject(targetDir)`（约第 43582 行），在读取真实路径后立即执行：

```javascript
if (!fs23.statSync(project).isDirectory() || !loadProjectConfig(project)) {
  throw new Error("Preview requires a bound Maker project with .maker-mcp/config.json.");
}
```

CLI help 没有免绑定的隔离预览开关；现有 Runtime 已安装也不会跳过这个入口。文档的 `.project` 默认配置准备与 `.maker-mcp/config.json` 绑定是两项不同前提。结论限于实际安装的 0.0.36：未找到无需绑定的官方隔离预览路径。

用户明确禁止复制/新建/修改应用绑定，所以没有执行 init、复制正式配置、伪造身份、直接启动 Runtime 或远端构建。尚无试验预览会话，不存在可刷新或可获取运行帧的试验进程。没有自动重启用户停止的预览。

需要的最小修复：获得明确支持未绑定独立目录、且输出限本试验目录的官方预览能力。只有用户明确调整绑定或输出授权边界时才重新评估其他方案；本轮不自行调整。

## 其他能力

- Windows 系统 Python 3.13.2 可用；现有项目的 Lupa Lua 5.4 二进制仅复制到 Lab 使用，无安装。
- Maker `lua-lsp doctor` 初报 `python_missing`，但已找到现有 `lua-lsp-venv` 和 EmmyLua 二进制，用有界 stdio 客户端完成真实 LSP 诊断，无安装或系统配置修改。诊断文件另附。
- Maker `mcp verify` 尝试准备其用户目录 runtime 时遭遇 EPERM，未提权或重试，不归因为游戏代码错误。未收到自动审批拒绝。
- 当前工具列表无 Maker MCP 和 `create_3d_asset`；没有资源生成任务、计费或审批等待。没有操纵系统输入或其他窗口。
