# 长词条纸面适配实施计划

**Goal:** 保留全部词条原文，以真实字体测量决定纸条尺寸，修复托盘、拖拽与愿望拼贴的溢出。

**Architecture:** 新增 ui/landscape/WordSlip.lua，集中测量、断行、纸面留白与横向三段绘制。托盘按短词两列、长词整行顺序排布；拼贴沿用已有归一化坐标和旋转，改变显示尺寸而不改存档。

**Tech Stack:** Lua 5.4、urhox-libs/UI、UI.MeasureTextWidth、现有纸条 PNG。

## 约束

- 本轮仅纸条适配；不改标题、结局正文、数值、来源 tokenId、业务与存档结构。
- UI 继续使用现有字体、缩放和事件机制；引擎库与原素材只读。
- 保持已有点击、拖拽、选中、分类及消耗标记，标记另留空间。
- 按用户已批准的方向直接在当前 Maker 工作区执行，不创建分支、不提交或远端构建。
- 每个代码批次后查询预览；仅存活才刷新并取日志，停止会话不启动。

## 执行步骤（本会话顺序执行）

- [x] 复现：混合短词、长词、小屏、状态标记，检查完整文字和纸内留白、卡片不重叠；先确认测试失败。
- [x] WordSlip.Metrics(text, options)：实际测宽，保留字号，达到宽度上限才按 Unicode 字符断行；返回尺寸、行文与内边距。WordSlip.Surface(props) 保留两端比例、仅延展纸张中段。
- [x] 托盘接入共享测量和可变行高；拼贴编辑/预览/留念共用相同规则；拖拽与投料飞行保留起始尺寸。
- [x] 回归：新专项、托盘、炼药拖放、结局拼贴事务与 UI；Lua 诊断、diff 检查。
- [x] 以真实字体生成并查看标明 OFFLINE 的纸条排版证据，记录原生/手机未验证；检查预览状态。

测试入口：`python -X utf8 -B scripts/ui/landscape/tests/run_word_slip.py`。既有入口：`run_word_tray.py`、`run_brew_workbench.py`；结局套件通过 content_test_runtime.run 调用 debug.EndingPresentationUITest 和 debug.EndingPresentationTest。
