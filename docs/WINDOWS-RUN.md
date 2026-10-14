# 完整 3D 候选：Windows 本机启动

此分支保留从 `65e640cafc3330e70c0d934404077ad98932603f` 到 `d00aca9c4874117fcc924625820cf43a20c44936` 的完整 17 次云端提交，Windows 启动修复另做提交。游戏入口仍为 `scripts/main.lua`，旧个人目录启动器已清理。

## 启动

需要已有 Python 3.9+ 和官方 Maker Windows Runtime `20260923-1717-bf3316f`（PE 版本 `1.32.14.0`）。不需要安装额外 Python 包。

1. 双击仓库根目录的 `Start-Windows.cmd`，或运行 `python tools/run_windows_game.py`。
2. 脚本在当前用户 `.taptap-maker/runtime` 中寻找匹配版本。如有多份匹配，可把环境变量 `URHOX_RUNTIME` 指向所选官方安装的 `UrhoXRuntime.exe`。
3. 脚本核对原始 ZIP 与安装文件，再复制完整发行文件到本项目 `.runtime-windows`。不复制账号、User、缓存、旧日志或玩家进度。
4. 基础 ZIP 不包含所需的 `Res/Fonts/MiSans-Regular.ttf`，因此还从同一官方安装目录复制并核对该字体；字体缺失时明确停止。

发行文件和字体已存在时必须哈希一致，脚本不会覆盖不一致的文件，也不会下载或安装运行器。缺少前置条件时先解决安装来源；不要替换成不明运行器。每次启动会开一个独立窗口，避免重复双击。

只核对本机条件、不复制文件也不启动：

```text
python tools/run_windows_game.py --check
```

实际命令由启动记录给出，工作目录是脚本所在仓库根目录：

```text
<repo>/.runtime-windows/UrhoXRuntime.exe scripts/main.lua -tapcode_dir=<repo> -skip_login -p=Res -w -width=1170 -height=658
```

这组参数来自已安装的官方 Maker CLI Windows 启动实现，不含 Linux surfaceless/软件渲染参数。无需更改 PowerShell 执行策略或关闭安全软件。

## 进度与日志

入口经 `FullSceneHost → Integration → Bootstrap` 固定使用 `MemoryStorage.New()`，槽名 `d3_lab_v035`。`save_d3_lab_v035*.json` 与 `.commit` 只是内存表键，不写磁盘，不读取正式玩家存档。关闭后进度重置。

本次启动的 `launch.json`、`stdout.log`、`stderr.log` 位于 `.windows-runs/<时间>/`，引擎自己的日志与缓存位于 `.runtime-windows`。这两个目录已忽略，不应提交。运行器、字体二进制、下载分片、存档和 Blender 大源文件不随本次 Windows 修复发布。

## 已验证范围与限制

2026-10-14 已在独立解压运行目录实际显示相同的候选场景和中文 HUD：Windows / RTX 4060 Laptop GPU / Direct3D 11，1170×658。场景加载约 53.11 秒；主页约 20 秒采样加权 82.39 Update FPS（不是 GPU profiler），当时进程工作集峰值约 1.95 GiB。100 模型、3,208,608 三角形、870 绘制对象。运行目录的 349 个清单文件与恢复候选逐项 SHA256 相同。

OS 截图确认桌面 DAY/金币瓶移除、架子四种原料可见、日期/金币/提示/结束当天 UI 保留。最初缺字体导致文字空白；补齐上述官方字体后恢复。用户随后要求自行测试，因此 8 个入口与完整业务流程未做完独立验收。本次仓库恢复只检查启动脚本，不重新接管用户窗口；先前场景证据不能当作此便携脚本已再次启动的证明。

仍有 `Cube/Day/DaySpecularHDR.dds`、`Cube/Dusk/DuskSpecularHDR.xml` 和 `themis_x64.dll` 缺失日志。场景能够显示，尚未确认这些项对其他行为的影响；没有删除安全组件或擅自调整美术。云端报告所列阴影、玻璃、花瓣和手机验收限制仍有效，见 [CLOUD-CANDIDATE-REPORT.md](CLOUD-CANDIDATE-REPORT.md)。

## 2026-10-14 清理后的本克隆验证（优先于上节历史运行目录记录）

本克隆由 `tools/run_windows_game.py` 实际启动官方 Windows Runtime，PID 34996；真实窗口截图见 [本次完整房间](evidence/cleanup-20261014/windows/00-home.png)。场景加载 62.263 秒，主页 25.03 秒采样加权 84.10 Update FPS，采样期间峰值工作集 2,193,747,968 字节（2.04 GiB）。FPS 为引擎 Update TimeStep，非 GPU profiler，不能替代操作流畅度验收。

实际鼠标已确认抽屉打开“来信抽屉”以及关闭回到房间。绿色本子点击后的截图仍为主页，未确认命中；随后采集工具因未获得焦点停止，没有发送后续点击。用户明确要求自行测试验收后，代理已停止输入，未再关闭、重启或接管窗口。其余 7 个入口、提示气泡、返回主页按钮、结束当天、扣金币和漂流瓶阅读均待用户验收；HUD 日期与金币显示已看见，不代表对应业务变更已测。

当前 164 项资源哈希和 147 个静态 Lua 依赖文件通过；当前源码与资源未改动。详细时间、点击、截图和原始日志见 [本次验证记录](evidence/cleanup-20261014/windows/verification.json)。本机已有环境警告仍存在，未发现清理引起的资源哈希缺失；阴影、玻璃和花瓣美术问题未调整。

## main 历史整合

`integration/3d-main-20261014` 保留本说明的 3D 启动器、入口及资源原字节，同时将 main `41cdaf3` 纳入祖先关系。合并后运行行为未迁到 main 的 schema 4/新内容；本轮只重跑资源、依赖及启动器环境预检，不重启或接管用户窗口，也不把先前截图当作合并后重新试玩的证据。

## 当前 main 功能接入（优先于上节历史整合记录）

3D Bootstrap 已切换为共享 main 业务，采用 ordinary-release-v2 / schema 4；窗口标题为“寄往人间 · 3D · main 接入测试”。共享新版信纸/词条展示、原料与家具商店、故事记录及辅料药效预览，房间模型、八个对象入口与原生镜头导航保留。内存槽仍为 d3_lab_v035，关闭后进度清空，不加载 ordinary_release_v2 的真实玩家存档。

修改前已打开的窗口不会自动升级，需要新启动窗口才能使用这些功能。具体回归结果与原生画面证据见 [功能接入行动记录](actions/2026-10-14-main-business-3d-integration.md)。船票启程和三结局尚未由 main 完整提供，不把入口可见当作实现完成。
