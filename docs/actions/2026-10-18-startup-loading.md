# 启动预加载与雾港加载页实施记录

## Status and situation

Completed（实现与隔离回归；本地预览已刷新并完成 Lua 启动）。用户要求按 `docs/superpowers/plans/2026-10-18-startup-loading.md` 完成实现。本轮新增加载页、资源清单、预加载控制器和首次场景门禁；未改剧情、数值、来源词卡、结局判定、保存格式或存档槽，未提交、未推送、未触发远端构建。

原生窗口的视觉/首击音效、手机冷启动和真实网络缓存证据尚未完成，不能据此宣称 L01～L10 全部通过。

## Implementation measures

1. 新增 `AudioCatalog` 作为三首 BGM 和 21 个交互音效的唯一映射；`SceneMusic`、`ObjectSounds` 与预加载清单共用。
2. 新增 `PreloadManifest`，按 bootstrap/core/seaside/brew/endings 分组；组内路径去重，清单只列正式运行引用。
3. 新增 `AssetPreloader`：下载 → 真实载入 → 图片预热 → ready，支持同组复用、失败重试、无进展提示、取消后的迟到回调隔离和后台预取。
4. 新增 `LoadingView`：雾港轻量背景、纯色兜底、真实进度/物品计数、首次下载提示、慢速提示、重试按钮、输入遮罩和 0.25 秒淡出。
5. `main` 先显示加载页，再执行原数据校验、读档和正式装配；正式装配只执行一次，目标完成布局与渲染后才撤下遮罩并启动 BGM。
6. `AppView` 对首次海边／商店／炼药／结局加资源门禁；后台按 seaside → brew → endings 预取，前台目标优先。
7. `resources.json` 保留 `default=["**"]`，新增很小的 bootstrap 组（轻量背景＋两个 HarborHand 字体）及对应预下载组。
8. 新增 `PreloadTest.lua`、`LoadingEntryTest.lua`、`run_preload.py`，覆盖清单、控制器、入口主流程和场景门禁。

## 资源清单审计

| 组 | 文件数 | 图片/音频/字体 | 文件字节 | 图片像素 | RGBA 估算 |
|---|---:|---|---:|---:|---:|
| bootstrap | 3 | 1 / 0 / 2 | 6.58 MB | 147,456 | 0.56 MB |
| core | 61 | 37 / 22 / 2 | 88.46 MB | 56,630,725 | 216.03 MB |
| seaside | 14 | 13 / 1 / 0 | 33.83 MB | 17,736,728 | 67.66 MB |
| brew | 7 | 6 / 1 / 0 | 23.72 MB | 7,338,343 | 27.99 MB |
| endings | 10 | 9 / 1 / 0 | 29.07 MB | 13,632,204 | 52.00 MB |

- core 的 RGBA 估算是按 `宽×高×4` 的上界，不等于实际显存占用；原生低内存验收仍须记录。
- 轻量加载背景：源 `assets/image/misty-harbor-r1/sea-calm.png`，SHA256 `3b83aa68c34c5d00d3c85dfaf15259482f4c5930098687e4a7e4816c55ce7b18`，2,383,298 字节；导出 `assets/image/loading-r1/harbor-small-v01.jpg`，512×288，22,681 字节，SHA256 `1e81efa22968a3bbbaa5a5da528734a6db54ee641755cbaeba3e920f6957508c`，并新增 `.meta`。
- 未引用历史图（如 `misty-harbor-r1/sea.png`、`title-screen-r1/shop-doorway.png`、`wish-collage-r1/table-cloth-background.png`）和编辑器数据不在清单中。

## Affected file tree

