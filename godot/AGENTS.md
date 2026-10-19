# Godot 工程工作约束

本目录是正式迁移工程。原 `../scripts`、`../assets` 和 Maker 绑定是只读对照基线，不得为 Godot 方便而改写。

## 当前阶段

- 只执行 P0：视觉基线、物件比例、宽屏与安全区、静态标题/主页/工作台、纸条组件与双端 debug 包。
- 不接正式订单、内容导出、存档、商店、结局或新手引导；这些属于 P1 及以后。
- 不替换、不上传、不删除 Maker 版本。

## 修改规则

1. 先运行 `python ../tools/verify.py --suite layout`，用失败证据驱动修改。
2. 资源只通过 `prepare_media.py` 从 `../assets` 复制；不要手工改 `media/` 中的原字节。
3. `TextureRect` 必须先设 `expand_mode = EXPAND_IGNORE_SIZE`，再设纹理和目标尺寸；不要用原生纹理尺寸代替 manifest 目标。
4. 视觉层级使用 1920×1080 设计坐标；背景覆盖视口，文字和主要操作留在安全区，不横向拉伸整页 UI。
5. 场景脚本不读写业务存档，不调用旧 Lua 模块；P0 的按钮只能导航或显示演示提示。
6. 每次交付记录：执行的命令、结果、包尺寸与 SHA256、仍未验证项。自动检查与真实画面分开写。
7. 不操作旧 Maker 预览窗口，不启动会被用户看到的桌面窗口；真实安卓验收由用户反馈记录。

## 工具路径

默认 Godot 为 `%USERPROFILE%/.codex/tools/godot/4.7.2-stable/editor/Godot_v4.7.2-stable_win64_console.exe`。Android SDK 默认 `C:/Android`，Java 默认 `C:/Program Files/Java/jdk-21`。缺失时直接报错，不自动下载。
