# 记录书素材接入与字体

用户已确认厚书和全新大朵干花、干草、索引签，并要求接入查看。继续在当前工作区由本会话实施，不使用子代理，不提交或远端构建。用户已选择启动本地 Maker 窗口。

## 设计

沿用记录书右侧 26% 可用屏宽、左缘故事索引、目录与详情两级、收集空位和原翻页。厚书完整等比显示；正文位于奶油色内页，避开左侧纸层、右侧书脊和下缘装饰。大朵干花置于左下，淡金干草置于右下，两者均不接收输入。索引使用独立纸签。字体沿用 story / HarborHand-Regular.ttf（霞鹜文楷子集），正文 16、行距 1.6，标题 18–20，日期与用料 12–14，深褐墨色。目录用细线和留白代替实心卡片。

## 实施计划

- [x] 先扩展 JournalBookTest 的图片、正文边界、字体、装饰穿透与小屏比例断言，确认旧实现失败；修正测试缺少成功返回值。
- [x] 新增 JournalBookArt.lua，负责等比几何与素材路径。JournalBook.lua 只接入表现和局部布局，不修改查询、库存、世界或存档。
- [x] 重跑记录书、词条栏及相关安全区检查，取得 Lua LSP 诊断。按实际比例验证书页与正文边界。
- [x] 检查本地预览状态，用户已授权启动；取得实际日志和图像，逐项区分本地窗口、离线与手机证据。

代码范围：scripts/ui/landscape/JournalBook.lua、JournalBookArt.lua、相关 tests；assets/image 中此前新生成的四张图与来源清单。图片不改像素，原素材保留。

## 验证与结果

记录书 68、词条栏 51、HomeHud 52 项通过（隔离 Lua/File/Widget，非手机）；git diff --check 通过。JournalBook.lua、JournalBookArt.lua 与本轮测试的 LSP Error 为 0；全工作区仍有其他文件的既有 Error，不宣称全项目零错误。

红阶段确实在缺少 bookArtFrame 时失败。接入后遇到隔离 Widget 尚未装配 GetAbsoluteLayout，补齐检查中的绑定，并沿用项目其它布局代码的未挂载保护；记录书测试缺少 return true 的退出码问题已修正。

本地 preview start 成功，session b583d2a3-13dd-446f-940b-cf6fdbcf034c；随后仅刷新存活会话。reload 1/2 的原生 JournalBookNativeProbe 通过：真实 Yoga、四图加载、正文避让、装饰穿透、关闭命中、玩家快照不变。probe 只打开真实记录书，不制造收集记录。实际空态截图 .tmp/journal-book-art/native-book-r2.png 已读取。第一次外部截图时页面已经切到词条栏，不将该图视为记录书证据。

原生书宽 331、高 497；正文宽 248、高 298，植物区位于正文下方，来源比例保持。当前存档未收到故事，因此截图显示真实空态；目录与详情由隔离检查验证。手机、安全区触控与已收集后续的真人操作仍未验收。

Maker check 仍包含既有 Cube/Day/DaySpecularHDR.dds 缺失和 themis_x64.dll 加载错误，项目随后正常启动；不宣称整体运行检查全绿。最终关闭所有开发检查开关，普通玩家窗口保持运行。
