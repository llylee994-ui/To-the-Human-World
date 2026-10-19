# 《寄往人间》Godot 离线迁移验证版

2026-10-19：这是一段独立的可运行技术验证，不是完整游戏移植。原 Maker 工程、绑定、素材和玩家存档均未改动；没有提交、上传或发布。

## 直接测试

- Windows：双击 [启动验证版.cmd](启动验证版.cmd)，或直接运行 [测试 EXE](build/windows/ToTheHumanWorld-Godot-Test.exe)。EXE 已内置游戏资源，不需要安装 Godot、Maker、Node 或 Python。
- Android：[离线测试 APK](build/ToTheHumanWorld-Godot-Offline-Test.apk)。包名 `cn.tothehumanworld.godotspike`，arm64，minSdk 24 / Android 7.0，targetSdk 36；本地调试签名，仅用于试验。安装后开飞行模式，检查首次进入、标题、主页、工作台、点击/拖入、熬制、保存和重启恢复。
- 编辑工程：双击 [打开Godot工程.cmd](打开Godot工程.cmd)。便携版位于 `%USERPROFILE%/.codex/tools/godot/4.7.2-stable/editor/`，已经下载并按官方 SHA512 核对，无需你再手动安装。

## 已包含的内容

1. 当前标题背景、室内分层美术、海面、药炉、原料托盘、手写字体与一首 BGM。
2. 标题→主页→炼药工作台，点击选择或把词条/原料拖进锅中。
3. 3 个示例词、4 种原料、示例库存消耗与完成记录；“保存进度”和“重新读取”。
4. 独立的 `user://migration-progress.json` 存档。Windows 在 `%APPDATA%/ToTheHumanWorld-Godot-Spike/`；Android 在该测试应用自己的私有目录。与 TapTap 版不互通。

## 范围边界

- 没有迁移正式信件、裁词、药效合成、订单事务、发货、商店、日历、结局或完整音效。
- 示例的“开始熬制”会直接消耗选择的示例库存，不等同于正式版本的试做/发货结算规则；不要把示例状态当正式游戏结果。
- UI 使用原美术搭建了验证布局，不声称与 Maker 版本像素一致。
- 所有运行资源已随包内置；APK 清单没有声明任何权限，包含无 `INTERNET` 权限的检查。
- APK 导出、签名与结构检查通过不等于 Android 实机通过。目前未连接安卓设备，未安装包、未测飞行模式、触控、听感、性能和后台恢复。
- 仅执行后台无界面检查，没有打开或控制用户桌面窗口。

## 后台验证结果

| 检查 | 结果 |
|---|---|
| 便携编辑器与导出模板 | Godot 4.7.2 stable，官方 SHA512 匹配 |
| 资源副本 | 25 个正式素材原字节复制，sources.json 记录来源与 SHA256 |
| verify_state.gd | 配方、消耗、重复点击、重新实例化恢复、损坏存档隔离通过 |
| verify_scene.gd | 实际按钮信号、三画面、保存恢复、1280×720 / 800×360 / 1080×1920 边界通过 |
| Android 导出 | 成功；APK 内有 arm64 Godot 引擎、本地场景/脚本、布局 JSON 与导入资源 |
| APK 签名 / 对齐 / ZIP CRC | v2/v3 验证通过、16 KiB 对齐检查通过、全部 ZIP 条目 CRC 通过 |
| APK 权限 | aapt 输出仅包名，无 uses-permission |
| Windows 导出 | 内嵌 PCK 的独立 EXE，后台 --headless -- --smoke-test 退出码 0 |
| 真实画面、手机与听感 | 未验收 |

具体包体积和哈希见 [build/delivery.json](build/delivery.json)。构建日志保留在 build/，不会随原 Maker 工程构建或提交。

## 可复现命令

便携编辑器：`%USERPROFILE%/.codex/tools/godot/4.7.2-stable/editor/Godot_v4.7.2-stable_win64_console.exe`。下列命令在此目录执行，将 `<Godot>` 替换为该绝对路径：

```powershell
& '<Godot>' --headless --path . --editor --import --quit
& '<Godot>' --headless --path . --script res://tests/verify_state.gd
& '<Godot>' --headless --path . --script res://tests/verify_scene.gd
& '<Godot>' --headless --path . --export-debug 'Android Offline Test'
& '<Godot>' --headless --path . --export-debug 'Windows Offline Test'
```

本机 Android SDK 使用 `C:/Android`，Java 使用 `C:/Program Files/Java/jdk-21`。配置只写入本轮便携版的 editor_data，不修改系统 PATH 或共享 SDK。export_presets.cfg 中的自定义模板路径目前对应本机；换电脑时需改为新工具路径。签名文件在工具目录，不在工程内。

参考：

- [Godot 官方 Windows 下载与便携说明](https://godotengine.org/download/windows/)
- [Android 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Windows 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)