- `.project/resources.json`：bootstrap 预下载组。
- `assets/image/loading-r1/harbor-small-v01.jpg`、`.meta`：加载页轻量背景。
- `scripts/core/`、`scripts/systems/`、`scripts/data/`：未改。
- `scripts/ui/landscape/AudioCatalog.lua`（新增）：公共音频映射。
- `scripts/ui/landscape/PreloadManifest.lua`（新增）：分组资源清单。
- `scripts/ui/landscape/AssetPreloader.lua`（新增）：下载/载入/预热状态机与生产端口。
- `scripts/ui/landscape/LoadingView.lua`（新增）：加载页。
- `scripts/ui/landscape/tests/PreloadTest.lua`（新增）：清单与控制器专项。
- `scripts/ui/landscape/tests/LoadingEntryTest.lua`（新增）：加载页、main 启动与场景门禁专项。
- `scripts/ui/landscape/tests/run_preload.py`（新增）：专项运行器。
- `scripts/ui/landscape/SceneMusic.lua`、`ObjectSounds.lua`：改用 AudioCatalog，播放行为不变。
- `scripts/ui/PlayView.lua`、`scripts/ui/landscape/AppView.lua`：资源门禁、延迟音乐和首次场景门禁。
- `scripts/main.lua`：加载页优先启动、单次正式装配、预取与退出清理。
- 本文档与 `docs/验证/2026-10-18-startup-loading-manual.md`：执行与人工验收记录。

## Self-verification results

| 检查 | 结果 |
| --- | --- |
| `python -X utf8 -B scripts/ui/landscape/tests/run_preload.py --suite all` | PASS，catalog/loader/entry/navigation 全部通过 |
| 清单文件与 meta | PASS，所有清单路径和 `.meta` 存在；bootstrap 背景与字体已入组 |
| 控制器 | PASS，下载未完成/占位/单图失败/缓存命中/取消迟到回调均不能提前 ready；同步命中、重试、同组去重、预取、30 秒提示通过 |
| 加载页 | PASS，目标首帧前最多 98%、目标渲染后 100%、重试/慢速/首次提示与一次淡出通过 |
| main 启动 | PASS，ready 前不装配正式视图；下载失败显示重试且不读档，重试后只装配/读档一次；目标完成后出现 `playPanel` 并撤下遮罩；Start/Stop 重复无残留 |
| 场景门禁 | PASS，首次商店/炼药/结局等待对应组，ready 后只执行一次，原始快照不变，未播放占位/点击音 |
| 已保存结局 | PASS，结局展示等待 endings 组；门禁前后事务、写入次数和已保存正文不变，不重复确认或发奖 |
| `run_scene_music.py` | PASS，201断言 |
| `run_object_sounds.py` | PASS，804断言 |
| `run_word_tray.py` | PASS，64断言 |
| `run_first_batch.py` | PASS，966断言 |
| `run_second_batch.py` | PASS，97断言 |
| `run_shop_view.py` | PASS，55断言 |
| `run_brew_workbench.py` | PASS，191断言 |
| `run_wish.py` | PASS，9/9 |
| `run_seaside_flow.py` | PASS，89断言 |
| `run_ui_action_sounds.py` | PASS，478断言 |
| `run_release.py --suite ui` | PASS，11/11 |
| `run_release.py --suite endings` | PASS，7/7 |
| `run_release.py --suite closing` | PASS，通过 |
| Maker Lua LSP（11个变更 Lua 文件） | 0 Error |
| `git diff --check` | PASS |

### 已知边界

- 本地预览 `preview refresh` 后 Lua 启动完成（第 1 天），日志无新增 Lua 报错；`preview check` 仍因既有引擎环境错误 `Cube/Day/DaySpecularHDR.dds` 与 `themis_x64.dll` 返回 FAIL，截图在基础本地预览不受支持，不能作为视觉/音效验收。
- `HomeEntryTest` 在未改动 HEAD 上同样于 `preview saves actual result` 失败，属既有问题；本轮未改动其涉及的业务逻辑。
- core 的 RGBA 估算较高；L10 低内存设备仍需在真机记录分组前后内存。
- 未测量真实冷缓存与手机网络时间线；不得把本地隔离测试当作下载、GPU 或听感通过。
