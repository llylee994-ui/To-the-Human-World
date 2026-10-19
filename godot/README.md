# 《寄往人间》Godot 正式工程（P1 基础）

本目录是 Godot 迁移的正式工程。P0 视觉基线（`0.1.3-p0fix`）已完成；当前完成 **P1-A 全量内容导出** 与 **P1-B 领域/存档基础**。原 Maker 工程 `scripts/`、`assets/`、存档与绑定保持不变，继续作为迁移与对照基线。

## 当前范围

- 标题、主页、炼药工作台的静态视觉与宽屏/安全区布局。
- 从正式 Lua 内容导出 `content/generated/catalog.json`；加载时校验版本、重复 ID、计数和引用。
- 词条来源 token、配方草稿、药效八步计算、内容查询与统一命令入口。
- 独立 `user://godot_save` A/B 快照：写入/读回校验、提交标记、结果不确定锁定、损坏回退。
- Windows 与 Android debug 包。

尚未接入：正式信件实例、订单生命周期、商店、日历、三结局、回溯、新手引导和 P1 命令的正式 UI。当前按钮除导航外仍只显示演示提示；P2 再把真实首单接到界面。

## 目录

| 路径 | 职责 |
|---|---|
| `scenes/` | boot、title、home、brew 场景 |
| `src/app/` | 布局服务与入口 |
| `src/content/` | 导出 catalog 的加载与只读查询 |
| `src/domain/` | 药效、草稿、词条、状态校验、命令/查询与会话 |
| `src/persistence/` | 规范化 JSON、A/B 快照、设置 |
| `src/presentation/` | 主页图层、纸条、纸面、场景脚本 |
| `ui/components/` | `paper_panel.tscn`、`word_slip.tscn` |
| `content/generated/` | 由 Lua 正式内容导出的只读 catalog |
| `tools/export_content.py` | 导出并校验正式内容与正文哈希 |
| `tools/export_oracle.py` | 导出 Lua 药效/词条/草稿对照用例 |
| `tools/prepare_media.py` | 从 `assets/` 复制正式引用资源，导出主页布局与来源哈希 |
| `tools/verify.py` | 导出检查、Godot 导入与 headless 测试 |
| `tools/build.py` | Windows / Android debug 导出与交付清单 |
| `tests/` | P1 内容/领域/存档与 P0 布局测试 |
| `media/` | 只读资源快照与 `home-layout.json` |
| `docs/evidence/` | 文本验收记录（大包与截图不进仓库） |

## 命令

在仓库根目录执行。默认 Godot 路径为
`%USERPROFILE%/.codex/tools/godot/4.7.2-stable/editor/Godot_v4.7.2-stable_win64_console.exe`，
可用 `--godot` 或环境变量 `GODOT_BIN` 覆盖。

```powershell
python godot/tools/prepare_media.py --scope p0
python godot/tools/export_content.py
python godot/tools/export_oracle.py
python godot/tools/verify.py --suite foundation
python godot/tools/verify.py --suite all
python godot/tools/build.py --target all --configuration debug --output godot/build/p0
```

`verify.py` 的 `content`/`foundation`/`all` 会先执行两个导出工具的 `--check`，内容或 oracle 陈旧时直接失败；`commands`/`foundation`/`all` 还会运行独立的双进程存档恢复检查。P1 总回执见 [P1 基础回执](docs/evidence/p1-foundation-2026-10-19.md)，分批报告见 [P1-A 内容对照](docs/evidence/p1-a-content-report-2026-10-19.md)、[P1-B 业务/存档对照](docs/evidence/p1-b-foundation-report-2026-10-19.md) 与 [P1 修复回执](docs/evidence/p1-fix-2026-10-19.md)。

产物：

- `godot/build/p0/ToTheHumanWorld-P0-Windows-debug.exe`
- `godot/build/p0/ToTheHumanWorld-P0-Android-debug.apk`
- `godot/build/p0/delivery.json`

Android 包使用本地调试签名、arm64、无 INTERNET 权限，只用于 P0 画面验收，不是正式发布包。正式签名、包名冻结与干净包在 P6 处理。

## P0 验收口径

自动检查只证明布局数学、图层尺寸和纸条行为。真实画面、比例、手感与安卓设备必须由用户运行双端包确认；自动测试通过不能替代画面验收。P0 通过后才进入 P1 内容导出与正式业务迁移。
