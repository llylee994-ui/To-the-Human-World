# 记录书关闭、页名与纸签文字调整

用户截图要求：右上关闭移到左上；“记录书”换位置；“铁锚”索引文字贴合纸签底图。直接在已确认的素材构图上微调，不变更花草、厚书、内容查询或收集状态。

纸签原图 2172×724，Alpha>=128 的纸面边界为 (56,95)-(2108,621)，上下有约 13% 透明边，右端为折入书页的窄尾。原按钮使用 padding={0,2}，但 Button.Init 默认 paddingHorizontal=16 优先展开，且普通子 Label 没有占满按钮高度，导致文字不按纸面垂直居中。选中横线位于底图的透明下缘。

调整：
- 关闭控件成为左上首个且唯一的按钮，局部栏宽 56（44 按钮 + 12 宿主避让内边距），继续通过 UpdateChrome 处理宿主胶囊。
- “记录书”放在内页的故事标题上方，13 号淡褐文楷，不再使用压住桌布绣花的深色底牌。
- 纸签明确四边 padding=0，文字绝对定位在 x=7%..79%、y=13%..86% 的纸面，11 号文楷、垂直居中；右端折页留白，移除透明边缘上的选中横线。已收集/未收集标签和切换逻辑不改。

验证：现有 JournalBookTest 69 项通过；JournalBook.lua / JournalBookArt.lua LSP Error 0；git diff --check 通过。没有为这次低影响排版修改增加镜像断言。

本地预览已按存活状态刷新，session 0330f2fb-efaf-4151-93d4-027c4c7fc52f / reload 3 / PID 27768，13:43:14 启动完成。已取 logs/check；既有 Cube/Day/DaySpecularHDR.dds、themis_x64.dll 错误仍在，不宣称全局检查通过。

## 原生验收

临时启用已有 PanelReferenceNativeProbe，reload 4 / PID 19088 使用隔离的内存 SaveSystem 收取、剪词并产生真实分支记录。13:50:24 输出 PASS：实际 Yoga、分类与词卡触摸、已保存后续、滚动、返回、关闭动画及玩家快照不变。截图明确标注“界面验收 · 内存样本”。

已从当前 Runtime 缓存复制并读取实际画面：
- .tmp/panel-layout-reference/journal-chrome-catalog-native.png
- .tmp/panel-layout-reference/journal-chrome-detail-native.png
- .tmp/panel-layout-reference/tray-reference-native.png
- 完整验收日志 .tmp/panel-layout-reference/journal-chrome-r4-acceptance.json

画面确认关闭在左上、页名在故事标题上方、“铁锚”文字处于宽纸面中央。验收另发现关闭按钮主题默认高度 48 而容器为 44 的溢出提示，最后将两者显式统一为 48；复跑 JournalBookTest 69 项、LSP Error 0，未改动按钮行为。随后关闭所有临时原生验收开关，刷新普通入口；没有提交、推送或远端构建。

普通入口 reload 5 / PID 8880 已于 13:56:46 输出 Game started successfully；所有 DevChecks 开关 false，预览保持运行。当前 logs/check 保存于 .tmp/panel-layout-reference/journal-chrome-r5-{log,check}.json。冷启动原有两条引擎错误仍在，界面验收通过不代表全项目 check 为绿色。
