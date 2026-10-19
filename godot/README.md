# 《寄往人间》Godot 正式工程（P0）

本目录是 Godot 迁移的正式工程。当前只完成 **P0：视觉基线与宽屏适配**，不包含正式玩法、订单、内容导出或存档系统。原 Maker 工程 `scripts/`、`assets/`、存档与绑定保持不变，继续作为迁移对照基线。

## 当前范围

- 标题、主页、炼药工作台的静态视觉。
- 主页物件按 `LayoutManifest` 的目标尺寸绘制，修复验证版 `TextureRect` 被原生纹理尺寸撑大的问题。
- 1920×1080、2340×1080、2400×1080、2412×1080 的内容/背景/安全区布局计算。
- 长词条纸条按实测文字宽度与最大宽度换行；`token_id` 与显示文本分离。
- 主页物件触控热区与点击提示；药炉进入工作台。
- Windows 与 Android debug 包。

尚未接入：正式内容导出、业务命令/查询、本地存档事务、信件/剪词/订单/商店/日历/三结局/回溯/新手引导。界面按钮除导航外只显示“P0 演示”提示，不修改任何业务状态。

## 目录

| 路径 | 职责 |
|---|---|
| `scenes/` | boot、title、home、brew 场景 |
| `src/app/` | 布局服务与入口 |
| `src/presentation/` | 主页图层、纸条、纸面、场景脚本 |
| `ui/components/` | `paper_panel.tscn`、`word_slip.tscn` |
| `tools/prepare_media.py` | 从 `assets/` 复制正式引用资源，导出主页布局与来源哈希 |
| `tools/verify.py` | Godot 导入与 headless 布局测试 |
| `tools/build.py` | Windows / Android debug 导出与交付清单 |
| `tests/` | P0 布局测试 |
| `media/` | 只读资源快照与 `home-layout.json` |
| `docs/evidence/` | 文本验收记录（大包与截图不进仓库） |

## 命令

在仓库根目录执行。默认 Godot 路径为
`%USERPROFILE%/.codex/tools/godot/4.7.2-stable/editor/Godot_v4.7.2-stable_win64_console.exe`，
可用 `--godot` 或环境变量 `GODOT_BIN` 覆盖。

```powershell
python godot/tools/prepare_media.py --scope p0
python godot/tools/verify.py --suite layout
python godot/tools/build.py --target all --configuration debug --output godot/build/p0
```

产物：

- `godot/build/p0/ToTheHumanWorld-P0-Windows-debug.exe`
- `godot/build/p0/ToTheHumanWorld-P0-Android-debug.apk`
- `godot/build/p0/delivery.json`

Android 包使用本地调试签名、arm64、无 INTERNET 权限，只用于 P0 画面验收，不是正式发布包。正式签名、包名冻结与干净包在 P6 处理。

## P0 验收口径

自动检查只证明布局数学、图层尺寸和纸条行为。真实画面、比例、手感与安卓设备必须由用户运行双端包确认；自动测试通过不能替代画面验收。P0 通过后才进入 P1 内容导出与正式业务迁移。
