# 云端候选 Windows 启动修复

## Status and situation
Completed for launcher migration and read-only verification. 在 d00aca9 的完整 17 次云端提交之后，单独保存 Windows 运行验证中确认的最小启动修复。用户要求仅推送 cloud/3d-d00aca9；不合并 main/3d，不改写云端历史。远端发布结果保存在本机独立恢复记录，不以本文件预先声明推送成功。

运行交付包的 349 个清单文件与此候选逐项 SHA256 一致；本机调试没有改游戏源码。实际故障是官方基础 ZIP 不含 UI 所需 MiSans-Regular.ttf，而本机安装的 Res/Fonts 有该文件。补齐后 Windows 完整场景与 HUD 真实显示。自动交互测试已按用户要求停止，由用户亲测。

## Implementation measures
1. 增加由脚本位置确定工程目录的 Windows 启动入口，只使用现有官方运行器，不下载或安装。
2. 从同一已安装发行 ZIP 校验并复制 8 个完整发行文件及额外官方中文字体到本项目忽略目录，避免账号、缓存或真实存档迁入。
3. 使用本机官方 Maker Windows 参数 scripts/main.lua / -tapcode_dir / -p=Res / -w / -width / -height；不复制 Linux 离屏参数，不修改系统执行策略。
4. 提供 --check 只读验证模式；本轮不再次启动游戏或接管用户鼠标。

## Affected file tree
- Start-Windows.cmd — Windows 双击入口，定位 Python 3。
- tools/run_windows_game.py — 标准库运行器校验、隔离副本与窗口启动；无自动鼠标操作。
- .gitignore — 排除新运行器副本、Windows 输出、进度和下载分片/Blender 大源文件。
- docs/WINDOWS-RUN.md — 前置条件、命令、实际已验证范围与剩余警告。
- docs/CLOUD-CANDIDATE-REPORT.md — 标记原文为云端交付阶段记录，并链接后续 Windows 说明。
- docs/actions/2026-10-14-cloud-windows-launcher.md — 此修复的执行和验证记录。

## Self-verification method
Python 语法检查；--check 核对本机发行版本、ZIP/安装文件一致性、字体与项目入口；git diff --check；暂存路径、敏感文件与新增 blob 大小检查。复用已记录的 Windows 实际场景结果时明确这是先前运行目录的验证，不宣称本克隆被重新试玩。

## Self-verification results
- PASS：`python tools/run_windows_game.py --check`；完整核对已安装 Windows build 20260923-1717-bf3316f、8 个官方 ZIP 文件、MiSans 字体，输出正确的新克隆 cwd 与 Windows 参数，launched=false。
- PASS：Python AST 语法检查；检查后 `.runtime-windows` 和 `.windows-runs` 均未创建，未再启动游戏。
- PASS：`git check-ignore --no-index` 对运行器、运行日志目录、内存槽命名的潜在磁盘存档、ZIP 分片、Blender 源文件全部命中忽略规则。
- PASS：`git diff --check`；本次不修改游戏 Lua、场景、美术或原 17 次提交。
- 开发中首轮 --check 发现 UI 入口误写为 urhox-libs/UI.lua；按仓库实际目录修正为 urhox-libs/UI/init.lua 后通过。一次 stdin 形式忽略检查的辅助断言失败，改为显式路径参数核对通过；未因此更改游戏。
- NOT RUN：本克隆真实窗口及交互；用户已要求亲自测试，保持其当前运行窗口与鼠标不受干扰。便携启动脚本的实际启动步骤尚未在此克隆重新运行，既有 Windows 场景证据仅描述先前运行目录。
