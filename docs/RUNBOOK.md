# 当前完整 3D 候选操作手册

当前入口为 `scripts/main.lua → scripts/v035/lab35/FullSceneHost.lua`，运行资源为 `assets/v035-full`、海边界面图片 `assets/v035-main-image`，UI 依赖 `urhox-libs`。本轮完整导出为 100 模型、3,208,608 三角形、8 个业务入口。

## Windows 启动

双击根目录 `Start-Windows.cmd`，或执行 `python tools/run_windows_game.py`。只读预检使用 `python tools/run_windows_game.py --check`。详见 [WINDOWS-RUN.md](WINDOWS-RUN.md)。旧个人目录启动器已退役，不再使用。

启动记录和原始截图保存在 `.windows-runs/<本次时间>/`。候选固定使用隔离 `MemoryStorage`，不加载真实玩家进度。每次启动为新进度；不要连续启动多个窗口。

## 检查与截图

- `python tools/audit_v035_resources.py`：只读核对当前 164 项资源哈希和 Lua 引用链；它不证明画面或点击通过。
- `python tools/windows_game_observer.py --run .windows-runs/<本次时间> --capture home`：核对当前克隆的启动记录/PID/可执行路径，置前游戏并采集真实客户区像素。此可选工具需本机已有 Pillow、psutil。`--click x y`、`--move x y` 是真实 Windows 鼠标输入，只在游戏获得焦点后发送；坐标以当前客户区为准，不能盲用旧截图坐标。`--close` 只关闭这份启动记录对应窗口。
- 云端的 `tools/run_cloud_game.sh`、`tools/run_cloud_capture.py/.sh`、`tools/run_cloud_interaction_check.py` 保留。其参数只适用官方 Linux 环境；云端合成输入与本机实际鼠标分别验收。详见 [云端报告](CLOUD-CANDIDATE-REPORT.md)。

## Blender 与旧测试

当前 Blender 编辑/导出辅助脚本与映射在 [tools/blender](../tools/blender/README.md)。所有输出进入显式暂存目录；不自动覆盖当前资源。旧导出包、旧打包工具及旧样片已清理。

根目录 `v035` 保留独有测试及不同实现，暂未迁移或去重；它不属于当前游戏加载入口。`tools/check_v035.py` 与 `tools/verify_full_v035.py` 服务这套旧测试，依赖 Lupa，不能替代 `scripts/v035` 的原生验收。旧测试必需的 `experiments/3d-lab/assets/import-probe-v035/probe.json` 特意保留。

## 历史资料

当前交付身份汇总见 [deliverables/CURRENT.md](../deliverables/CURRENT.md)，清理清单和测试状态见 [独立清理行动记录](actions/2026-10-14-independent-cleanup.md)。历史说明中的旧采样路径、已退役工具和旧交付压缩包仅说明当时过程，可从清理前提交 `7460d04e697c5ca7e6d312afae3cb0ef769ecc4b` 查阅，不应作为当前操作步骤。

## main 历史整合后的目录边界

当前开发分支为 `integration/3d-main-20261014`。完整 3D 经 `scripts/v035/lab35/Bootstrap.lua` 使用 main 的 `core`、`data`、`systems` 和 `ui.PlayModel`，采用 ordinary-release-v2 / schema 4；页面共用 `ui/landscape/AppView`，3D 提供透明房间、镜头导航和单次跨天确认适配。旧 `scripts/v035` 业务副本和根目录 `v035` 保留作历史参考，不作为当前生效业务。

本机稀疏检出只省略 `scripts/素材/` 的美术过程稿，其内容与许可仍在 Git 中。完整 3D 运行路径不受影响；按需恢复方法见根目录 README。旧 `.project` 绑定与 `experiments/3d-lab` 样片不接收，当前 probe.json 留作根目录测试。

## 当前共享业务回归

`python -X utf8 tools/check_3d_main_integration.py` 测试实际 3D 装配和页面回调，使用明确的 UI/时钟替身，禁止磁盘存档 API。测试依赖为本仓库 `.tmp/b1-python` 内的 Lupa 2.6，不提交或修改系统 Python。该检查不能替代真实鼠标、画面或手机验收。
