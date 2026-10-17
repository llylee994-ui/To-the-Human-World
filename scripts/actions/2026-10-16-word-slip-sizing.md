# 2026-10-16 长词条纸面适配

用户已确认「让纸适应文字」并要求实施。本轮仅 UI，未提交、未推送或远端构建。

## 实现

- 新增 `ui/landscape/WordSlip.lua`：使用 `UI.MeasureTextWidth` 和实际 story 字体字号测量，左右各留 14 基准像素；先扩宽再按 Unicode 字符断行，不截断原词、不自动缩小字号。极长边界样本可超过两行以保留原文。
- 纸面使用现有 PNG，左右各 8% 为端部，按垂直比例保留撕边，中段横向伸缩；没有编辑或生成素材。
- 托盘由固定两列改为顺序流式排布：短词可双列，长词整行；内容高度按实际行高累加，预留滚动条和状态标记空间。
- 拿起、投料飞行及退回均传递临时 wordSlip 测量值；动画缩放发生在整张纸条上。
- 愿望编辑、预览与留念共用测量。旧布局只在显示副本内限制旋转边界，拖动从显示位置起步；来源 ID 与保存坐标不因查看而改写。

修改：WordTrayDrawer、WishPaper、WishView、BrewView、BrewInteraction；新增 WordSlip 与专项测试/离线证据脚本。
工作区原有 TitleView、结局文案、release_endings、标题素材与相关文档均保留，不属于本轮改动。

## 验证

- 新专项先在原实现复现「好好睡一觉」超出纸内留白，再复现拖拽丢失来源尺寸，修复后 `run_word_slip.py`：179 项通过。
- `run_word_tray.py`：64 项通过；`run_brew_workbench.py`：188 项通过。
- `debug.EndingPresentationUITest`：5 组通过；`debug.EndingPresentationTest`：12 组通过。首次新增显示副本遗漏 sourceTokenId 导致拖动拒绝，已补齐并重跑 UI 套件通过。
- 使用真实 `HarborHand-Regular.ttf` 测量全部 61 词 + 6 边界样本，1280×720、800×360、1920×1080 共 210 行全部位于纸内留白。
- 八个本轮 Lua 文件单文件 LSP Error 查询均为空；全工程仍有 6 条不在本轮修改范围的既有 Error（ReleaseDayGateTest 2、AppView 1、JourneyArt 1、UiActionSoundsTest 2），未宣称全工程无错误。
- `git diff --check` 通过。
- 多次官方 preview status 均 `stopped / process_alive=false`，未启动或刷新。

真实字体离线图已查看：[offline-word-slips.png](../../docs/验证/evidence/word-slip-sizing-r1/offline-word-slips.png)。对应几何与源文件 SHA-256 在同目录 geometry.json。图仅重放纸条排版，不能证明原生 Yoga、GPU 切片接缝、鼠标拖放或手机触控通过。

原生/手机待验：长词与状态标记、拖出/投料/退回的尺寸连续性、旋转后边界与撤销、不同密度缩放下的文字行高及纹理接缝。后续在获准启动的窗口里验证；不将停止会话自动复活。
