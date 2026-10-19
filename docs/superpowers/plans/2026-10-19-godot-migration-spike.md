# Godot 离线迁移验证计划

> 执行方式：本会话按任务顺序执行，使用 executing-plans；不拆分其他会话。用户已接受上一轮提出的 Godot 小范围验证，尚未授权替换正式 Maker 版本。

**目标：** 用便携版 Godot 建立独立验证工程，验证现有美术、标题/主页/炼药交互、本地存档以及离线 Android 导出链路。

**架构：** 独立工程放在 experiments/godot-migration/；不引用 Maker 服务、Lua 原生宿主或生产存档。复制本轮需要的少量正式素材，用 Godot Control 和 GDScript 实现最小示例流程，不声称完整玩法已移植。

**技术：** 官方稳定版 Godot 标准版、Compatibility 渲染、GDScript、Android SDK、本地 user:// 文件。

## 约束与范围

- 只在后台运行命令，不操作桌面、鼠标或现有预览窗口。
- 保留原 scripts/、assets/、Maker 绑定和玩家存档；独立测试文件与包名。
- 下载工具使用官方来源，保存在用户工具目录；不修改系统 PATH、共享 SDK 配置或安装新的系统组件。
- 此次是迁移技术验证，示例配方和初始库存不替代正式 196 条规则或剧情。
- APK 不申请 INTERNET 权限；导出成功不等于真机体验通过，飞行模式和触控由后续设备验收确认。
- 不提交、推送、远端构建或发布本轮验证工程。

## 文件职责

| 路径 | 职责 |
|---|---|
| experiments/godot-migration/project.godot | 独立工程、横屏画布与 Compatibility 配置 |
| experiments/godot-migration/src/spike_state.gd | 示例选料、配方、库存、存档数据与验证 |
| experiments/godot-migration/src/main.gd | 标题、主页、工作台、选择/拖放及离线状态 |
| experiments/godot-migration/main.tscn | 主场景 |
| experiments/godot-migration/tests/verify_state.gd | 选料、消耗、重复提交、损坏存档和恢复检查 |
| experiments/godot-migration/media/ | 现有美术和字体的原字节副本 |
| experiments/godot-migration/tools/ | 素材准备与后台运行/导出辅助 |
| experiments/godot-migration/README.md | 实际运行命令、产物、验证证据和未迁移范围 |

## Task 1：工具和工程基线

- [x] 核查 Godot、Java、Android SDK，确定可用稳定版及准确下载地址。
- [x] 下载便携版并核对官方校验和，运行 --headless --version；记录实际版本。
- [x] 创建最小 project.godot、场景和测试入口，运行无界面导入检查。

## Task 2：本地状态与存档

- [x] 先写状态行为检查：无原料禁止炼制；正确选料扣减一次；连点不重复奖励；重新实例化可恢复；非法存档不覆盖现有内存状态。
- [x] 运行测试确认缺少实现而失败。
- [x] 实现独立状态模块，JSON 写入 user://，不接入 TapTap 存档。
- [x] 运行同一检查直到通过，记录退出码与日志。

## Task 3：三画面与交互

- [x] 复制并校验标题、室内前景、海面、药炉、托盘和字体素材。
- [x] 实现标题→主页→工作台；工作台显示可选词条/原料、铜锅、配方和示例结果。
- [x] 支持点击选择与拖放，提供本地进度保存、重载及明确“迁移验证版”标识。
- [x] 在独立后台 Godot 进程验证场景装配、按钮调用、状态恢复；不把 headless 检查当作视觉证据。

## Task 4：离线导出链路

- [x] 准备与编辑器版本相同的官方 Android 导出模板，复用已存在 SDK 与 Java。
- [x] 设置独立包名、横屏、arm64、无 INTERNET 权限；使用本地调试签名。
- [x] 执行 Android 导出，检查 APK 清单、签名、ZIP 完整性和完整资源内置。
- [x] 若工具缺失或下载阻塞，准确记录已完成和具体缺口，不宣称已导出。
- [x] 汇总可运行工程和 APK（若成功），列出安卓安装、飞行模式、触控与听感仍待验证。

## 自检

范围与用户已接受的小验证一致；不执行全量剧情迁移，不覆盖旧引擎。本地状态测试和 APK 静态检查各自对应不同验收结论。无需用户先安装编辑器；如需设备验收再交付可安装包。

## 实际执行结果（2026-10-19）

便携版 Godot 4.7.2 和导出模板已按官方 SHA512 校验。独立工程、25 项资源副本、状态与场景检查、Android 和 Windows 导出均已完成。安卓 APK 66,706,223 字节，无权限声明；v2/v3 签名、16 KiB 对齐及 ZIP CRC 通过。Windows EXE 138,691,568 字节，已后台独立加载完整内置资源并完成 smoke 检查，退出码 0。实机未连接，未安装 APK；画面、触控、飞行模式、听感与完整游戏迁移均未验收。本轮保留独立试验目录，无提交或远端构建。实际操作和限制见 experiments/godot-migration/README.md。
