# P0 记录书固定标题修正（2026-10-19）

用户圈出的“记录书”“铁锚巷的一夜”“已收集 0 / 8 支”应保持固定，下方编号条目才属于滑动区域。

## 修改与验证

记录书内容分为固定标题容器和条目 ScrollContainer。标题按实际文字高度排版，剩余纸面空间留给列表；滚动条从收集进度下方开始。字号、左右贴边和页面大小沿用上一轮。

先运行布局基线：147 项通过。新增实际场景回归在修复前观察到失败：三行标题属于滚动节点并随列表移动。修复后执行 `python -B godot/tools/verify.py --suite all --skip-import`，563 项通过、退出 0。新增检查覆盖三个屏幕/安全区组合，实际设置列表滚动量，确认条目移动、三行标题位置不变且位于滚动区域上方。

执行 `python -B godot/tools/build.py --target all --configuration debug --output godot/build/p0`，Windows、Android 导出均退出 0。版本 0.1.3-p0fix，Android versionCode 4。

- Windows：151190760 字节；SHA256 `0e0acca547a7c60c335fc590aea0b2d6453464aaa353bba59c6d266ea98622fe`。
- Android：79396645 字节；SHA256 `5dc01e32bfa09cc42db68f00def683b5c114e966dd7678da28243a9722cbfc6d`。

APK v2/v3 调试签名、16 KiB 对齐、ZIP CRC 和开发目录排除检查通过，未声明 uses-permission。交付清单关联本轮源码快照。

从最终 EXE 在未切换到的独立 desktop 导出并实际查看两张画面，滚动条位于固定三行下方；之前调整的托盘比例、按钮、侧栏保持正常：

- [16:9 工作台](D:/p0-fix5-20261019/brew-1280x720.png)
- [2412×1080 等效宽屏工作台](D:/p0-fix5-20261019/brew-1600x716.png)

自动滚动验证与静态截图分别记录；本轮未实际操作 Android 手机，触控手感仍待实机确认。P0 总体验收不据此自动放行。
